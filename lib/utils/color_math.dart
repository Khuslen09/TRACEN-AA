/// 색상 계산 순수 함수 모음 — Flutter/dart:ui에 의존하지 않음.
///
/// FilterRecipe와 `tools/generate_luts.dart`가 공유하는 기반 수학.
library;

import 'dart:math' as math;

/// RGB(0..1) → HSL. h는 [0,360), s/l은 [0,1].
(double h, double s, double l) rgbToHsl(double r, double g, double b) {
  final maxV = math.max(r, math.max(g, b));
  final minV = math.min(r, math.min(g, b));
  final l = (maxV + minV) / 2;
  if (maxV == minV) return (0, 0, l);

  final d = maxV - minV;
  final s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);

  double h;
  if (maxV == r) {
    h = (g - b) / d;
    if (h < 0) h += 6;
  } else if (maxV == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  h *= 60;
  return (h, s, l);
}

/// HSL → RGB(0..1).
(double r, double g, double b) hslToRgb(double h, double s, double l) {
  if (s <= 0) return (l, l, l);

  final c = (1 - (2 * l - 1).abs()) * s;
  final hp = (h % 360) / 60;
  final x = c * (1 - (hp % 2 - 1).abs());
  double r1 = 0, g1 = 0, b1 = 0;
  if (hp < 1) {
    r1 = c;
    g1 = x;
  } else if (hp < 2) {
    r1 = x;
    g1 = c;
  } else if (hp < 3) {
    g1 = c;
    b1 = x;
  } else if (hp < 4) {
    g1 = x;
    b1 = c;
  } else if (hp < 5) {
    r1 = x;
    b1 = c;
  } else {
    r1 = c;
    b1 = x;
  }
  final m = l - c / 2;
  return (r1 + m, g1 + m, b1 + m);
}

/// Rec.709 luma (0..1).
double luma709(double r, double g, double b) =>
    0.2126 * r + 0.7152 * g + 0.0722 * b;

/// 두 색상(도) 사이의 최단 원형 거리, [0,180].
double hueDistanceDeg(double a, double b) {
  var d = (a - b).abs() % 360;
  if (d > 180) d = 360 - d;
  return d;
}

/// 0..1 범위로 부드럽게 보간하는 표준 smoothstep.
double smoothstep(double edge0, double edge1, double x) {
  if (edge0 == edge1) return x < edge0 ? 0 : 1;
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// [lo1,hi1] 에서는 1, [lo0,lo1)/( hi1,hi0] 에서는 완만히 0으로, 그 밖은 0인
/// 사다리꼴 창 함수 — 피부 보호의 채도/루마 윈도우에 사용.
double trapezoidWindow(double lo0, double lo1, double hi1, double hi0, double x) {
  if (x <= lo0 || x >= hi0) return 0;
  if (x < lo1) return smoothstep(lo0, lo1, x);
  if (x > hi1) return 1 - smoothstep(hi1, hi0, x);
  return 1;
}

/// 중심 0, 표준편차 [sigmaDeg]인 가우시안 — 피부 보호의 hue 윈도우에 사용.
double gaussian(double distance, double sigmaDeg) {
  final z = distance / sigmaDeg;
  return math.exp(-0.5 * z * z);
}

/// 색온도 변화(+K가 더 따뜻함)와 tint(+가 마젠타 쪽)를 R/G/B 게인으로 근사.
///
/// 실제 Planckian locus 계산이 아니라, 사진 편집 도구의 "온도/색조" 슬라이더를
/// 모사하는 단순 선형 근사 — 이 필터들은 과학적 화이트밸런스가 아니라 스타일화된
/// 톤이 목적이라 충분함.
(double rGain, double gGain, double bGain) kelvinToRgbGain(
  double shiftK,
  double tint,
) {
  const perKelvin = 0.00009; // 250K → ±0.0225
  final warm = shiftK * perKelvin;
  final rGain = 1.0 + warm - tint * 0.05;
  final gGain = 1.0 + tint * 0.08;
  final bGain = 1.0 - warm - tint * 0.05;
  return (rGain, gGain, bGain);
}

/// Fritsch–Carlson 단조 큐빅 에르미트 보간의 탄젠트 계산.
/// [xs]는 엄격히 증가해야 함. 결과는 각 점에서의 탄젠트(기울기) 목록.
List<double> monotoneCubicTangents(List<double> xs, List<double> ys) {
  final n = xs.length;
  assert(n >= 2 && xs.length == ys.length);

  final d = List<double>.filled(n - 1, 0);
  for (var i = 0; i < n - 1; i++) {
    d[i] = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]);
  }

  final m = List<double>.filled(n, 0);
  m[0] = d[0];
  m[n - 1] = d[n - 2];
  for (var i = 1; i < n - 1; i++) {
    m[i] = (d[i - 1] + d[i]) / 2;
  }

  for (var i = 0; i < n - 1; i++) {
    if (d[i] == 0) {
      m[i] = 0;
      m[i + 1] = 0;
      continue;
    }
    final a = m[i] / d[i];
    final b = m[i + 1] / d[i];
    final s = a * a + b * b;
    if (s > 9) {
      final tau = 3 / math.sqrt(s);
      m[i] = tau * a * d[i];
      m[i + 1] = tau * b * d[i];
    }
  }
  return m;
}

/// 주어진 세그먼트에서 단조 큐빅 에르미트 값 평가 (0<=t<=1).
double evalMonotoneHermite(
  double y0,
  double y1,
  double m0,
  double m1,
  double h,
  double t,
) {
  final t2 = t * t;
  final t3 = t2 * t;
  final h00 = 2 * t3 - 3 * t2 + 1;
  final h10 = t3 - 2 * t2 + t;
  final h01 = -2 * t3 + 3 * t2;
  final h11 = t3 - t2;
  return h00 * y0 + h10 * (m0 * h) + h01 * y1 + h11 * (m1 * h);
}

double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
