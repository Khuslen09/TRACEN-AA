import 'package:flutter_test/flutter_test.dart';
import 'package:tracen/models/camera_filter.dart';
import 'package:tracen/utils/lut_math.dart';

void main() {
  group('lutPixelFor / lutLevelsAt', () {
    test('전 64^3 레벨에서 라운드트립', () {
      for (var r = 0; r < kLutSize; r += 7) {
        for (var g = 0; g < kLutSize; g += 7) {
          for (var b = 0; b < kLutSize; b++) {
            final (px, py) = lutPixelFor(r, g, b);
            final (r2, g2, b2) = lutLevelsAt(px, py);
            expect((r2, g2, b2), (r, g, b));
          }
        }
      }
    });

    test('코너 픽셀', () {
      expect(lutPixelFor(0, 0, 0), (0, 0));
      expect(lutPixelFor(63, 63, 0), (63, 63));
      expect(lutPixelFor(0, 0, 1), (64, 0)); // b=1 -> tileX=1
      expect(lutPixelFor(0, 0, 8), (0, 64)); // b=8 -> tileY=1
      expect(lutPixelFor(63, 63, 63), (kLutPx - 1, kLutPx - 1));
    });
  });

  group('sampleLutTrilinear', () {
    test('identity LUT은 입력을 그대로 돌려줌(그리드 상 점)', () {
      final rgba = buildLutRgbaFromSampler((r, g, b) => (r, g, b));
      for (final v in [0.0, 0.2, 0.5, 0.8, 1.0]) {
        final (r, g, b) = sampleLutTrilinear(rgba, v, v, v);
        expect(r, closeTo(v, 1 / 255));
        expect(g, closeTo(v, 1 / 255));
        expect(b, closeTo(v, 1 / 255));
      }
    });

    test('identity LUT은 그리드 사이 점에서도 거의 정확', () {
      final rgba = buildLutRgbaFromSampler((r, g, b) => (r, g, b));
      final (r, g, b) = sampleLutTrilinear(rgba, 0.3333, 0.6666, 0.1234);
      expect(r, closeTo(0.3333, 1 / 255));
      expect(g, closeTo(0.6666, 1 / 255));
      expect(b, closeTo(0.1234, 1 / 255));
    });

    test('실제 필터 LUT이 applyRgb와 2/255 이내로 일치', () {
      for (final filter in TracenFilter.values) {
        final recipe = filter.recipe;
        final rgba = buildLutRgbaFromSampler(recipe.applyRgb);
        for (final sample in [
          (0.5, 0.5, 0.5),
          (0.8, 0.3, 0.2),
          (0.1, 0.6, 0.9),
        ]) {
          final expected = recipe.applyRgb(sample.$1, sample.$2, sample.$3);
          final actual = sampleLutTrilinear(rgba, sample.$1, sample.$2, sample.$3);
          expect(
            actual.$1,
            closeTo(expected.$1, 2 / 255),
            reason: '${filter.id} R channel',
          );
          expect(
            actual.$2,
            closeTo(expected.$2, 2 / 255),
            reason: '${filter.id} G channel',
          );
          expect(
            actual.$3,
            closeTo(expected.$3, 2 / 255),
            reason: '${filter.id} B channel',
          );
        }
      }
    });
  });
}
