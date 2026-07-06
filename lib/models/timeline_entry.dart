import 'pin.dart';

/// 타임라인 화면에서 사용하는 핀 + (있다면) 러닝 메타 묶음.
///
/// **MVP 변경 (v5)**: 핀이 독립 엔티티라 러닝 정보(`runTitle`, `runStartedAt`)는
/// nullable. 일반 핀이면 둘 다 null, 러닝 중 만든 핀이면 채워짐.
///
/// RouteDBService.getAllPinsWithRoute의 raw row를 객체로 매핑.
/// Picture/Memo Timeline 화면 양쪽에서 공유.
class TimelineEntry {
  final Pin pin;
  final String? runTitle;
  final DateTime? runStartedAt;

  TimelineEntry({required this.pin, this.runTitle, this.runStartedAt});

  /// 호환성 — 옛 코드가 `entry.routeTitle`을 참조할 수 있어 alias 제공.
  String get routeTitle => runTitle ?? '';
  DateTime get routeStartedAt => runStartedAt ?? pin.createdAt;

  factory TimelineEntry.fromMap(Map<String, dynamic> map) {
    final startedRaw = map['route_started_at'] as String?;
    return TimelineEntry(
      pin: Pin.fromMap(map),
      runTitle: map['route_title'] as String?,
      runStartedAt: startedRaw == null ? null : DateTime.parse(startedRaw),
    );
  }
}
