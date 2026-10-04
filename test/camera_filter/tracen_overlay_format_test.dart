import 'package:flutter_test/flutter_test.dart';
import 'package:tracen/models/tracen_overlay_data.dart';
import 'package:tracen/services/tracen_overlay_service.dart';

void main() {
  group('dayIdFor', () {
    test('월/일을 0으로 패딩', () {
      expect(TracenOverlayService.dayIdFor(DateTime(2026, 1, 5)), '2026-01-05');
      expect(TracenOverlayService.dayIdFor(DateTime(2026, 10, 4)), '2026-10-04');
    });
  });

  group('totalDistanceMeters', () {
    test('점이 0개/1개면 0', () {
      expect(TracenOverlayService.totalDistanceMeters([]), 0);
      expect(
        TracenOverlayService.totalDistanceMeters([(lat: 37.5, lng: 127.0)]),
        0,
      );
    });

    test('연속된 점들의 haversine 합', () {
      // 위도 1도 ≈ 111.19km — 대략적인 거리로 합산이 되는지만 확인.
      final points = [
        (lat: 37.0, lng: 127.0),
        (lat: 37.01, lng: 127.0),
        (lat: 37.02, lng: 127.0),
      ];
      final total = TracenOverlayService.totalDistanceMeters(points);
      expect(total, greaterThan(2000));
      expect(total, lessThan(2500));
    });
  });

  group('formatStampDistance', () {
    test('소수점 1자리 + km', () {
      expect(TracenOverlayService.formatStampDistance(5234), '5.2km');
      expect(TracenOverlayService.formatStampDistance(0), '0.0km');
      expect(TracenOverlayService.formatStampDistance(1000), '1.0km');
    });
  });

  group('buildStampText', () {
    test('도시/거리 모두 있을 때', () {
      final data = TracenOverlayData(
        date: DateTime(2026, 10, 4),
        city: 'Seoul',
        distanceMeters: 5234,
        path: const [],
      );
      expect(
        TracenOverlayService.buildStampText(data),
        '2026.10.04 · Seoul · 5.2km',
      );
    });

    test('도시가 null이면 생략', () {
      final data = TracenOverlayData(
        date: DateTime(2026, 10, 4),
        city: null,
        distanceMeters: 5234,
        path: const [],
      );
      expect(TracenOverlayService.buildStampText(data), '2026.10.04 · 5.2km');
    });

    test('거리가 0이면 생략', () {
      final data = TracenOverlayData(
        date: DateTime(2026, 10, 4),
        city: 'Seoul',
        distanceMeters: 0,
        path: const [],
      );
      expect(TracenOverlayService.buildStampText(data), '2026.10.04 · Seoul');
    });

    test('도시도 거리도 없으면 날짜만', () {
      final data = TracenOverlayData(
        date: DateTime(2026, 10, 4),
        city: null,
        distanceMeters: 0,
        path: const [],
      );
      expect(TracenOverlayService.buildStampText(data), '2026.10.04');
    });
  });
}
