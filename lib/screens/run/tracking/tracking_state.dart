import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 지표 패널이 구독하는 값. mock/실제 엔진 모두 공유하는 데이터 형태 —
/// [MockTrackingController]와 `ActivityRecorder`가 같은 인터페이스를
/// 쓸 수 있게 해주는 핵심 타입.
@immutable
class TrackingMetrics {
  final Duration elapsed;
  final double distanceMeters;

  /// 러닝/워킹: 초/km. 사이클링: 사용 안 함(0).
  final double currentPaceSecondsPerKm;
  final double avgPaceSecondsPerKm;

  /// 사이클링: km/h. 러닝/워킹: 사용 안 함(0).
  final double currentSpeedKmh;
  final double avgSpeedKmh;
  final double maxSpeedKmh;

  final double altitudeMeters;
  final int steps;

  /// 수동 또는 자동으로 일시정지된 상태인지 — 컨트롤 바 아이콘용.
  final bool isPaused;

  /// 자동 일시정지로 멈춘 상태인지 — "자동으로 멈췄어요" 안내 배지용.
  /// true면 [isPaused]도 항상 true.
  final bool isAutoPaused;

  const TrackingMetrics({
    required this.elapsed,
    required this.distanceMeters,
    required this.currentPaceSecondsPerKm,
    required this.avgPaceSecondsPerKm,
    required this.currentSpeedKmh,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.altitudeMeters,
    required this.steps,
    required this.isPaused,
    this.isAutoPaused = false,
  });

  static const zero = TrackingMetrics(
    elapsed: Duration.zero,
    distanceMeters: 0,
    currentPaceSecondsPerKm: 0,
    avgPaceSecondsPerKm: 0,
    currentSpeedKmh: 0,
    avgSpeedKmh: 0,
    maxSpeedKmh: 0,
    altitudeMeters: 0,
    steps: 0,
    isPaused: false,
  );
}

/// 지도 패널이 구독하는 값. 매 틱 새 인스턴스로 교체됨
/// (단, 실제 카메라 이동 여부는 [TrackingMapPanel] 내부에서 별도로
/// 스로틀링 — 이 클래스 자체는 "데이터"만 담는다).
///
/// [position]은 **정확도 필터와 무관하게** 가장 최근 원본 GPS 픽스를
/// 그대로 담는다(또는 아직 첫 픽스 전이면 null) — 마커는 항상 "지금
/// 기기가 아는 최선의 위치"를 보여줘야 하고, 정확도 필터는 [path](경로/
/// 거리 누적)에만 적용되기 때문. `ActivityRecorder` 참고.
@immutable
class TrackingMapState {
  final LatLng? position;
  final List<LatLng> path;

  const TrackingMapState({required this.position, required this.path});

  static const loading = TrackingMapState(position: null, path: []);
}

/// 디버그 빌드 전용 — 지도 위 작은 오버레이에 표시할 원본 GPS 진단 정보.
/// `kDebugMode`가 아니면 위젯 쪽에서 아예 렌더링하지 않는다(수집 자체는
/// 가볍기 때문에 항상 돌아가도 상관없음).
@immutable
class DebugGpsSnapshot {
  final double? lat;
  final double? lng;
  final double? accuracyMeters;
  final DateTime? timestamp;
  final bool passedAccuracyFilter;
  final LocationPermission? permission;
  final LocationAccuracyStatus? accuracyStatus;

  const DebugGpsSnapshot({
    this.lat,
    this.lng,
    this.accuracyMeters,
    this.timestamp,
    this.passedAccuracyFilter = false,
    this.permission,
    this.accuracyStatus,
  });
}
