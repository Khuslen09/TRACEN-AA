import 'package:flutter_test/flutter_test.dart';
import 'package:tracen/models/camera_filter.dart';
import 'package:tracen/models/filter_recipe.dart';
import 'package:tracen/utils/color_matrix_fit.dart';
import 'package:tracen/utils/skin_tone_samples.dart';

(double, double, double) _applyMatrix(List<double> m, double r, double g, double b) {
  // m은 0..255 오프셋 스케일이라 255로 나눠 0..1로 되돌림.
  final or = (m[0] * r + m[1] * g + m[2] * b + m[4] / 255).clamp(0.0, 1.0);
  final og = (m[5] * r + m[6] * g + m[7] * b + m[9] / 255).clamp(0.0, 1.0);
  final ob = (m[10] * r + m[11] * g + m[12] * b + m[14] / 255).clamp(0.0, 1.0);
  return (or, og, ob);
}

void main() {
  setUp(clearColorMatrixCache);

  test('identity 레시피를 피팅하면 identity 행렬', () {
    final m = fitColorMatrix(FilterRecipe.identity);
    for (var i = 0; i < 20; i++) {
      expect(m[i], closeTo(kIdentityMatrix[i], 1e-6));
    }
  });

  group('lerpWithIdentity', () {
    final sample = fitColorMatrix(TracenFilter.goldenRoute.recipe);

    test('t=0은 identity', () {
      final m = lerpWithIdentity(sample, 0);
      for (var i = 0; i < 20; i++) {
        expect(m[i], closeTo(kIdentityMatrix[i], 1e-9));
      }
    });

    test('t=1은 원본 그대로', () {
      final m = lerpWithIdentity(sample, 1);
      for (var i = 0; i < 20; i++) {
        expect(m[i], closeTo(sample[i], 1e-9));
      }
    });

    test('t=0.5는 중간값', () {
      final m = lerpWithIdentity(sample, 0.5);
      for (var i = 0; i < 20; i++) {
        final expected = (kIdentityMatrix[i] + sample[i]) / 2;
        expect(m[i], closeTo(expected, 1e-9));
      }
    });
  });

  group('드리프트 가드', () {
    for (final filter in TracenFilter.values) {
      test('${filter.id}: 피부톤에서 매트릭스 근사 오차가 작음', () {
        final recipe = filter.recipe;
        final matrix = fitColorMatrix(recipe);

        var totalError = 0.0;
        var count = 0;
        for (final hex in monkSkinToneHex) {
          final (r0, g0, b0) = rgbFromHex(hex);
          final expected = recipe.applyRgb(r0, g0, b0);
          final actual = _applyMatrix(matrix, r0, g0, b0);
          totalError += (expected.$1 - actual.$1).abs();
          totalError += (expected.$2 - actual.$2).abs();
          totalError += (expected.$3 - actual.$3).abs();
          count += 3;
        }
        expect(totalError / count, lessThan(0.03));
      });
    }
  });

  test('모노크롬 레시피도 안정적으로 피팅됨(R=G=B 근사)', () {
    final m = fitColorMatrix(TracenFilter.monoPath.recipe);
    for (final rgb in [(0.8, 0.3, 0.1), (0.1, 0.9, 0.5)]) {
      final (r, g, b) = _applyMatrix(m, rgb.$1, rgb.$2, rgb.$3);
      expect(r, closeTo(g, 0.05));
      expect(g, closeTo(b, 0.05));
    }
  });
}
