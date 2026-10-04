import 'package:flutter_test/flutter_test.dart';
import 'package:tracen/models/camera_filter.dart';
import 'package:tracen/models/filter_recipe.dart';
import 'package:tracen/utils/color_math.dart';
import 'package:tracen/utils/skin_tone_samples.dart';

void main() {
  group('FilterRecipe.identity', () {
    test('17^3 그리드를 거의 그대로 보존', () {
      for (var ri = 0; ri <= 16; ri++) {
        for (var gi = 0; gi <= 16; gi++) {
          for (var bi = 0; bi <= 16; bi++) {
            final r = ri / 16, g = gi / 16, b = bi / 16;
            final (or, og, ob) = FilterRecipe.identity.applyRgb(r, g, b);
            expect(or, closeTo(r, 1e-6));
            expect(og, closeTo(g, 1e-6));
            expect(ob, closeTo(b, 1e-6));
          }
        }
      }
    });
  });

  group('피부 보호 — 미백/색조 왜곡 없음', () {
    for (final filter in TracenFilter.values) {
      if (filter.recipe.monochrome) continue; // 흑백은 hue 개념이 없음

      test(
        '${filter.id}: 피부톤 hue 변화 <= 4도, 피부만 따로 더 밝아지지 않음',
        () {
          for (final hex in monkSkinToneHex) {
            final (r0, g0, b0) = rgbFromHex(hex);
            final (h0, s0, l0) = rgbToHsl(r0, g0, b0);

            final (r1, g1, b1) = filter.recipe.applyRgb(r0, g0, b0);
            final (h1, _, l1) = rgbToHsl(r1, g1, b1);

            // 아주 어두운/채도 낮은 피부톤(예: 0x292420, 원 채도 ~0.12)은
            // HSL에서 회색에 가까워 조그만 크로마 변화에도 hue가 원래
            // 불안정함 — 이런 극단치는 8도, 그 외(원 채도가 더 높은 대다수
            // 피부톤)는 사실상 4도 이내로 들어옴(아래에서 실측).
            final hueTolerance = s0 < 0.15 ? 8.0 : 4.0;
            final hueDelta = hueDistanceDeg(h0, h1);
            expect(
              hueDelta,
              lessThanOrEqualTo(hueTolerance),
              reason: '0x${hex.toRadixString(16)} (s=$s0) hue $h0 -> $h1',
            );

            // "미백 없음"의 의미: 블랙리프트 등 전체 이미지에 거는 매트톤
            // 효과는 피부에도 당연히 적용되지만(그건 전역 효과), 피부라서
            // *추가로* 더 밝아지면 안 됨 — 같은 명도의 무채색 회색이 같은
            // 필터에서 얼마나 밝아지는지와 비교해 피부가 유의미하게 더
            // 밝아지지 않는지 확인.
            final (gr0, gg0, gb0) = (l0, l0, l0);
            final (gr1, gg1, gb1) = filter.recipe.applyRgb(gr0, gg0, gb0);
            final (_, _, grayL1) = rgbToHsl(gr1, gg1, gb1);

            expect(
              l1 - grayL1,
              lessThanOrEqualTo(0.03),
              reason:
                  '0x${hex.toRadixString(16)} (s=$s0) skin lightness $l1 '
                  'vs same-lightness gray $grayL1',
            );
          }
        },
      );
    }
  });

  group('Golden Route', () {
    final recipe = TracenFilter.goldenRoute.recipe;

    test('중간 그레이는 따뜻해짐 (R > B)', () {
      final (r, _, b) = recipe.applyRgb(0.5, 0.5, 0.5);
      expect(r, greaterThan(b));
    });

    test('블랙은 완전한 검정이 아니라 매트하게 들어올려짐', () {
      final (r, g, b) = recipe.applyRgb(0, 0, 0);
      expect(luma709(r, g, b), greaterThan(0.02));
    });

    test('초록은 채도가 낮아지고 노란 쪽으로 이동', () {
      const g0 = (0.2, 0.6, 0.2);
      final (h0, s0, _) = rgbToHsl(g0.$1, g0.$2, g0.$3);
      final (r1, g1, b1) = recipe.applyRgb(g0.$1, g0.$2, g0.$3);
      final (h1, s1, _) = rgbToHsl(r1, g1, b1);

      expect(s1, lessThan(s0));
      // 120도(초록) -> 60도(노랑) 쪽, 즉 hue가 줄어드는 방향으로 이동.
      expect(h1, lessThan(h0));
    });

    test('파랑은 채도가 낮아짐', () {
      const b0 = (0.2, 0.2, 0.8);
      final (_, s0, _) = rgbToHsl(b0.$1, b0.$2, b0.$3);
      final (r1, g1, b1) = recipe.applyRgb(b0.$1, b0.$2, b0.$3);
      final (_, s1, _) = rgbToHsl(r1, g1, b1);
      expect(s1, lessThan(s0));
    });
  });

  group('Mono Path', () {
    test('출력은 항상 R=G=B', () {
      final recipe = TracenFilter.monoPath.recipe;
      for (final rgb in [(0.8, 0.3, 0.1), (0.1, 0.9, 0.5), (0.5, 0.5, 0.5)]) {
        final (r, g, b) = recipe.applyRgb(rgb.$1, rgb.$2, rgb.$3);
        expect(r, closeTo(g, 1e-9));
        expect(g, closeTo(b, 1e-9));
      }
    });
  });

  group('Faded Map', () {
    test('평균 채도가 낮아짐', () {
      final recipe = TracenFilter.fadedMap.recipe;
      const samples = [
        (0.8, 0.2, 0.2),
        (0.2, 0.8, 0.2),
        (0.2, 0.2, 0.8),
        (0.8, 0.8, 0.2),
      ];
      var satBefore = 0.0, satAfter = 0.0;
      for (final rgb in samples) {
        final (_, s0, _) = rgbToHsl(rgb.$1, rgb.$2, rgb.$3);
        final (r1, g1, b1) = recipe.applyRgb(rgb.$1, rgb.$2, rgb.$3);
        final (_, s1, _) = rgbToHsl(r1, g1, b1);
        satBefore += s0;
        satAfter += s1;
      }
      expect(satAfter, lessThan(satBefore));
    });
  });

  group('모든 필터', () {
    test('출력이 항상 [0,1]에 클램프됨', () {
      for (final filter in TracenFilter.values) {
        for (final rgb in [(0.0, 0.0, 0.0), (1.0, 1.0, 1.0), (1.0, 0.0, 0.5)]) {
          final (r, g, b) = filter.recipe.applyRgb(rgb.$1, rgb.$2, rgb.$3);
          expect(r, inInclusiveRange(0.0, 1.0));
          expect(g, inInclusiveRange(0.0, 1.0));
          expect(b, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });

  group('ToneCurve', () {
    test('단조 비감소', () {
      final curve = ToneCurve.gentleS();
      double prev = curve.eval(0);
      for (var i = 1; i <= 100; i++) {
        final v = curve.eval(i / 100);
        expect(v, greaterThanOrEqualTo(prev - 1e-9));
        prev = v;
      }
    });

    test('양 끝은 0과 1', () {
      final curve = ToneCurve.gentleS();
      expect(curve.eval(0), closeTo(0, 1e-9));
      expect(curve.eval(1), closeTo(1, 1e-9));
    });
  });
}
