import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/activity_type.dart';
import '../../../services/run_metrics.dart';
import 'tracking_state.dart';

/// 개발용 가짜 데이터 소스 — 실기기에서 GPS 없이 UI/레이아웃을 돌려볼 때
/// 사용. 릴리스 경로에서는 [ActivityRecorder]만 쓰이고 이 클래스는 전혀
/// 참조되지 않음(구조적으로 이미 분리됨, 별도 플래그 불필요).
///
/// [metrics]/[mapState] 두 ValueNotifier로 패널별 구독을 분리하는 구조와,
/// "데이터는 1초마다, 카메라는 소비자(TrackingMapPanel)가 알아서 스로틀링"
/// 하는 책임 분리는 [ActivityRecorder]와 동일한 인터페이스([TrackingMetrics]/
/// [TrackingMapState], start/pause/resume/stop)를 공유한다.
class MockTrackingController {
  MockTrackingController(this.activityType, {LatLng? startAt})
    : _position = startAt ?? const LatLng(37.5665, 126.9780);

  final ActivityType activityType;

  final ValueNotifier<TrackingMetrics> metrics = ValueNotifier(
    TrackingMetrics.zero,
  );
  final ValueNotifier<TrackingMapState> mapState = ValueNotifier(
    const TrackingMapState(
      position: LatLng(37.5665, 126.9780),
      path: [LatLng(37.5665, 126.9780)],
    ),
  );

  final _rand = math.Random();
  Timer? _ticker;
  DateTime? _startedAt;
  Duration _pausedAccum = Duration.zero;
  DateTime? _pausedAt;
  bool _paused = false;

  LatLng _position;
  final List<LatLng> _path = [const LatLng(37.5665, 126.9780)];
  double _distanceMeters = 0;
  double _headingRad = 0;
  double _altitude = 50;
  int _steps = 0;
  double _maxSpeedKmh = 0;

  /// 활동별 기준 속도(m/s) — 매 틱 여기서 ±지터.
  double get _baseSpeedMps => switch (activityType) {
    ActivityType.running => 2.8, // 약 6'00"/km
    ActivityType.walking => 1.3, // 약 12'50"/km
    ActivityType.cycling => 5.6, // 약 20km/h
  };

  void start() {
    _startedAt ??= DateTime.now();
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    if (_paused) return;
    _paused = true;
    _pausedAt = DateTime.now();
    _publishMetrics();
  }

  void resume() {
    if (!_paused) return;
    final pausedAt = _pausedAt;
    if (pausedAt != null) {
      _pausedAccum += DateTime.now().difference(pausedAt);
    }
    _pausedAt = null;
    _paused = false;
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  void dispose() {
    stop();
    metrics.dispose();
    mapState.dispose();
  }

  void _tick() {
    if (_paused) return;

    // 1) 이동 시뮬레이션 — heading을 조금씩 흔들어서 자연스러운 곡선 경로.
    _headingRad += (_rand.nextDouble() - 0.5) * 0.5;
    final jitter = 1 + (_rand.nextDouble() - 0.5) * 0.3; // ±15%
    final speedMps = (_baseSpeedMps * jitter).clamp(0.2, 20.0);

    const earthRadiusM = 6371000.0;
    final dx = speedMps * math.sin(_headingRad); // 동서
    final dy = speedMps * math.cos(_headingRad); // 남북
    final latRad = _position.latitude * math.pi / 180;
    final newLat = _position.latitude + (dy / earthRadiusM) * (180 / math.pi);
    final newLng =
        _position.longitude +
        (dx / (earthRadiusM * math.cos(latRad))) * (180 / math.pi);
    _position = LatLng(newLat, newLng);
    _path.add(_position);
    _distanceMeters += speedMps * 1; // 1초 틱

    // 2) 고도 랜덤워크.
    _altitude = (_altitude + (_rand.nextDouble() - 0.5) * 2).clamp(0, 300);

    // 3) 걸음 수(러닝/워킹만) — 거리 비례 + 노이즈.
    if (activityType.tracksSteps) {
      final stepsPerMeter = activityType == ActivityType.running ? 1.3 : 1.5;
      _steps += (speedMps * stepsPerMeter).round();
    }

    // 4) 속도/페이스.
    final currentSpeedKmh = speedMps * 3.6;
    if (currentSpeedKmh > _maxSpeedKmh) _maxSpeedKmh = currentSpeedKmh;

    mapState.value = TrackingMapState(
      position: _position,
      path: List.unmodifiable(_path),
    );
    _publishMetrics(currentSpeedKmh: currentSpeedKmh);
  }

  void _publishMetrics({double? currentSpeedKmh}) {
    final elapsed = _elapsedNow();
    final avgPace = RunMetrics.averagePaceSecondsPerKm(
      distanceMeters: _distanceMeters,
      elapsed: elapsed,
    );
    final avgSpeed = RunMetrics.averageSpeedKmh(
      distanceMeters: _distanceMeters,
      elapsed: elapsed,
    );
    final curSpeed = currentSpeedKmh ?? metrics.value.currentSpeedKmh;
    metrics.value = TrackingMetrics(
      elapsed: elapsed,
      distanceMeters: _distanceMeters,
      currentPaceSecondsPerKm: curSpeed > 0 ? 3600 / curSpeed : 0,
      avgPaceSecondsPerKm: avgPace,
      currentSpeedKmh: curSpeed,
      avgSpeedKmh: avgSpeed,
      maxSpeedKmh: _maxSpeedKmh,
      altitudeMeters: _altitude,
      steps: _steps,
      isPaused: _paused,
    );
  }

  Duration _elapsedNow() {
    final startedAt = _startedAt;
    if (startedAt == null) return Duration.zero;
    var total = DateTime.now().difference(startedAt) - _pausedAccum;
    final pausedAt = _pausedAt;
    if (pausedAt != null) total -= DateTime.now().difference(pausedAt);
    return total.isNegative ? Duration.zero : total;
  }
}
