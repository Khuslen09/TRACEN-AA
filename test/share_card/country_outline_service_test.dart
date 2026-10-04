import 'package:flutter_test/flutter_test.dart';
import 'package:tracen/services/country_outline_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CountryOutlineService.findCountryAt', () {
    test('서울시청 좌표 → KR', () async {
      final outline = await CountryOutlineService.findCountryAt(37.5665, 126.9780);
      expect(outline?.iso, 'KR');
    });

    test('울란바토르 좌표 → MN', () async {
      final outline = await CountryOutlineService.findCountryAt(47.8864, 106.9057);
      expect(outline?.iso, 'MN');
    });

    test('태평양 한가운데 좌표 → null(어떤 나라에도 속하지 않음)', () async {
      final outline = await CountryOutlineService.findCountryAt(10.0, -150.0);
      expect(outline, isNull);
    });

    test('같은 좌표를 두 번 조회해도 캐시된 외곽선으로 같은 결과', () async {
      final first = await CountryOutlineService.findCountryAt(37.5665, 126.9780);
      final second = await CountryOutlineService.findCountryAt(37.5665, 126.9780);
      expect(first?.iso, second?.iso);
    });
  });
}
