import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracen/utils/map_projection.dart';

/// 순수 투영/피팅 수학 테스트 — `CountryOutlinePainter` 자체는 테스트하지
/// 않음(이 저장소에 CustomPainter 테스트 전례가 없고 순수 함수 테스트를
/// 선호함, PLAN 참고). 대신 실제 빌드된 KR/MN 외곽선으로 "박스 안에 맞고
/// 핀 점이 경계 안쪽" 요구를 이 레벨에서 검증.

bool _pointInRing(double lon, double lat, List<List<double>> ring) {
  var inside = false;
  final n = ring.length;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final pi = ring[i];
    final pj = ring[j];
    final crosses = (pi[1] > lat) != (pj[1] > lat);
    if (!crosses) continue;
    final xIntersect = pi[0] + (lat - pi[1]) * (pj[0] - pi[0]) / (pj[1] - pi[1]);
    if (lon < xIntersect) inside = !inside;
  }
  return inside;
}

Map<String, dynamic> _loadCountry(String iso) {
  final file = File('assets/countries/$iso.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('mercatorProject', () {
    test('적도에서 y=0', () {
      final p = mercatorProject(0, 0);
      expect(p.dy, closeTo(0, 1e-9));
    });

    test('위도가 커질수록 y도 단조 증가(북쪽일수록 큼)', () {
      final y10 = mercatorProject(0, 10).dy;
      final y30 = mercatorProject(0, 30).dy;
      final y60 = mercatorProject(0, 60).dy;
      expect(y30, greaterThan(y10));
      expect(y60, greaterThan(y30));
    });

    test('경도는 선형(x = lon * π/180)', () {
      final p = mercatorProject(90, 0);
      expect(p.dx, closeTo(3.14159265 / 2, 1e-6));
    });
  });

  group('fitBBoxToSize', () {
    test('정사각형 bbox를 정사각형 타겟에 맞추면 corner가 타겟 경계 안쪽', () {
      const target = Size(200, 200);
      final fit = fitBBoxToSize([0, 0, 10, 10], target, padding: 10);
      final topLeft = fit.applyLonLat(0, 10); // 북서쪽 모서리
      final bottomRight = fit.applyLonLat(10, 0); // 남동쪽 모서리

      expect(topLeft.dx, greaterThanOrEqualTo(0));
      expect(topLeft.dy, greaterThanOrEqualTo(0));
      expect(bottomRight.dx, lessThanOrEqualTo(target.width));
      expect(bottomRight.dy, lessThanOrEqualTo(target.height));
    });

    test('가로로 긴 bbox(몽골형)도 비율 유지하며 타겟 안에 들어감', () {
      const target = Size(100, 100);
      final fit = fitBBoxToSize([0, 0, 40, 10], target, padding: 6);
      final corners = [
        fit.applyLonLat(0, 0),
        fit.applyLonLat(40, 0),
        fit.applyLonLat(0, 10),
        fit.applyLonLat(40, 10),
      ];
      for (final c in corners) {
        expect(c.dx, inInclusiveRange(-0.5, target.width + 0.5));
        expect(c.dy, inInclusiveRange(-0.5, target.height + 0.5));
      }
    });

    test('세로로 긴 bbox(한국형)도 비율 유지하며 타겟 안에 들어감', () {
      const target = Size(100, 100);
      final fit = fitBBoxToSize([0, 0, 8, 30], target, padding: 6);
      final corners = [
        fit.applyLonLat(0, 0),
        fit.applyLonLat(8, 0),
        fit.applyLonLat(0, 30),
        fit.applyLonLat(8, 30),
      ];
      for (final c in corners) {
        expect(c.dx, inInclusiveRange(-0.5, target.width + 0.5));
        expect(c.dy, inInclusiveRange(-0.5, target.height + 0.5));
      }
    });
  });

  group('실제 국가 데이터(KR/MN)', () {
    test('KR 외곽선 전체가 피팅 박스 안에 들어오고 서울 핀이 경계 안쪽', () {
      final kr = _loadCountry('KR');
      final bbox = (kr['bbox'] as List).cast<num>().map((n) => n.toDouble()).toList();
      final rings = (kr['rings'] as List)
          .map((ring) => (ring as List).map((p) => (p as List).cast<num>().map((n) => n.toDouble()).toList()).toList())
          .toList();

      const target = Size(112, 112);
      final fit = fitBBoxToSize(bbox, target, padding: 4);

      for (final ring in rings) {
        for (final point in ring) {
          final screen = fit.applyLonLat(point[0], point[1]);
          expect(screen.dx, inInclusiveRange(-1.0, target.width + 1.0));
          expect(screen.dy, inInclusiveRange(-1.0, target.height + 1.0));
        }
      }

      // 서울시청 좌표 — KR 외곽선 경계 안쪽이어야 함(ray-casting).
      const seoulLon = 126.9780, seoulLat = 37.5665;
      final insideSomeRing = rings.any((ring) => _pointInRing(seoulLon, seoulLat, ring));
      expect(insideSomeRing, isTrue);
    });

    test('MN 외곽선 전체가 피팅 박스 안에 들어오고 울란바토르 핀이 경계 안쪽', () {
      final mn = _loadCountry('MN');
      final bbox = (mn['bbox'] as List).cast<num>().map((n) => n.toDouble()).toList();
      final rings = (mn['rings'] as List)
          .map((ring) => (ring as List).map((p) => (p as List).cast<num>().map((n) => n.toDouble()).toList()).toList())
          .toList();

      const target = Size(112, 112);
      final fit = fitBBoxToSize(bbox, target, padding: 4);

      for (final ring in rings) {
        for (final point in ring) {
          final screen = fit.applyLonLat(point[0], point[1]);
          expect(screen.dx, inInclusiveRange(-1.0, target.width + 1.0));
          expect(screen.dy, inInclusiveRange(-1.0, target.height + 1.0));
        }
      }

      const ubLon = 106.9057, ubLat = 47.8864;
      final insideSomeRing = rings.any((ring) => _pointInRing(ubLon, ubLat, ring));
      expect(insideSomeRing, isTrue);
    });
  });
}
