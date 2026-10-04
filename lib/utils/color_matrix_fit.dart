/// [FilterRecipe]를 실시간 미리보기용 4x5 ColorMatrix로 근사 피팅.
///
/// `ColorFiltered(colorFilter: ColorFilter.matrix(...))`로 CameraPreview를
/// 감싸는 가벼운 미리보기용 — LUT 셰이더만큼 정확하진 않지만, 매 프레임
/// 돌려도 가벼워야 하는 실시간 경로라 선형 근사로 충분하다. 그레인/비네트/
/// 디노이즈 같은 공간 효과는 여기 포함 안 됨(저장 화면에서 실제 셰이더로
/// 정확히 보여줌).
library;

import '../models/filter_recipe.dart';
import 'skin_tone_samples.dart';

/// Flutter `ColorFilter.matrix`가 받는 형식 — row-major 4x5, 오프셋
/// (각 행의 5번째 값)은 0..255 스케일.
const List<double> kIdentityMatrix = [
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

/// identity와 [t]만큼 보간 — t=0이면 무필터, t=1이면 [m] 그대로.
List<double> lerpWithIdentity(List<double> m, double t) {
  final out = List<double>.filled(20, 0);
  for (var i = 0; i < 20; i++) {
    out[i] = kIdentityMatrix[i] + (m[i] - kIdentityMatrix[i]) * t;
  }
  return out;
}

class _Sample {
  final double r, g, b, weight, outR, outG, outB;
  _Sample(this.r, this.g, this.b, this.weight, this.outR, this.outG, this.outB);
}

List<_Sample> _buildSamples(FilterRecipe recipe) {
  final samples = <_Sample>[];

  void add(double r, double g, double b, double weight) {
    final (or, og, ob) = recipe.applyRgb(r, g, b);
    samples.add(_Sample(r, g, b, weight, or, og, ob));
  }

  // 9^3 그리드 — 색 공간 전체를 고르게.
  for (var ri = 0; ri < 9; ri++) {
    for (var gi = 0; gi < 9; gi++) {
      for (var bi = 0; bi < 9; bi++) {
        add(ri / 8, gi / 8, bi / 8, 1.0);
      }
    }
  }

  // 33 그레이 램프 — 중립색 정확도.
  for (var i = 0; i < 33; i++) {
    final v = i / 32;
    add(v, v, v, 5.0);
  }

  // Monk 피부톤 10종(±5% 밝기 지터) — 가장 중요한 영역이라 가중치를 높임.
  for (final hex in monkSkinToneHex) {
    final (r0, g0, b0) = rgbFromHex(hex);
    for (final jitter in [-0.05, 0.0, 0.05]) {
      final r = (r0 * (1 + jitter)).clamp(0.0, 1.0);
      final g = (g0 * (1 + jitter)).clamp(0.0, 1.0);
      final b = (b0 * (1 + jitter)).clamp(0.0, 1.0);
      add(r, g, b, 20.0);
    }
  }

  return samples;
}

/// 4x4 연립방정식 Ax=y를 가우스 소거법으로 풀어 x(길이4) 반환.
/// [a]는 4개 행(각 길이5: [계수4, 상수항]).
List<double> _solve4x4(List<List<double>> a) {
  final n = 4;
  for (var col = 0; col < n; col++) {
    var pivot = col;
    for (var r = col + 1; r < n; r++) {
      if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
    }
    final tmp = a[col];
    a[col] = a[pivot];
    a[pivot] = tmp;

    final pivotVal = a[col][col];
    if (pivotVal.abs() < 1e-12) continue; // 특이행렬 방지 — 해당 열은 0으로 둠
    for (var r = 0; r < n; r++) {
      if (r == col) continue;
      final factor = a[r][col] / pivotVal;
      for (var c = col; c <= n; c++) {
        a[r][c] -= factor * a[col][c];
      }
    }
  }
  return [
    for (var r = 0; r < n; r++) a[r][r].abs() < 1e-12 ? 0 : a[r][n] / a[r][r],
  ];
}

/// 한 출력 채널(r/g/b 중 하나)에 대해 가중 최소제곱으로 `[a,b,c,d]`를 찾음
/// (예측값 = a*r + b*g + c*b + d).
List<double> _fitChannel(
  List<_Sample> samples,
  double Function(_Sample) target,
) {
  // 정규방정식 A^T W A x = A^T W y, 4x4.
  final ata = List.generate(4, (_) => List.filled(5, 0.0));
  for (final s in samples) {
    final row = [s.r, s.g, s.b, 1.0];
    final y = target(s);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        ata[i][j] += s.weight * row[i] * row[j];
      }
      ata[i][4] += s.weight * row[i] * y;
    }
  }
  return _solve4x4(ata);
}

final Map<FilterRecipe, List<double>> _cache = {};

/// [recipe]를 4x5 ColorMatrix로 피팅(메모이즈).
List<double> fitColorMatrix(FilterRecipe recipe) {
  final cached = _cache[recipe];
  if (cached != null) return cached;

  final samples = _buildSamples(recipe);
  final rRow = _fitChannel(samples, (s) => s.outR);
  final gRow = _fitChannel(samples, (s) => s.outG);
  final bRow = _fitChannel(samples, (s) => s.outB);

  // row-major 4x5 — 각 행은 [r계수, g계수, b계수, a계수, 오프셋].
  // 오프셋은 ColorFilter.matrix 규약상 0..255 스케일이라 ×255.
  final matrix = <double>[
    rRow[0], rRow[1], rRow[2], 0, rRow[3] * 255,
    gRow[0], gRow[1], gRow[2], 0, gRow[3] * 255,
    bRow[0], bRow[1], bRow[2], 0, bRow[3] * 255,
    0, 0, 0, 1, 0,
  ];
  _cache[recipe] = matrix;
  return matrix;
}

/// 테스트/디버깅용 — 캐시 비우기.
void clearColorMatrixCache() => _cache.clear();
