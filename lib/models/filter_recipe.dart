/// 필터 레시피 — 색상 보정의 유일한 소스.
///
/// 순수 Dart (flutter/dart:ui 의존 없음) — `tools/generate_luts.dart`가
/// 그대로 import해서 LUT를 굽고, `lib/utils/color_matrix_fit.dart`가 실시간
/// 미리보기용 4x5 행렬을 이 로직에서 피팅한다. 두 렌더링 경로가 각자 손으로
/// 튜닝한 별도 구현이 되어 서로 어긋나지 않게, 실제 색상 변환은 오직 이
/// 파일의 [FilterRecipe.applyRgb]에만 있다.
library;

import 'dart:math' as math;

import '../utils/color_math.dart';

/// 하나의 HSL 보정 구간(Lightroom 스타일 8밴드 중 하나).
enum HslBand {
  red(0),
  orange(30),
  yellow(60),
  green(120),
  aqua(180),
  blue(240),
  purple(270),
  magenta(300);

  final double centerHueDeg;
  const HslBand(this.centerHueDeg);
}

/// 한 HSL 밴드에 대한 보정값. hueShiftDeg는 그 밴드 중심에서 최대로 적용되는
/// 색조 이동(도), satDelta/lumDelta는 채도/밝기에 더해지는 값(둘 다 -1..1
/// 범위에서 쓰되, 보통 ±0.3 이내로 충분).
class HslBandAdjust {
  final double hueShiftDeg;
  final double satDelta;
  final double lumDelta;

  const HslBandAdjust({
    this.hueShiftDeg = 0,
    this.satDelta = 0,
    this.lumDelta = 0,
  });
}

/// 0..1 구간의 단조 증가 톤 커브. 점들은 x 기준 오름차순, 양 끝은 보통
/// (0,0)/(1,1) 근처(블랙리프트/화이트드롭은 [FilterRecipe]에서 별도 적용).
class ToneCurve {
  final List<(double x, double y)> points;
  late final List<double> _xs;
  late final List<double> _ys;
  late final List<double> _tangents;

  ToneCurve(this.points) {
    assert(points.length >= 2, 'ToneCurve는 최소 2개 점이 필요');
    _xs = points.map((p) => p.$1).toList();
    _ys = points.map((p) => p.$2).toList();
    for (var i = 1; i < _xs.length; i++) {
      assert(_xs[i] > _xs[i - 1], 'ToneCurve 점은 x 기준 엄격히 증가해야 함');
    }
    _tangents = monotoneCubicTangents(_xs, _ys);
  }

  double eval(double v) {
    final x = clamp01(v);
    if (x <= _xs.first) return _ys.first;
    if (x >= _xs.last) return _ys.last;

    var i = 0;
    while (i < _xs.length - 2 && x > _xs[i + 1]) {
      i++;
    }
    final x0 = _xs[i], x1 = _xs[i + 1];
    final h = x1 - x0;
    final t = (x - x0) / h;
    return evalMonotoneHermite(_ys[i], _ys[i + 1], _tangents[i], _tangents[i + 1], h, t);
  }

  /// 완만한 기본 S커브 — 그림자 살짝 내리고 하이라이트 살짝 올림.
  static ToneCurve gentleS({double shadowY = 0.22, double highlightY = 0.78}) =>
      ToneCurve([(0, 0), (0.25, shadowY), (0.75, highlightY), (1, 1)]);

  static final identity = ToneCurve([(0, 0), (1, 1)]);
}

/// 하나의 TRACEN 필터 레시피. 모든 필드는 불변.
class FilterRecipe {
  final double temperatureShiftK; // +가 더 따뜻함
  final double tint; // -1..1, +가 마젠타 쪽
  final ToneCurve curve;
  final double blackLift; // 0..1, 블랙 포인트를 올려 매트하게
  final double whiteDrop; // 0..1, 화이트 포인트를 내려 바랜 느낌
  final Map<HslBand, HslBandAdjust> hsl;
  final double globalSaturation; // -1..1
  final double vibrance; // -1..1, 이미 채도 높은 색은 덜 건드림
  final double splitHighlightHueDeg;
  final double splitHighlightSat; // 0..1
  final double splitShadowHueDeg;
  final double splitShadowSat; // 0..1
  final double splitBalance; // -1..1, 하이라이트/섀도 경계 이동
  final bool monochrome;
  final (double r, double g, double b) monoMix;
  final double skinProtect; // 0..1, 피부색 hue를 원본에 가깝게 복원하는 강도

  // 공간적 효과 — LUT(픽셀당 매핑)로는 표현 못 함. 셰이더 uniform으로 전달.
  final double grain; // 0..1
  final double vignette; // 0..1
  final double shadowDenoise; // 0..1, 그림자 영역 크로마 노이즈 억제

  const FilterRecipe({
    this.temperatureShiftK = 0,
    this.tint = 0,
    required this.curve,
    this.blackLift = 0,
    this.whiteDrop = 0,
    this.hsl = const {},
    this.globalSaturation = 0,
    this.vibrance = 0,
    this.splitHighlightHueDeg = 45,
    this.splitHighlightSat = 0,
    this.splitShadowHueDeg = 210,
    this.splitShadowSat = 0,
    this.splitBalance = 0,
    this.monochrome = false,
    this.monoMix = (0.2126, 0.7152, 0.0722),
    this.skinProtect = 0,
    this.grain = 0,
    this.vignette = 0,
    this.shadowDenoise = 0,
  });

  static final identity = FilterRecipe(curve: ToneCurve.identity);

  /// 입력 sRGB(0..1) → 출력 sRGB(0..1). 아래 순서를 반드시 지켜야 함(이
  /// 순서 자체가 레시피의 의미를 정의함):
  ///   1) 화이트밸런스 게인  2) 톤커브 → 블랙리프트/화이트드롭
  ///   3) HSL 밴드 보정      4) 전역 채도 + vibrance
  ///   5) 스플릿톤           6) 모노크롬
  ///   8) 클램프
  ///
  /// **피부 보호(7)는 끝에 패치하는 방식이 아니다.** 입력 픽셀이 피부일
  /// 가중치(`keep`의 반대)를 맨 앞에서 한 번만 계산해 3~5단계의 hue 영향
  /// 보정값(HSL 밴드/전역 채도/vibrance/스플릿톤 양)에 전부 `keep`을 곱해
  /// 둔다. 끝에서 hue만 되돌리는 방식은, 전역 채도가 강해서 채도가 0 근처로
  /// 깎인 뒤 스플릿톤이 아주 작은 양만 더해도 결과 hue가 스플릿톤 쪽으로
  /// 전부 끌려가 버리는(거의 무채색에는 약간의 색조만 더해도 hue가 그
  /// 색조로 결정됨) 문제가 있었음 — 처음부터 그 보정들 자체를 줄이는 쪽이
  /// 안전하다.
  (double, double, double) applyRgb(double r0, double g0, double b0) {
    final (hue0, sat0, lum0) = rgbToHsl(r0, g0, b0);
    final skinWeight = skinProtect <= 0 || monochrome
        ? 0.0
        : (_skinWeight(hue0, sat0, lum0) * skinProtect).clamp(0.0, 1.0);
    final keep = 1 - skinWeight;

    // 1) 화이트밸런스 — 피부는 게인을 1.0 쪽으로 blend(완전히 끄진 않음,
    // "약간 차가운/따뜻한 톤" 자체는 피부에도 살짝 남아야 필터 느낌이 있음.
    // 다만 세게 들어가면 hue가 돌아가므로 keep 비율만큼만 적용).
    final (rGain0, gGain0, bGain0) = kelvinToRgbGain(temperatureShiftK, tint);
    final rGain = 1 + (rGain0 - 1) * keep;
    final gGain = 1 + (gGain0 - 1) * keep;
    final bGain = 1 + (bGain0 - 1) * keep;
    var r = clamp01(r0 * rGain);
    var g = clamp01(g0 * gGain);
    var b = clamp01(b0 * bGain);

    // 2) 톤커브 + 블랙리프트/화이트드롭
    r = curve.eval(r);
    g = curve.eval(g);
    b = curve.eval(b);
    final liftScale = 1 - blackLift - whiteDrop;
    r = blackLift + r * liftScale;
    g = blackLift + g * liftScale;
    b = blackLift + b * liftScale;

    // 3) HSL 밴드 보정
    var (h, s, l) = rgbToHsl(r, g, b);
    if (hsl.isNotEmpty && keep > 0) {
      double hueShift = 0, satDelta = 0, lumDelta = 0;
      for (final entry in hsl.entries) {
        final dist = hueDistanceDeg(h, entry.key.centerHueDeg);
        if (dist >= 45) continue;
        final weight = _cosFalloff(dist) * keep;
        hueShift += weight * entry.value.hueShiftDeg;
        satDelta += weight * entry.value.satDelta;
        lumDelta += weight * entry.value.lumDelta;
      }
      h = (h + hueShift) % 360;
      if (h < 0) h += 360;
      s = clamp01(s + satDelta);
      l = clamp01(l + lumDelta);
    }

    // 4) 전역 채도 + vibrance(이미 채도 높은 픽셀은 덜 영향)
    s = clamp01(s + globalSaturation * keep);
    s = clamp01(s + vibrance * (1 - s) * keep);
    (r, g, b) = hslToRgb(h, s, l);

    // 5) 스플릿톤 — 루미넌스는 유지하고 크로마만 하이라이트/섀도 쪽으로 이동
    final luma = luma709(r, g, b);
    if ((splitHighlightSat > 0 || splitShadowSat > 0) && keep > 0) {
      final mid = 0.5 + splitBalance * 0.3;
      final hlAmt =
          smoothstep(mid, mid + 0.35, luma) * splitHighlightSat * keep;
      final shAmt =
          (1 - smoothstep(mid - 0.35, mid, luma)) * splitShadowSat * keep;
      if (hlAmt > 0) {
        final (tr, tg, tb) = hslToRgb(splitHighlightHueDeg, 0.6, l);
        r = r + (tr - r) * hlAmt;
        g = g + (tg - g) * hlAmt;
        b = b + (tb - b) * hlAmt;
      }
      if (shAmt > 0) {
        final (tr, tg, tb) = hslToRgb(splitShadowHueDeg, 0.6, l);
        r = r + (tr - r) * shAmt;
        g = g + (tg - g) * shAmt;
        b = b + (tb - b) * shAmt;
      }
    }

    // 6) 모노크롬
    if (monochrome) {
      final (mr, mg, mb) = monoMix;
      final gray = r * mr + g * mg + b * mb;
      r = gray;
      g = gray;
      b = gray;
    }

    // 8) 클램프
    return (clamp01(r), clamp01(g), clamp01(b));
  }

  /// 중심에서 1, ±45도에서 0으로 떨어지는 코사인 falloff.
  static double _cosFalloff(double distDeg) {
    if (distDeg >= 45) return 0;
    return math.cos(distDeg / 45 * (math.pi / 2));
  }

  /// 피부색(hue가 주황 쪽)에 가까울수록 1에 가까운 가중치. 입력 픽셀 기준으로
  /// 계산해야 필터가 색을 바꾸기 전 "원래 피부였는지"를 판단할 수 있음.
  /// 채도/루마 창은 Monk Skin Tone 10단계 전체(아주 어두운 톤 포함)를
  /// weight≈1로 덮도록 넓게 잡음 — hue 가우시안이 실질적인 판별 기준.
  static double _skinWeight(double hue, double sat, double luma) {
    final hueW = gaussian(hueDistanceDeg(hue, 28), 16);
    final satW = trapezoidWindow(0.04, 0.08, 0.75, 0.85, sat);
    final lumaW = trapezoidWindow(0.05, 0.10, 0.97, 0.99, luma);
    return hueW * satW * lumaW;
  }
}
