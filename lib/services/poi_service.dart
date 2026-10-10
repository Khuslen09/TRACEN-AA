import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/place_candidate.dart';
import 'env_service.dart';
import 'run_metrics.dart';

/// 좌표 근처 POI(관심 장소) 검색 — 한국은 Kakao Local API, 그 외는
/// Google Places API (New). [PlaceNameService.poiCandidatesFor]가 나라
/// 판별 후 둘 중 하나를 호출한다.
///
/// `place_recommend_service.dart`와 같은 HTTP 관례(timeout + try/catch +
/// jsonDecode + debugPrint)를 따르되, 이 서비스는 실패해도 에러를 표시하지
/// 않고 조용히 폴백하는 게 스펙이라 — 지역화 문자열을 throw하지 않고 그냥
/// 빈 리스트를 반환한다.
class PoiService {
  PoiService._();

  static const _kakaoEndpoint = 'https://dapi.kakao.com/v2/local/search/category.json';
  static const _googleEndpoint = 'https://places.googleapis.com/v1/places:searchNearby';

  /// 음식점/카페/관광명소/문화시설 — 공유 카드 위치명으로 쓰기 적당한 범주.
  static const _kakaoCategoryGroupCodes = ['FD6', 'CE7', 'AT4', 'CT1'];

  static const _radiusM = 100;
  static const _maxCandidates = 5;

  static Future<List<PlaceCandidate>> kakaoSearchNearby(
    double lat,
    double lng,
    String languageCode,
  ) async {
    if (!Env.hasKakaoKey) return const [];

    final all = <PlaceCandidate>[];
    for (final code in _kakaoCategoryGroupCodes) {
      final uri = Uri.parse(_kakaoEndpoint).replace(queryParameters: {
        'category_group_code': code,
        'x': '$lng',
        'y': '$lat',
        'radius': '$_radiusM',
        'sort': 'distance',
      });
      try {
        final res = await http
            .get(uri, headers: {'Authorization': 'KakaoAK ${Env.kakaoRestApiKey}'})
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) {
          debugPrint('[Poi] Kakao $code → HTTP ${res.statusCode}');
          continue;
        }
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        for (final doc in (data['documents'] as List? ?? [])) {
          final m = doc as Map<String, dynamic>;
          final name = m['place_name'] as String?;
          final distance = double.tryParse('${m['distance']}');
          if (name == null || distance == null) continue;
          final addressParts = (m['address_name'] as String? ?? '').split(' ');
          all.add(PlaceCandidate(
            name: name,
            city: addressParts.length > 1 ? addressParts[1] : null,
            subLocality: addressParts.length > 2 ? addressParts[2] : null,
            countryCode: 'KR',
            distanceM: distance,
          ));
        }
      } catch (e) {
        debugPrint('[Poi] Kakao $code → 예외: $e');
      }
    }

    final seen = <String>{};
    final deduped = all.where((c) => seen.add(c.name)).toList()
      ..sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return deduped.take(_maxCandidates).toList();
  }

  static Future<List<PlaceCandidate>> googlePlacesSearchNearby(
    double lat,
    double lng,
    String languageCode,
  ) async {
    final key = Env.googleMapsApiKey;
    if (key.isEmpty) return const [];

    try {
      final res = await http
          .post(
            Uri.parse(_googleEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': key,
              'X-Goog-FieldMask': 'places.displayName,places.location,places.types',
              ...Env.googleApiHeaders,
            },
            body: jsonEncode({
              'maxResultCount': _maxCandidates,
              'locationRestriction': {
                'circle': {
                  'center': {'latitude': lat, 'longitude': lng},
                  'radius': _radiusM.toDouble(),
                },
              },
              'rankPreference': 'DISTANCE',
              'languageCode': languageCode,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        debugPrint('[Poi] Google Places → HTTP ${res.statusCode}: ${res.body}');
        return const [];
      }

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final places = (data['places'] as List? ?? []);
      final candidates = <PlaceCandidate>[];
      for (final p in places) {
        final m = p as Map<String, dynamic>;
        final name = m['displayName']?['text'] as String?;
        final loc = m['location'] as Map<String, dynamic>?;
        if (name == null || loc == null) continue;
        final placeLat = (loc['latitude'] as num).toDouble();
        final placeLng = (loc['longitude'] as num).toDouble();
        candidates.add(PlaceCandidate(
          name: name,
          distanceM: RunMetrics.haversineMeters(lat, lng, placeLat, placeLng),
        ));
      }
      candidates.sort((a, b) => a.distanceM.compareTo(b.distanceM));
      return candidates.take(_maxCandidates).toList();
    } catch (e) {
      debugPrint('[Poi] Google Places → 예외: $e');
      return const [];
    }
  }
}
