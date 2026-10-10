/// 홈 지도 전체를 보라 톤으로 칠하는 Google Maps 스타일 JSON.
///
/// 예전엔 원래 지도 위에 반투명 보라 타일([ScratchTileProvider])을 깔아
/// "아직 안 가본 곳"을 표현했는데, 줌/팬 중 타일이 갈아끼워지는 순간마다
/// 원래 색 지도가 비쳐 깨져 보였다. 지도 자체를 보라로 그리면 덮을 타일이
/// 없어서 그런 틈이 생길 수 없다. 가본 길은 그 위에 밝게 긁어낸 자국으로
/// 따로 그린다.
///
/// 색은 [AppColors.primary](#6B4EFF) 계열 — 땅은 연보라, 물은 한 톤 진하게,
/// 도로는 거의 흰 보라, 글자는 짙은 보라 회색.
const purpleMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#e4ddff"}]},
  {"elementType": "labels.icon", "stylers": [{"saturation": -100}, {"lightness": 20}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#5a4d99"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#efebff"}]},
  {"featureType": "administrative", "elementType": "geometry.stroke", "stylers": [{"color": "#b7a8ff"}]},
  {"featureType": "landscape.man_made", "elementType": "geometry", "stylers": [{"color": "#ddd5ff"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#d9d0ff"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#d2c7ff"}]},
  {"featureType": "poi.business", "stylers": [{"visibility": "off"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#f4f1ff"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#d6ccff"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#cfc3ff"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#b9a9ff"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#d6ccff"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#bfb1ff"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#6b4eff"}]}
]
''';
