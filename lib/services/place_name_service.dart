import 'package:geocoding/geocoding.dart';

import '../l10n/strings.dart';
import '../models/place_candidate.dart';
import '../utils/geocoding_locale.dart';
import 'country_outline_service.dart';
import 'poi_service.dart';

/// 공유 카드의 "위치명" 조회.
///
/// - [poiCandidatesFor]: 실제 가까운 장소(POI) 이름 — 한국 좌표면 Kakao
///   Local, 그 외엔 Google Places (New). 공유 카드를 열 때마다 호출하는
///   게 아니라, 핀 저장 시 1회만 호출해 [Pin.placeCandidates]로 캐시한다
///   (`PinPlaceLookupService` 참고).
/// - [placeNameFor]: 기존 방식 — 디바이스 역지오코딩(동/시 단위). POI
///   후보가 하나도 없을 때(오프라인, API 키 없음, 두 서비스 다 실패)의
///   폴백으로만 쓰인다. 베스트에포트라 네트워크/권한이 없어도 절대
///   throw하지 않고 `null`만 돌려준다.
class PlaceNameService {
  PlaceNameService._();

  static Future<List<PlaceCandidate>> poiCandidatesFor(
    double lat,
    double lng, {
    required String languageCode,
  }) async {
    final country = await CountryOutlineService.findCountryAt(lat, lng);
    if (country?.iso == 'KR') {
      return PoiService.kakaoSearchNearby(lat, lng, languageCode);
    }
    return PoiService.googlePlacesSearchNearby(lat, lng, languageCode);
  }

  static Future<String?> placeNameFor(double lat, double lng) async {
    try {
      await setLocaleIdentifier(geocodingLocaleFor(Strings.current.localeName));
      final placemarks = await placemarkFromCoordinates(
        lat,
        lng,
      ).timeout(const Duration(seconds: 4));
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      return p.locality ?? p.subAdministrativeArea ?? p.administrativeArea;
    } catch (_) {
      return null;
    }
  }
}
