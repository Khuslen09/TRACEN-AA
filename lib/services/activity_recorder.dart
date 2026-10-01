import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/activity_type.dart';
import '../models/route.dart';
import '../screens/run/tracking/tracking_state.dart';
import 'location_service.dart';
import 'route_db_service.dart';
import 'run_metrics.dart';

/// 실시간 기록의 진짜 엔진 — GPS 구독, 거리/경과시간 계산, DB 저장,
/// 자동 일시정지를 모두 책임진다. [MockTrackingController]와 동일한
/// 표면(metrics/mapState ValueNotifier, start/pause/resume/stop)을 제공해
/// 화면(`ActivityTrackingScreen`) 코드는 둘 중 뭘 쓰든 거의 안 바뀐다.
///
/// 경과시간은 **타임스탬프 기반**: `movingTime = (now - startedAt) -
/// Σ(일시정지 구간)`. 1초 Timer는 화면 갱신(재계산 + publish) 트리거일
/// 뿐, 그 자체로 시간을 누적하지 않는다 — 화면이 꺼져 Timer가 지연돼도
/// 다음 틱에서 실제 경과시간으로 정확히 보정됨.
///
/// 일시정지 구간은 [RouteDBService]의 `route_pauses` 테이블에 즉시
/// insert/update — 메모리에만 두지 않아 강제종료돼도 유실되지 않는다.
class ActivityRecorder {
  ActivityRecorder(this.activityType);

  final ActivityType activityType;

  final ValueNotifier<TrackingMetrics> metrics = ValueNotifier(
    TrackingMetrics.zero,
  );
  /// 첫 GPS 픽스 전까지 보여줄 임시 위치 — home_screen의 기본 카메라와
  /// 같은 값(서울)을 써서 실제 GPS가 들어오기 전 지도가 엉뚱한 곳(0,0 — 기니만)을
  /// 잠깐 보여주는 걸 피한다.
  final ValueNotifier<TrackingMapState> mapState = ValueNotifier(
    const TrackingMapState(position: LatLng(37.5665, 126.9780), path: []),
  );

  /// 지금 어떤 route가 기록 중인지 — 앱 전역에서 1개뿐이어야 한다.
  /// `HomeScreen`의 복구 로직이 이 값을 확인해 같은 route에 GPS 스트림이
  /// 두 번 붙는 걸 막는다.
  static int? activeRouteId;

  int? _routeId;
  int get routeId {
    final id = _routeId;
    if (id == null) throw StateError('ActivityRecorder not started yet');
    return id;
  }

  Timer? _ticker;
  StreamSubscription<Position>? _posSub;

  DateTime? _startedAt;
  DateTime? _lastAcceptedPointTime; // GPS 신호 끊김 감시용
  LatLng? _lastLatLng;
  DateTime? _lastPointTime;

  final List<LatLng> _path = [];
  double _distanceMeters = 0;
  double _currentSpeedMps = 0;
  double _maxSpeedKmh = 0;
  double _lastAltitude = 0;

  bool _manualPaused = false;
  bool _autoPaused = false;
  DateTime? _belowThresholdSince;
  DateTime? _aboveThresholdSince;

  Duration _closedPausesDuration = Duration.zero;
  int? _openPauseId;
  DateTime? _openPauseStartedAt;

  static const _accuracyThreshold = 20.0; // meters
  static const _jumpMinMeters = 3.0;
  static const _jumpMaxMeters = 50.0;
  static const _autoPauseDelay = Duration(seconds: 8);
  static const _autoResumeDelay = Duration(seconds: 3);
  static const _gpsSilenceDelay = Duration(seconds: 8);

  /// 대략적인 보폭(m) — 실제 보수계가 없어 거리 기반으로 추정.
  double get _strideMeters =>
      activityType == ActivityType.running ? 1.1 : 0.75;

  // ─────────────────────────────────────────────
  // 시작 / 재개 / 일시정지 / 정지
  // ─────────────────────────────────────────────

  Future<void> start() async {
    final id = await RouteDBService.startRoute(activityType: activityType);
    _routeId = id;
    activeRouteId = id;
    _startedAt = DateTime.now();
    _beginTicking();
    await _subscribeGps();
  }

  /// 강제종료/백그라운드 전후로 끊긴 기존 route를 이어받는다.
  /// 거리/경로는 DB에서 복원, 죽어있던 시간은 일시정지로 환산.
  ///
  /// 일시정지 토글용 [resume]과는 다른 메서드 — 이건 "다른 route를 이어받아
  /// 새로 시작"하는 쪽이라 이름을 구분했다.
  Future<void> resumeExisting(int existingRouteId) async {
    final route = await RouteDBService.getRoute(existingRouteId);
    if (route == null) {
      throw StateError('Route $existingRouteId not found');
    }

    _routeId = existingRouteId;
    activeRouteId = existingRouteId;
    _startedAt = route.startedAt;
    _distanceMeters = route.distance;

    final points = await RouteDBService.getPoints(existingRouteId);
    _path
      ..clear()
      ..addAll(points.map((p) => LatLng(p.lat, p.lng)));
    if (points.isNotEmpty) {
      final last = points.last;
      _lastLatLng = LatLng(last.lat, last.lng);
      _lastPointTime = last.time;
      _lastAltitude = last.altitude;
    }
    mapState.value = TrackingMapState(
      position: _lastLatLng ?? const LatLng(0, 0),
      path: List.unmodifiable(_path),
    );

    // 기존에 닫힌 일시정지 구간들을 누적.
    final pauses = await RouteDBService.getPauses(existingRouteId);
    final now = DateTime.now();
    for (final p in pauses) {
      if (!p.isOpen) {
        _closedPausesDuration += p.durationAsOf(now);
      } else {
        // 앱이 일시정지 중에 죽었던 경우 — lastActiveAt 시점에 끝난 걸로
        // 마무리하고, 재개는 항상 "이동 중" 상태로 시작한다. lastActiveAt이
        // 일시정지 시작보다 이르면(= GPS 끊김으로 인한 자동 일시정지 직후
        // 바로 죽은 경우) 음수 구간이 되지 않게 시작 시각으로 고정.
        final lastActiveAt = route.lastActiveAt;
        final closedAt = (lastActiveAt != null && lastActiveAt.isAfter(p.startedAt))
            ? lastActiveAt
            : p.startedAt;
        await RouteDBService.closePause(p.id!, closedAt);
        _closedPausesDuration += closedAt.difference(p.startedAt);
      }
    }

    // 프로세스가 죽어있던 구간(lastActiveAt ~ 지금) 자체도 일시정지로 환산.
    final lastActive = route.lastActiveAt ?? route.startedAt;
    final deadGap = now.difference(lastActive);
    if (deadGap > const Duration(seconds: 2)) {
      await RouteDBService.insertPause(
        existingRouteId,
        lastActive,
        endedAt: now,
      );
      _closedPausesDuration += deadGap;
    }

    _openPauseId = null;
    _openPauseStartedAt = null;
    _manualPaused = false;
    _autoPaused = false;
    _lastAcceptedPointTime = now;

    _beginTicking();
    await _subscribeGps();
    _publishMetrics();
  }

  Future<void> pause() async {
    if (_manualPaused) return;
    _manualPaused = true;
    final now = DateTime.now();
    if (_autoPaused) {
      // 자동 일시정지 구간을 그대로 수동 일시정지로 이어받음 — 같은 route_pauses
      // 행을 재사용해 이중으로 열린 구간이 생기지 않게 한다.
      _autoPaused = false;
    } else if (_openPauseId == null) {
      _openPauseStartedAt = now;
      _openPauseId = await RouteDBService.insertPause(routeId, now);
    }
    _belowThresholdSince = null;
    _aboveThresholdSince = null;
    _publishMetrics();
  }

  /// [MockTrackingController.resume]과 동일 — 수동 일시정지 해제.
  Future<void> resume() async {
    if (!_manualPaused) return;
    _manualPaused = false;
    final now = DateTime.now();
    await _closeOpenPause(now);
    _lastAcceptedPointTime = now; // 재개 직후 바로 GPS 끊김 룰 재적용 방지
    _publishMetrics();
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    await _posSub?.cancel();
    _posSub = null;

    final now = DateTime.now();
    await _closeOpenPause(now);
    await RouteDBService.endRoute(
      routeId,
      distance: _distanceMeters,
      status: RouteStatus.pendingReview,
    );
    if (activeRouteId == _routeId) activeRouteId = null;
  }

  void dispose() {
    _ticker?.cancel();
    _posSub?.cancel();
    metrics.dispose();
    mapState.dispose();
    if (activeRouteId == _routeId) activeRouteId = null;
  }

  Future<void> _closeOpenPause(DateTime now) async {
    final id = _openPauseId;
    final startedAt = _openPauseStartedAt;
    if (id != null && startedAt != null) {
      await RouteDBService.closePause(id, now);
      _closedPausesDuration += now.difference(startedAt);
    }
    _openPauseId = null;
    _openPauseStartedAt = null;
  }

  // ─────────────────────────────────────────────
  // GPS 처리
  // ─────────────────────────────────────────────

  Future<void> _subscribeGps() async {
    await _posSub?.cancel();
    _posSub = LocationService.positionStream().listen(_handlePosition);
  }

  void _handlePosition(Position p) {
    if (_manualPaused) return;
    if (p.accuracy > _accuracyThreshold) return;

    final now = p.timestamp;
    _lastAcceptedPointTime = now;
    _lastAltitude = p.altitude;

    if (_lastLatLng != null && _lastPointTime != null) {
      final deltaM = RunMetrics.haversineMeters(
        _lastLatLng!.latitude,
        _lastLatLng!.longitude,
        p.latitude,
        p.longitude,
      );
      if (deltaM < _jumpMinMeters || deltaM > _jumpMaxMeters) return;

      final deltaT = now.difference(_lastPointTime!).inMilliseconds / 1000.0;
      final speedMps = deltaT > 0 ? deltaM / deltaT : 0.0;
      _distanceMeters += deltaM;
      _currentSpeedMps = speedMps;
      final speedKmh = speedMps * 3.6;
      if (speedKmh > _maxSpeedKmh) _maxSpeedKmh = speedKmh;

      _evaluateAutoPause(speedMps, now);
      unawaited(_recordPoint(p, now));
    } else {
      unawaited(_recordPoint(p, now));
    }

    _lastLatLng = LatLng(p.latitude, p.longitude);
    _lastPointTime = now;
  }

  Future<void> _recordPoint(Position p, DateTime now) async {
    final latLng = LatLng(p.latitude, p.longitude);
    _path.add(latLng);
    mapState.value = TrackingMapState(
      position: latLng,
      path: List.unmodifiable(_path),
    );
    await RouteDBService.insertPoint(
      routeId: routeId,
      lat: p.latitude,
      lng: p.longitude,
      time: now,
      altitude: p.altitude,
      altitudeAccuracy: p.altitudeAccuracy,
    );
    await RouteDBService.updateRouteProgress(
      routeId,
      distance: _distanceMeters,
      lastActiveAt: now,
    );
  }

  void _evaluateAutoPause(double speedMps, DateTime now) {
    final threshold = activityType.autoPauseSpeedThreshold;
    if (speedMps < threshold) {
      _belowThresholdSince ??= now;
      _aboveThresholdSince = null;
      if (!_autoPaused &&
          now.difference(_belowThresholdSince!) >= _autoPauseDelay) {
        unawaited(_setAutoPaused(true, now));
      }
    } else {
      _aboveThresholdSince ??= now;
      _belowThresholdSince = null;
      if (_autoPaused &&
          now.difference(_aboveThresholdSince!) >= _autoResumeDelay) {
        unawaited(_setAutoPaused(false, now));
      }
    }
  }

  Future<void> _setAutoPaused(bool value, DateTime now) async {
    if (_autoPaused == value || _manualPaused) return;
    _autoPaused = value;
    if (value) {
      if (_openPauseId == null) {
        _openPauseStartedAt = now;
        _openPauseId = await RouteDBService.insertPause(routeId, now);
      }
    } else {
      await _closeOpenPause(now);
    }
    _publishMetrics();
  }

  // ─────────────────────────────────────────────
  // 1초 틱 — 화면 갱신 + GPS 끊김 감시
  // ─────────────────────────────────────────────

  void _beginTicking() {
    _lastAcceptedPointTime ??= DateTime.now();
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    final lastAccepted = _lastAcceptedPointTime;
    if (!_manualPaused &&
        !_autoPaused &&
        lastAccepted != null &&
        now.difference(lastAccepted) >= _gpsSilenceDelay) {
      unawaited(_setAutoPaused(true, now));
    }
    _publishMetrics();
  }

  void _publishMetrics() {
    final startedAt = _startedAt;
    if (startedAt == null) return;
    final now = DateTime.now();

    var pausedTotal = _closedPausesDuration;
    final openStart = _openPauseStartedAt;
    if (openStart != null) {
      pausedTotal += now.difference(openStart);
    }
    var moving = now.difference(startedAt) - pausedTotal;
    if (moving.isNegative) moving = Duration.zero;

    final isPaused = _manualPaused || _autoPaused;
    final currentSpeedKmh = isPaused ? 0.0 : _currentSpeedMps * 3.6;
    final avgPace = RunMetrics.averagePaceSecondsPerKm(
      distanceMeters: _distanceMeters,
      elapsed: moving,
    );
    final avgSpeed = RunMetrics.averageSpeedKmh(
      distanceMeters: _distanceMeters,
      elapsed: moving,
    );

    metrics.value = TrackingMetrics(
      elapsed: moving,
      distanceMeters: _distanceMeters,
      currentPaceSecondsPerKm: currentSpeedKmh > 0 ? 3600 / currentSpeedKmh : 0,
      avgPaceSecondsPerKm: avgPace,
      currentSpeedKmh: currentSpeedKmh,
      avgSpeedKmh: avgSpeed,
      maxSpeedKmh: _maxSpeedKmh,
      altitudeMeters: _lastAltitude,
      steps: activityType.tracksSteps
          ? (_distanceMeters / _strideMeters).round()
          : 0,
      isPaused: isPaused,
      isAutoPaused: _autoPaused,
    );
  }
}
