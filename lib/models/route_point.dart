/// 여정 중 GPS로 추적된 한 점.
///
/// 여러 개의 RoutePoint가 모여 지도 위 Polyline이 됩니다.
/// 한 Route(여정)에 종속되며 [routeId]로 연결됩니다.
///
/// [altitude]/[altitudeAccuracy]는 DB v6 신규 — 결과 화면의 고도 상승
/// 계산에 쓰임(수직 정확도가 나쁜 점은 그 계산에서 제외됨).
class RoutePoint {
  final int? id;
  final int routeId;
  final double lat;
  final double lng;
  final DateTime time;
  final double altitude;
  final double altitudeAccuracy;

  RoutePoint({
    this.id,
    required this.routeId,
    required this.lat,
    required this.lng,
    required this.time,
    this.altitude = 0,
    this.altitudeAccuracy = 0,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'route_id': routeId,
    'lat': lat,
    'lng': lng,
    'time': time.toIso8601String(),
    'altitude': altitude,
    'altitude_accuracy': altitudeAccuracy,
  };

  factory RoutePoint.fromMap(Map<String, dynamic> map) => RoutePoint(
    id: map['id'] as int?,
    routeId: map['route_id'] as int,
    lat: (map['lat'] as num).toDouble(),
    lng: (map['lng'] as num).toDouble(),
    time: DateTime.parse(map['time'] as String),
    altitude: (map['altitude'] as num?)?.toDouble() ?? 0,
    altitudeAccuracy: (map['altitude_accuracy'] as num?)?.toDouble() ?? 0,
  );
}
