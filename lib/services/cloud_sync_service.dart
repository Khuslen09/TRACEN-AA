import '../l10n/strings.dart';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/activity_type.dart';
import '../models/pin.dart';
import '../models/pin_category.dart';
import '../models/place_candidate.dart';
import '../models/route.dart';
import '../utils/polyline_codec.dart';
import 'auth_service.dart';
import 'cloud_photo_service.dart';
import 'route_db_service.dart';
import 'sync_queue_service.dart';

/// AA의 클라우드 동기화 메인 서비스.
///
/// 책임:
///   - 여정 종료 / 핀 삭제 / 여정 삭제 시 sync_queue에 작업 추가
///   - flushQueue() 호출 시 큐를 비워가며 Firestore + Storage에 반영
///   - 로그인 직후 pullAll()로 클라우드 → 로컬 풀 다운로드
///
/// 사용 패턴:
///   화면 단에서 직접 enqueue 호출하지 말고, HomeScreen/RouteListScreen 등이
///   "여정 종료" 같은 상위 의도 메서드(syncRouteCompleted, syncRouteDeleted)를
///   호출. 그 안에서 enqueue + flush를 처리.
class CloudSyncService {
  CloudSyncService._();

  static final _firestore = FirebaseFirestore.instance;

  /// Firestore는 리스트를 네이티브 배열(`List<dynamic>`, 각 원소가
  /// `Map<String,dynamic>`)로 주므로, [Pin.fromMap]의 JSON 문자열 디코드
  /// (`_decodeCandidates`, SQLite TEXT 컬럼용)와는 다른 경로가 필요하다.
  /// `_uploadPin`이 쓰는 인코딩과 쌍을 이루니 같이 고칠 것.
  static List<PlaceCandidate> _decodeCandidatesFromFirestore(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PlaceCandidate.fromJson)
        .toList();
  }

  // ─────────────────────────────────────────────
  // 컬렉션 참조 헬퍼
  // ─────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _routesCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('routes');

  static CollectionReference<Map<String, dynamic>> _pinsCol(
    String uid,
    String routeUuid,
  ) => _routesCol(uid).doc(routeUuid).collection('pins');

  /// **v5 신규**: 일반 핀 (러닝과 무관)의 Firestore 경로.
  /// `users/{uid}/pins/{pinUuid}` — 러닝 서브컬렉션과 분리.
  static CollectionReference<Map<String, dynamic>> _standalonePinsCol(
    String uid,
  ) => _firestore.collection('users').doc(uid).collection('pins');

  /// **신규**: 일상 경로(DayTrack)의 Firestore 경로.
  /// `users/{uid}/dayTracks/{dayId}` — 하루 전체를 문서 하나로 관리 (덮어쓰기 방식).
  static CollectionReference<Map<String, dynamic>> _dayTracksCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('dayTracks');

  // ─────────────────────────────────────────────
  // 상위 의도 API — 화면에서 호출하는 곳
  // ─────────────────────────────────────────────

  /// 여정 종료 직후 호출. 여정 + 모든 핀을 큐에 넣고 즉시 flush 시도.
  static Future<void> syncRouteCompleted(int routeId) async {
    final route = await RouteDBService.getRoute(routeId);
    if (route == null) return;

    await SyncQueueService.enqueue(
      action: SyncAction.uploadRoute,
      entityUuid: route.uuid,
    );

    final pins = await RouteDBService.getPins(routeId);
    for (final pin in pins) {
      await SyncQueueService.enqueue(
        action: SyncAction.uploadPin,
        entityUuid: pin.uuid,
      );
    }

    // fire-and-forget: 호출 측 UX 막지 않음
    flushQueue();
  }

  /// 핀 추가 직후 호출.
  /// **MVP v5**: 핀이 독립 엔티티라 runId가 없을 수도 있음 (일반 핀).
  /// 일반 핀은 즉시 동기화. 러닝 진행 중인 핀만 러닝 종료 시 일괄 처리.
  static Future<void> syncPinAdded(Pin pin) async {
    if (pin.runId == null) {
      // 일반 핀 — 즉시 큐
      await SyncQueueService.enqueue(
        action: SyncAction.uploadPin,
        entityUuid: pin.uuid,
      );
      flushQueue();
      return;
    }

    // 러닝에 속한 핀 — 그 러닝이 이미 종료됐으면 즉시, 진행 중이면 종료 때
    final route = await RouteDBService.getRoute(pin.runId!);
    if (route == null || route.isActive) return;

    await SyncQueueService.enqueue(
      action: SyncAction.uploadPin,
      entityUuid: pin.uuid,
    );
    flushQueue();
  }

  /// 핀 삭제 시. payload에 routeUuid + storagePath 같이 보냄
  /// (큐 처리 시점엔 핀이 로컬에 없을 수 있어서 정보 보존 필요).
  static Future<void> syncPinDeleted({
    required String pinUuid,
    required String routeUuid,
    String? photoStoragePath,
  }) async {
    await SyncQueueService.enqueue(
      action: SyncAction.deletePin,
      entityUuid: pinUuid,
      payload: '$routeUuid|${photoStoragePath ?? ''}',
    );
    flushQueue();
  }

  /// 여정 삭제 시. payload 없음 — Firestore에서 routes/{uuid}만 삭제하면 됨
  /// (Firestore는 cascade 없으므로 pins 서브컬렉션도 직접 지움).
  static Future<void> syncRouteDeleted(String routeUuid) async {
    await SyncQueueService.enqueue(
      action: SyncAction.deleteRoute,
      entityUuid: routeUuid,
    );
    flushQueue();
  }

  /// **신규**: 일상 경로(DayTrack) 갱신 시 호출.
  ///
  /// 백그라운드 트래킹 중 GPS 점이 새로 찍힐 때마다 호출해도 안전 —
  /// entityUuid(dayId)가 같으면 큐에서 중복 제거되므로 여러 번 불러도 작업은 1개만 남음.
  /// 다만 매번 즉시 flush하면 Firestore 쓰기 비용이 커지므로,
  /// 호출 측(TrackingService)에서 일정 간격으로만 flush를 트리거하도록 함.
  static Future<void> syncDayTrackUpdated(
    String dayId, {
    bool flushNow = false,
  }) async {
    await SyncQueueService.enqueue(
      action: SyncAction.uploadDayTrack,
      entityUuid: dayId,
    );
    if (flushNow) flushQueue();
  }

  // ─────────────────────────────────────────────
  // Queue flush
  // ─────────────────────────────────────────────

  static bool _flushing = false;

  /// 큐의 모든 작업을 처리. 동시에 여러 번 호출돼도 한 번만 돈다.
  ///
  /// 실패 작업은 큐에 남아 다음 flush에서 재시도.
  /// 5번 이상 실패한 작업은 reapDeadJobs()로 영구 폐기.
  static Future<void> flushQueue() async {
    if (_flushing) return;
    if (!AuthService.isLoggedIn) return; // 로그인 안 된 상태면 스킵

    _flushing = true;
    try {
      await SyncQueueService.reapDeadJobs();

      // 이번 flush 안에서 이미 실패한 작업 id — peek()은 markFailed 후에도
      // 큐에 그대로 남은 job을 계속 돌려주므로, 기록해두지 않으면 같은
      // 작업만 영원히 재시도하며 while(true)가 멈추지 않는다.
      final failedThisRun = <int>{};

      while (true) {
        final jobs = await SyncQueueService.peek(limit: 10);
        final pending = jobs.where((j) => !failedThisRun.contains(j.id)).toList();
        if (pending.isEmpty) break;

        for (final job in pending) {
          try {
            await _processJob(job);
            await SyncQueueService.markDone(job.id);
          } catch (e, st) {
            if (kDebugMode) {
              debugPrint('[CloudSync] job ${job.id} failed: $e');
              debugPrint(st.toString());
            }
            await SyncQueueService.markFailed(job.id, e.toString());
            failedThisRun.add(job.id);
            // 이 작업만 건너뛰고 배치의 나머지 + 다음 배치는 계속 처리.
            // 다음 flushQueue 호출에서 다시 시도된다(reapDeadJobs가 생명주기
            // 전체 재시도 횟수를 캡핑).
            continue;
          }
        }
      }
    } finally {
      _flushing = false;
    }
  }

  static Future<void> _processJob(SyncJob job) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      throw StateError('Not logged in');
    }

    switch (job.action) {
      case SyncAction.uploadRoute:
        await _uploadRoute(uid, job.entityUuid);
        break;
      case SyncAction.deleteRoute:
        await _deleteRoute(uid, job.entityUuid);
        break;
      case SyncAction.uploadPin:
        await _uploadPin(uid, job.entityUuid);
        break;
      case SyncAction.deletePin:
        await _deletePin(uid, job.entityUuid, job.payload);
        break;
      case SyncAction.uploadDayTrack:
        await _uploadDayTrack(uid, job.entityUuid);
        break;
    }
  }

  // ─────────────────────────────────────────────
  // 개별 작업 구현
  // ─────────────────────────────────────────────

  static Future<void> _uploadRoute(String uid, String routeUuid) async {
    final route = await RouteDBService.getRouteByUuid(routeUuid);
    if (route == null) {
      // 큐 작업 후 사용자가 여정 삭제했을 수 있음 — 정상 케이스
      return;
    }

    final points = await RouteDBService.getPoints(route.id!);
    final encodedPath = PolylineCodec.encode([
      for (final p in points) LatLng(p.lat, p.lng),
    ]);

    final pinCount = (await RouteDBService.getPins(route.id!)).length;

    await _routesCol(uid).doc(routeUuid).set({
      'id': routeUuid,
      'title': route.title,
      'startedAt': Timestamp.fromDate(route.startedAt),
      'endedAt': route.endedAt == null
          ? null
          : Timestamp.fromDate(route.endedAt!),
      'distance': route.distance,
      'activityType': route.activityType.key,
      'memo': route.memo,
      'pointCount': points.length,
      'pinCount': pinCount,
      'encodedPath': encodedPath,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _deleteRoute(String uid, String routeUuid) async {
    final routeRef = _routesCol(uid).doc(routeUuid);

    // pins 서브컬렉션 먼저 정리 (Firestore는 cascade 없음)
    final pinsSnapshot = await _pinsCol(uid, routeUuid).get();
    final batch = _firestore.batch();
    for (final doc in pinsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(routeRef);
    await batch.commit();

    // Storage의 사진 폴더도 정리
    await CloudPhotoService.deleteRoutePhotos(uid: uid, routeUuid: routeUuid);
  }

  static Future<void> _uploadPin(String uid, String pinUuid) async {
    final pin = await RouteDBService.getPinByUuid(pinUuid);
    if (pin == null) return;

    // 사진 업로드 — 러닝/일반 핀 모두 동일 로직
    String? photoUrl = pin.photoUrl;
    String? storagePath = pin.photoStoragePath;

    if (pin.photoPath != null && photoUrl == null) {
      final file = File(pin.photoPath!);
      if (await file.exists()) {
        // Storage 경로: 일반 핀은 'standalone' 폴더로 분리
        final routeUuidForStorage = pin.runId == null
            ? 'standalone'
            : (await RouteDBService.getRoute(pin.runId!))?.uuid ?? 'standalone';

        final result = await CloudPhotoService.uploadPinPhoto(
          uid: uid,
          routeUuid: routeUuidForStorage,
          pinUuid: pin.uuid,
          localFile: file,
        );
        photoUrl = result.downloadUrl;
        storagePath = result.storagePath;

        await RouteDBService.updatePin(
          pin.copyWith(photoUrl: photoUrl, photoStoragePath: storagePath),
        );
      }
    }

    final pinData = {
      'id': pin.uuid,
      'lat': pin.lat,
      'lng': pin.lng,
      'category': pin.category.key,
      'photoUrl': photoUrl,
      'photoStoragePath': storagePath,
      'memo': pin.memo,
      'createdAt': Timestamp.fromDate(pin.createdAt),
      'placeName': pin.placeName,
      'placeCity': pin.placeCity,
      // 디코드 쪽은 _decodeCandidatesFromFirestore — 같이 고칠 것.
      'placeCandidates': pin.placeCandidates.map((c) => c.toJson()).toList(),
    };

    if (pin.runId == null) {
      // **v5 신규**: 일반 핀 → users/{uid}/pins/{pinUuid}
      await _standalonePinsCol(uid).doc(pin.uuid).set(pinData);
    } else {
      // 러닝 자식 핀 → users/{uid}/routes/{runUuid}/pins/{pinUuid}
      final route = await RouteDBService.getRoute(pin.runId!);
      if (route == null) return;
      await _pinsCol(uid, route.uuid).doc(pin.uuid).set(pinData);
    }
  }

  static Future<void> _deletePin(
    String uid,
    String pinUuid,
    String? payload,
  ) async {
    if (payload == null) return;

    // payload 형식: "{routeUuid}|{storagePath or empty}"
    // **v5**: routeUuid가 빈 문자열이면 일반 핀 (러닝과 무관)
    final parts = payload.split('|');
    if (parts.length != 2) return;
    final routeUuid = parts[0];
    final storagePath = parts[1].isEmpty ? null : parts[1];

    if (routeUuid.isEmpty) {
      // 일반 핀 → users/{uid}/pins/{pinUuid}
      await _standalonePinsCol(uid).doc(pinUuid).delete();
    } else {
      // 러닝 자식 핀 → users/{uid}/routes/{runUuid}/pins/{pinUuid}
      await _pinsCol(uid, routeUuid).doc(pinUuid).delete();
    }

    if (storagePath != null) {
      await CloudPhotoService.deletePhoto(storagePath);
    }
  }

  /// dayId 하루치 전체 점을 다시 인코딩해서 Firestore 문서를 덮어씀.
  /// (이 기기가 그날의 "출처"이므로 항상 로컬 → 클라우드 방향으로만 씀)
  static Future<void> _uploadDayTrack(String uid, String dayId) async {
    final points = await RouteDBService.getDayTrackRawPoints(
      dayId,
      userId: uid,
    );
    if (points.isEmpty) return;

    final encodedPath = PolylineCodec.encode([
      for (final p in points) LatLng(p.lat, p.lng),
    ]);

    await _dayTracksCol(uid).doc(dayId).set({
      'dayId': dayId,
      'encodedPath': encodedPath,
      'pointCount': points.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────
  // Pull (다운로드) — 다른 기기에서 로그인 시
  // ─────────────────────────────────────────────

  /// 클라우드 → 로컬 풀 동기화.
  ///
  /// 호출 시점: 로그인 직후 (LoginScreen이 Home 진입 전 1회).
  /// 이미 로컬에 있는 데이터는 uuid로 매칭해서 덮어쓰지 않고 무시
  /// (last-write-wins는 추후 updatedAt 비교로 정교화 가능).
  ///
  /// 사진은 lazy 다운로드 — Pin.photoUrl만 저장하고 실제 파일은
  /// 사용자가 그 핀을 처음 볼 때 [Image.network]로 받아옴.
  ///
  /// 반환: 새로 가져온 여정 수.
  static Future<int> pullAll() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return 0;

    final routesSnapshot = await _routesCol(uid).get();
    int newCount = 0;

    for (final routeDoc in routesSnapshot.docs) {
      final data = routeDoc.data();
      final routeUuid = routeDoc.id;

      // 이미 로컬에 있으면 메타데이터만 갱신
      final existing = await RouteDBService.getRouteByUuid(routeUuid);

      final route = TraceRoute(
        id: existing?.id,
        uuid: routeUuid,
        title: data['title'] as String? ?? Strings.current.journey,
        startedAt: (data['startedAt'] as Timestamp).toDate(),
        endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
        distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
        userId: uid,
        activityType: ActivityType.fromKey(data['activityType'] as String?),
        memo: data['memo'] as String?,
        status: RouteStatus.completed,
      );
      final localId = await RouteDBService.upsertRouteFromCloud(route);

      // 새로 받은 여정만 polyline + pins 다운로드
      if (existing == null) {
        newCount++;

        // polyline 디코딩 → route_points 테이블에 채워넣기
        final encoded = data['encodedPath'] as String? ?? '';
        if (encoded.isNotEmpty) {
          final points = PolylineCodec.decode(encoded);
          await RouteDBService.replacePoints(localId, [
            for (final p in points) (lat: p.latitude, lng: p.longitude),
          ]);
        }

        // 핀 다운로드
        final pinsSnapshot = await _pinsCol(uid, routeUuid).get();
        for (final pinDoc in pinsSnapshot.docs) {
          final pd = pinDoc.data();
          final pin = Pin(
            uuid: pinDoc.id,
            runId: localId,
            userId: uid,
            lat: (pd['lat'] as num).toDouble(),
            lng: (pd['lng'] as num).toDouble(),
            category: PinCategory.fromKey(pd['category'] as String?),
            photoUrl: pd['photoUrl'] as String?,
            photoStoragePath: pd['photoStoragePath'] as String?,
            memo: pd['memo'] as String?,
            createdAt: (pd['createdAt'] as Timestamp).toDate(),
            placeName: pd['placeName'] as String?,
            placeCity: pd['placeCity'] as String?,
            placeCandidates: _decodeCandidatesFromFirestore(pd['placeCandidates']),
          );
          await RouteDBService.upsertPinFromCloud(pin);
        }
      }
    }

    // **v5 신규**: 일반 핀 다운로드 (러닝과 무관)
    final standaloneSnapshot = await _standalonePinsCol(uid).get();
    for (final pinDoc in standaloneSnapshot.docs) {
      final pd = pinDoc.data();
      final pin = Pin(
        uuid: pinDoc.id,
        runId: null, // 일반 핀
        userId: uid,
        lat: (pd['lat'] as num).toDouble(),
        lng: (pd['lng'] as num).toDouble(),
        category: PinCategory.fromKey(pd['category'] as String?),
        photoUrl: pd['photoUrl'] as String?,
        photoStoragePath: pd['photoStoragePath'] as String?,
        memo: pd['memo'] as String?,
        createdAt: (pd['createdAt'] as Timestamp).toDate(),
        placeName: pd['placeName'] as String?,
        placeCity: pd['placeCity'] as String?,
        placeCandidates: _decodeCandidatesFromFirestore(pd['placeCandidates']),
      );
      await RouteDBService.upsertPinFromCloud(pin);
    }

    // **신규**: 일상 경로(DayTrack) 다운로드 — 기간 제한 없이 전체.
    // 이 기기에 이미 해당 dayId 데이터가 있으면 이 기기가 "출처"이므로 건너뜀
    // (덮어쓰면 이 기기가 아직 클라우드에 안 올린 최신 점들을 잃을 수 있음).
    final dayTracksSnapshot = await _dayTracksCol(uid).get();
    for (final doc in dayTracksSnapshot.docs) {
      final dayId = doc.id;
      final alreadyLocal = await RouteDBService.hasDayTrack(
        dayId,
        userId: uid,
      );
      if (alreadyLocal) continue;

      final data = doc.data();
      final encoded = data['encodedPath'] as String? ?? '';
      if (encoded.isEmpty) continue;

      final decoded = PolylineCodec.decode(encoded);
      await RouteDBService.bulkInsertDayTrackPoints(
        dayId: dayId,
        userId: uid,
        points: [
          for (final p in decoded) (lat: p.latitude, lng: p.longitude),
        ],
      );
    }

    return newCount;
  }
}
