import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracen/services/poi_service.dart';

void main() {
  // PoiService가 Env.hasKakaoKey/googleMapsApiKey를 읽으므로, dotenv가
  // 로드되지 않은 상태에서 호출하면 NotInitializedError가 남 — 실제 앱은
  // main()에서 Env.load()를 먼저 호출하므로 문제 없지만, 테스트에선 빈
  // 값으로라도 초기화해둬야 함(testLoad는 flutter_dotenv가 테스트용으로
  // 제공하는 메서드).
  setUpAll(() {
    dotenv.testLoad(fileInput: '');
  });

  group('PoiService — 키 없을 때 조용히 빈 리스트 반환', () {
    test('kakaoSearchNearby는 KAKAO_REST_API_KEY 없으면 네트워크 호출 없이 빈 리스트', () async {
      final result = await PoiService.kakaoSearchNearby(37.5665, 126.9780, 'ko');
      expect(result, isEmpty);
    });

    test('googlePlacesSearchNearby는 GOOGLE_MAPS_API_KEY 없으면 네트워크 호출 없이 빈 리스트', () async {
      final result = await PoiService.googlePlacesSearchNearby(37.5665, 126.9780, 'en');
      expect(result, isEmpty);
    });
  });
}
