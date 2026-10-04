/// `assets/countries/{ISO}.json`에서 로드한 나라 외곽선 — [CountryOutlineService]가
/// 오프라인으로 읽어 [CountryOutlinePainter]가 그린다. `rings`는 exterior 링만
/// (hole 없음), lon/lat degree 좌표. `TracenOverlayData.path`의 레코드 타입
/// 관례를 그대로 따름.
class CountryOutline {
  final String iso;
  final String name;

  /// [minLon, minLat, maxLon, maxLat]
  final List<double> bbox;
  final List<List<({double lon, double lat})>> rings;

  const CountryOutline({
    required this.iso,
    required this.name,
    required this.bbox,
    required this.rings,
  });

  double get minLon => bbox[0];
  double get minLat => bbox[1];
  double get maxLon => bbox[2];
  double get maxLat => bbox[3];

  factory CountryOutline.fromJson(Map<String, dynamic> json) {
    final rawBbox = (json['bbox'] as List).cast<num>();
    final rawRings = (json['rings'] as List).cast<List>();
    return CountryOutline(
      iso: json['iso'] as String,
      name: json['name'] as String,
      bbox: rawBbox.map((n) => n.toDouble()).toList(),
      rings: [
        for (final ring in rawRings)
          [
            for (final point in ring.cast<List>())
              (lon: (point[0] as num).toDouble(), lat: (point[1] as num).toDouble()),
          ],
      ],
    );
  }
}
