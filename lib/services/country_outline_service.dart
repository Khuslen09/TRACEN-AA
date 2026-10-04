import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/country_outline.dart';

/// 핀 좌표 → 나라 판별 + 외곽선 로드. `assets/countries/`를 네트워크 없이
/// 읽기만 하므로 완전히 오프라인으로 동작(`tools/build_countries.py` 참고).
///
/// `_index.json`(bbox만, 가벼움)은 최초 호출 시 1회 로드해 앱 생애주기 동안
/// 캐시. 나라별 전체 외곽선은 실제로 필요할 때만 로드해 무기한 캐시(국가
/// 수가 적고 재사용이 잦아 LRU 같은 제거 정책은 불필요).
class CountryOutlineService {
  CountryOutlineService._();

  static Map<String, List<double>>? _index;
  static final Map<String, CountryOutline> _cache = {};

  static Future<void> _ensureIndexLoaded() async {
    if (_index != null) return;
    final raw = await rootBundle.loadString('assets/countries/_index.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _index = {
      for (final entry in decoded.entries)
        entry.key: (entry.value as List).cast<num>().map((n) => n.toDouble()).toList(),
    };
  }

  static bool _bboxContains(List<double> bbox, double lon, double lat) {
    return lon >= bbox[0] && lon <= bbox[2] && lat >= bbox[1] && lat <= bbox[3];
  }

  static double _bboxArea(List<double> bbox) {
    return (bbox[2] - bbox[0]) * (bbox[3] - bbox[1]);
  }

  static Future<CountryOutline> _loadOutline(String iso) async {
    final cached = _cache[iso];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/countries/$iso.json');
    final outline = CountryOutline.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _cache[iso] = outline;
    return outline;
  }

  /// 표준 ray-casting(crossing-number) point-in-polygon. `rings`는 exterior
  /// 링만(hole 없음)이라 여러 링 중 하나라도 포함하면 내부로 판단(OR).
  static bool _pointInRing(double lon, double lat, List<({double lon, double lat})> ring) {
    var inside = false;
    final n = ring.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final pi = ring[i];
      final pj = ring[j];
      final crosses = (pi.lat > lat) != (pj.lat > lat);
      if (!crosses) continue;
      final xIntersect = pi.lon + (lat - pi.lat) * (pj.lon - pi.lon) / (pj.lat - pi.lat);
      if (lon < xIntersect) inside = !inside;
    }
    return inside;
  }

  static bool _pointInOutline(double lon, double lat, CountryOutline outline) {
    for (final ring in outline.rings) {
      if (_pointInRing(lon, lat, ring)) return true;
    }
    return false;
  }

  /// 좌표가 속한 나라의 외곽선을 찾는다. bbox로 후보를 좁힌 뒤(작은 나라부터
  /// 검사해 겹치는 bbox가 있어도 더 구체적인 쪽이 우선 매치), 각 후보마다
  /// point-in-polygon으로 확인. 공해/매핑 안 된 영역이면 `null`(호출부는
  /// 지도 스티커만 생략하고 나머지는 정상 렌더).
  static Future<CountryOutline?> findCountryAt(double lat, double lng) async {
    await _ensureIndexLoaded();
    final index = _index!;

    final candidates = [
      for (final entry in index.entries)
        if (_bboxContains(entry.value, lng, lat)) entry.key,
    ]..sort((a, b) => _bboxArea(index[a]!).compareTo(_bboxArea(index[b]!)));

    for (final iso in candidates) {
      final outline = await _loadOutline(iso);
      if (_pointInOutline(lng, lat, outline)) return outline;
    }
    return null;
  }
}
