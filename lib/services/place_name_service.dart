import 'package:geocoding/geocoding.dart';

import '../l10n/strings.dart';
import '../utils/geocoding_locale.dart';

/// 공유 카드의 "위치명"(도시/동네) 조회 — [TracenOverlayService]의 도시명
/// 조회 절반을 독립 함수로 분리한 것. 베스트에포트 온라인 조회라 네트워크/
/// 권한이 없어도 절대 throw하지 않고 `null`만 돌려준다(카드의 나머지
/// 부분 — 나라명/외곽선은 오프라인 데이터라 이와 무관하게 항상 렌더됨).
class PlaceNameService {
  PlaceNameService._();

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
