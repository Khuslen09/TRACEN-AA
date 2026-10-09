import 'package:flutter/foundation.dart';

import '../models/pin.dart';
import '../models/pin_category.dart';
import 'cloud_photo_service.dart';
import 'cloud_sync_service.dart';
import 'photo_storage.dart';
import 'route_db_service.dart';

/// 이미 저장된 핀의 수정/삭제 — 로컬 DB, 사진 파일, 클라우드 동기화를
/// 한곳에서 처리한다. (화면마다 따로 구현하면 어떤 화면은 클라우드 삭제를
/// 빼먹는 식의 차이가 생겨서 — 실제로 프로필/타임라인의 삭제가 그랬다)
class PinService {
  PinService._();

  /// 핀 수정.
  ///
  /// - [newPhotoPath]: 새로 고른 사진(임시 경로). 주면 영구 저장소로 복사하고
  ///   예전 사진(로컬 + 클라우드)은 지운다.
  /// - [removePhoto]: true면 사진을 없앤다.
  /// - 둘 다 아니면 사진은 그대로.
  ///
  /// id/uuid/생성 시각/위치는 유지 — 같은 핀으로 취급되어 클라우드 문서도
  /// 같은 uuid로 덮어쓴다.
  static Future<Pin> update(
    Pin original, {
    required PinCategory category,
    required String? memo,
    required String? placeName,
    String? newPhotoPath,
    bool removePhoto = false,
  }) async {
    if (original.id == null) {
      throw ArgumentError('저장되지 않은 핀은 수정할 수 없어요');
    }

    var photoPath = original.photoPath;
    var photoUrl = original.photoUrl;
    var photoStoragePath = original.photoStoragePath;
    final photoChanged = newPhotoPath != null || removePhoto;

    if (photoChanged) {
      final oldLocal = original.photoPath;
      final oldStorage = original.photoStoragePath;

      photoPath = newPhotoPath == null
          ? null
          : await PhotoStorage.persist(newPhotoPath);
      // 새 사진은 동기화 때 다시 업로드되도록 URL/Storage 경로를 비운다.
      photoUrl = null;
      photoStoragePath = null;

      if (oldLocal != null && oldLocal != photoPath) {
        await PhotoStorage.delete(oldLocal);
      }
      if (oldStorage != null && oldStorage.isNotEmpty) {
        // 확장자가 달라지면 경로도 달라져 덮어쓰기가 안 되므로 직접 지움.
        // 실패해도(오프라인 등) 핀 수정 자체는 진행.
        CloudPhotoService.deletePhoto(oldStorage).catchError((Object e) {
          debugPrint('[PinService] 예전 사진 삭제 실패: $e');
        });
      }
    }

    final placeChanged = placeName != original.placeName;

    // copyWith는 null로 지우는 걸 못 해서 새로 만든다.
    final updated = Pin(
      id: original.id,
      uuid: original.uuid,
      runId: original.runId,
      userId: original.userId,
      lat: original.lat,
      lng: original.lng,
      category: category,
      photoPath: photoPath,
      photoUrl: photoUrl,
      photoStoragePath: photoStoragePath,
      memo: (memo == null || memo.trim().isEmpty) ? null : memo.trim(),
      createdAt: original.createdAt,
      placeName: placeName,
      placeCity: placeChanged ? null : original.placeCity,
      placeCandidates: original.placeCandidates,
    );

    await RouteDBService.updatePin(updated);
    CloudSyncService.syncPinAdded(updated); // 같은 uuid → 클라우드 문서 덮어쓰기
    return updated;
  }

  /// 핀 삭제 — 로컬 DB + 사진 파일 + 클라우드.
  static Future<void> delete(Pin pin) async {
    if (pin.id == null) return;

    final run = pin.runId == null
        ? null
        : await RouteDBService.getRoute(pin.runId!);

    await RouteDBService.deletePin(pin.id!);
    if (pin.photoPath != null) {
      await PhotoStorage.delete(pin.photoPath!);
    }

    if (pin.runId == null) {
      CloudSyncService.syncPinDeleted(
        pinUuid: pin.uuid,
        routeUuid: '', // 빈 문자열 = 일반 핀
        photoStoragePath: pin.photoStoragePath,
      );
    } else if (run != null && !run.isActive) {
      // 진행 중 러닝의 핀은 러닝 종료 때 한 번에 동기화된다
      CloudSyncService.syncPinDeleted(
        pinUuid: pin.uuid,
        routeUuid: run.uuid,
        photoStoragePath: pin.photoStoragePath,
      );
    }
  }
}
