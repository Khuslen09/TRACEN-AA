import 'route_point.dart';

/// 24시간 백그라운드 추적의 **일별 묶음**.
///
/// 하루치 GPS 점들을 [dayId] (예: '2026-01-15')로 그룹핑.
/// 명시적 시작/종료 없음 — 사용자가 폰만 들고 다니면 자동으로 쌓임.
///
/// **MVP 변경 메모 (DB v5)**: 24시간 추적 도입 시 신규.
/// 러닝([Run])과는 별개 — 추적은 항상 돌아가고, 러닝은 명시적 세션.
///
/// - [dayId]: 'YYYY-MM-DD' 형식. 사용자 timezone 기준의 날짜.
/// - [points]: 그날 수집된 GPS 점들 (시간순).
/// - [userId]: 사용자 격리.
class DayTrack {
  final String dayId;
  final List<RoutePoint> points;
  final String? userId;

  const DayTrack({
    required this.dayId,
    required this.points,
    this.userId,
  });

  /// 'YYYY-MM-DD' 포맷 헬퍼.
  static String formatDayId(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}';
  }

  static String todayId() => formatDayId(DateTime.now());
}
