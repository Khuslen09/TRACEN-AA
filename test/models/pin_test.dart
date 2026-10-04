import 'package:flutter_test/flutter_test.dart';
import 'package:tracen/models/pin.dart';
import 'package:tracen/models/place_candidate.dart';

void main() {
  group('Pin — placeName/placeCity/placeCandidates round-trip', () {
    test('toMap/fromMap round-trip with candidates', () {
      final pin = Pin(
        uuid: 'u1',
        lat: 37.5665,
        lng: 126.9780,
        createdAt: DateTime(2026, 10, 4),
        placeName: '한양대학교 ERICA캠퍼스',
        placeCity: '안산시',
        placeCandidates: const [
          PlaceCandidate(name: 'A', city: '안산시', subLocality: '사동', countryCode: 'KR', distanceM: 12.3),
          PlaceCandidate(name: 'B', distanceM: 88),
        ],
      );

      final map = pin.toMap();
      expect(map['place_name'], '한양대학교 ERICA캠퍼스');
      expect(map['place_city'], '안산시');
      expect(map['place_candidates'], isA<String>());

      final restored = Pin.fromMap(map);
      expect(restored.placeName, pin.placeName);
      expect(restored.placeCity, pin.placeCity);
      expect(restored.placeCandidates.length, 2);
      expect(restored.placeCandidates[0].name, 'A');
      expect(restored.placeCandidates[0].distanceM, closeTo(12.3, 1e-9));
      expect(restored.placeCandidates[1].name, 'B');
    });

    test('빈 candidates는 place_candidates 컬럼에 null로 저장되고, 복원하면 다시 []', () {
      final pin = Pin(uuid: 'u2', lat: 0, lng: 0, createdAt: DateTime(2026, 1, 1));
      final map = pin.toMap();
      expect(map['place_candidates'], isNull);

      final restored = Pin.fromMap(map);
      expect(restored.placeCandidates, isEmpty);
    });

    test('손상된 place_candidates JSON은 던지지 않고 []로 복원', () {
      final map = Pin(uuid: 'u3', lat: 0, lng: 0, createdAt: DateTime(2026, 1, 1)).toMap();
      map['place_candidates'] = '{not valid json';

      final restored = Pin.fromMap(map);
      expect(restored.placeCandidates, isEmpty);
    });

    test('copyWith으로 위치명만 갱신 가능', () {
      final pin = Pin(uuid: 'u4', lat: 0, lng: 0, createdAt: DateTime(2026, 1, 1));
      final updated = pin.copyWith(placeName: '새 이름');
      expect(updated.placeName, '새 이름');
      expect(updated.lat, pin.lat);
    });
  });
}
