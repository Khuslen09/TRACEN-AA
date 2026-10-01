import '../l10n/strings.dart';
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';
import '../services/route_db_service.dart';

// ─────────────────────────────────────────────────────────────
// Android 전용 — 포그라운드 서비스 Task Handler (v8.17+ API)
// ─────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_TrackingTaskHandler());
}

class _TrackingTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _sub;
  int _pointsSinceFlush = 0;

  // v8.17+: onStart 시그니처 변경 (SendPort? → TaskStarter)
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // B-1: 백그라운드 isolate 는 Firebase 를 별도로 초기화해야 함.
    // main isolate 의 initializeApp 은 이 isolate 에 전파되지 않는다.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }


    _sub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((p) async {
      final uid = AuthService.currentUser?.uid;
      // B-2: uid 가 없으면 (미로그인) 기록하지 않음.
      if (uid == null) return;
      final dayId = _todayId();
      await RouteDBService.insertDayTrackPoint(
        dayId: dayId,
        userId: uid,
        lat: p.latitude,
        lng: p.longitude,
      );

      // 매 포인트마다 큐에는 넣되(중복제거됨), 실제 flush는 6포인트(~30m)마다만.
      // → 배터리/Firestore 쓰기 비용 절약, 다른 기기와는 최대 30m 지연으로 동기화.
      _pointsSinceFlush++;
      final shouldFlush = _pointsSinceFlush >= 6;
      if (shouldFlush) _pointsSinceFlush = 0;
      await CloudSyncService.syncDayTrackUpdated(dayId, flushNow: shouldFlush);
    });
  }

  // v8.17+: SendPort? 파라미터 제거됨
  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _sub?.cancel();
  }

  static String _todayId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────
// TrackingService — Android / iOS 분기 처리
// ─────────────────────────────────────────────────────────────

class TrackingService {
  TrackingService._();

  static const _prefKey = 'auto_tracking_enabled';
  static StreamSubscription<Position>? _fgSub;
  static int _pointsSinceFlush = 0;
  static bool _iosBackground = false;

  // ─────────────────────────────────────────────
  // 초기화
  // ─────────────────────────────────────────────

  static Future<void> init() async {
    if (Platform.isAndroid) _initForegroundTask();
    final enabled = await isEnabled();
    // B-2: 로그인 상태일 때만 자동 시작.
    if (enabled && AuthService.isLoggedIn) await start();
  }

  static void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'aa_tracking',
        channelName: Strings.current.trackingChannelName,
        channelDescription: Strings.current.trackingChannelDesc,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        // v8.17+: iconData 파라미터 제거됨
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // v8.17+: interval → eventAction
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 설정
  // ─────────────────────────────────────────────

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // B-2: 기본값을 false 로 — 첫 설치 시 사용자 동의 없이 추적 시작 방지.
    return prefs.getBool(_prefKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (value) {
      await start();
    } else {
      await stop();
    }
  }

  // ─────────────────────────────────────────────
  // 시작
  // ─────────────────────────────────────────────

  static Future<void> start() async {
    try {
      await LocationService.ensurePermission();
    } catch (_) {
      return;
    }

    if (Platform.isAndroid) {
      await _startAndroid();
    } else if (Platform.isIOS) {
      await _startIOS();
    }
  }

  static Future<void> _startAndroid() async {
    // 새 구독을 먼저 걸고 이전 것을 나중에 취소 — cancel을 await하는 사이에
    // start()가 동시에 또 불려도 리스너가 겹쳐서 새지 않게 한다.
    final previous = _fgSub;
    _fgSub = LocationService.positionStream().listen(
      _onPosition,
      onError: (e) {
        if (kDebugMode) debugPrint('[Tracking] Android GPS 오류: $e');
      },
    );
    await previous?.cancel();

    final result = await FlutterForegroundTask.startService(
      serviceId: 1000,
      notificationTitle: Strings.current.trackingNotifTitle,
      notificationText: Strings.current.trackingNotifText,
      callback: startCallback,
    );
    if (kDebugMode) debugPrint('[Tracking] Android 서비스 시작: $result');
  }

  static Future<void> _startIOS() async {
    // B-3: "항상 허용" 권한이 있을 때만 allowBackgroundLocationUpdates 활성화.
    // "앱 사용 중만 허용" 상태에서는 백그라운드 업데이트를 켜면 iOS 가 무음으로 무시한다.
    final permission = await Geolocator.checkPermission();
    final hasAlways = permission == LocationPermission.always;
    _iosBackground = hasAlways;

    // 새 구독을 먼저 걸고 이전 것을 나중에 취소 (동시 start() 시 리스너 중복 방지).
    final previous = _fgSub;
    _fgSub = Geolocator.getPositionStream(
      locationSettings: AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: hasAlways,
        showBackgroundLocationIndicator: hasAlways,
      ),
    ).listen(
      _onPosition,
      onError: (e) {
        if (kDebugMode) debugPrint('[Tracking] iOS GPS 오류: $e');
      },
    );
    await previous?.cancel();

    if (kDebugMode) {
      debugPrint('[Tracking] iOS 위치 추적 시작 (백그라운드: $hasAlways)');
    }
  }

  /// iOS: "항상 허용"을 (필요하면 한 번) 요청하고, 권한 상태가 추적 시작 때와
  /// 달라졌으면 추적을 재시작해서 백그라운드 업데이트를 켜거나 끈다.
  /// 앱이 처음 뜰 때와 설정 앱에서 돌아왔을 때(resumed) 호출한다.
  static Future<void> ensureBackgroundLocation() async {
    if (!Platform.isIOS || !isRunning) return;
    await PermissionService.requestLocationAlways();
    final permission = await Geolocator.checkPermission();
    if ((permission == LocationPermission.always) != _iosBackground) {
      await _startIOS();
    }
  }

  // ─────────────────────────────────────────────
  // 정지
  // ─────────────────────────────────────────────

  static Future<void> stop() async {
    await _fgSub?.cancel();
    _fgSub = null;
    if (Platform.isAndroid) {
      await FlutterForegroundTask.stopService();
    }
    if (kDebugMode) debugPrint('[Tracking] 추적 정지');
  }

  static bool get isRunning => _fgSub != null;

  // ─────────────────────────────────────────────
  // GPS 수신 → DB 저장
  // ─────────────────────────────────────────────

  static Future<void> _onPosition(Position p) async {
    final uid = AuthService.currentUser?.uid;
    // B-2: 로그인 상태가 아니면 저장하지 않음.
    if (uid == null) return;
    final dayId = _todayId();
    await RouteDBService.insertDayTrackPoint(
      dayId: dayId,
      userId: uid,
      lat: p.latitude,
      lng: p.longitude,
    );

    _pointsSinceFlush++;
    final shouldFlush = _pointsSinceFlush >= 6;
    if (shouldFlush) _pointsSinceFlush = 0;
    await CloudSyncService.syncDayTrackUpdated(dayId, flushNow: shouldFlush);
  }

  static String _todayId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
