/// 촬영 사진에 합성할 TRACEN 오버레이(날짜/도시/거리 스탬프 + 오늘의 경로)용
/// 데이터. [TracenOverlayService.loadToday]가 채워서 돌려준다.
class TracenOverlayData {
  final DateTime date;
  final String? city;
  final double distanceMeters;
  final List<({double lat, double lng})> path;

  const TracenOverlayData({
    required this.date,
    required this.city,
    required this.distanceMeters,
    required this.path,
  });
}
