/// 여정(route) 중 한 번의 일시정지 구간(수동 또는 자동).
///
/// [endedAt]이 null이면 현재 진행 중인 일시정지. 경과 이동시간은
/// `(종료시각 - 시작시각) - Σ(일시정지 구간)`으로 계산되며, 이 테이블이
/// 그 "일시정지 구간"의 유일한 출처입니다 — 틱 누적이 아니라 타임스탬프
/// 기반으로 계산하기 위한 핵심 테이블([RouteDBService] 참고).
class RoutePause {
  final int? id;
  final int routeId;
  final DateTime startedAt;
  final DateTime? endedAt;

  RoutePause({
    this.id,
    required this.routeId,
    required this.startedAt,
    this.endedAt,
  });

  bool get isOpen => endedAt == null;

  Duration durationAsOf(DateTime now) =>
      (endedAt ?? now).difference(startedAt);

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'route_id': routeId,
    'started_at': startedAt.toIso8601String(),
    'ended_at': endedAt?.toIso8601String(),
  };

  factory RoutePause.fromMap(Map<String, dynamic> map) => RoutePause(
    id: map['id'] as int?,
    routeId: map['route_id'] as int,
    startedAt: DateTime.parse(map['started_at'] as String),
    endedAt: map['ended_at'] != null
        ? DateTime.parse(map['ended_at'] as String)
        : null,
  );
}
