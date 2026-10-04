/// 핀 근처 POI(관심 장소) 후보 하나 — [PlaceNameService.poiCandidatesFor]가
/// 돌려주고, [Pin.placeCandidates]로 영구 저장된다(핀 저장 시 1회 조회 후
/// 캐시 — 공유 카드를 열 때마다 재조회하지 않음).
class PlaceCandidate {
  final String name;
  final String? subLocality;
  final String? city;
  final String? countryCode;
  final double distanceM;

  const PlaceCandidate({
    required this.name,
    this.subLocality,
    this.city,
    this.countryCode,
    required this.distanceM,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'subLocality': subLocality,
    'city': city,
    'countryCode': countryCode,
    'distanceM': distanceM,
  };

  factory PlaceCandidate.fromJson(Map<String, dynamic> json) => PlaceCandidate(
    name: json['name'] as String,
    subLocality: json['subLocality'] as String?,
    city: json['city'] as String?,
    countryCode: json['countryCode'] as String?,
    distanceM: (json['distanceM'] as num).toDouble(),
  );
}
