/// 3D LUT(64^3)을 512x512 PNG(8x8 타일)로 펼치고 되읽는 수학.
///
/// 순수 Dart — `tools/generate_luts.dart`, `tools/cube_to_lut_png.dart`,
/// `test/camera_filter/lut_math_test.dart`, 그리고 `shaders/lut_filter.frag`가
/// 전부 이 레이아웃을 전제로 한다. **이 파일의 레이아웃을 바꾸면 셰이더의
/// LUT 샘플링 코드도 반드시 같이 바꿔야 한다.**
///
/// 레이아웃: 512x512 RGBA8, 64^3 큐브를 8x8 타일(타일당 64x64)로 unwrap.
///   - 타일 인덱스 = blue 레벨 b: tileX = b % 8, tileY = b ~/ 8
///   - 타일 내부: x = red 레벨, y = green 레벨
library;

import 'dart:typed_data';

const kLutSize = 64;
const kLutTiles = 8;
const kLutPx = kLutSize * kLutTiles; // 512

typedef RgbSample = (double, double, double);
typedef RgbSampler = RgbSample Function(double r, double g, double b);

/// (r,g,b) 레벨(0..63) → LUT PNG 안의 픽셀 좌표.
(int px, int py) lutPixelFor(int r, int g, int b) {
  final tileX = b % kLutTiles;
  final tileY = b ~/ kLutTiles;
  return (tileX * kLutSize + r, tileY * kLutSize + g);
}

/// LUT PNG 픽셀 좌표 → (r,g,b) 레벨(0..63). [lutPixelFor]의 역함수.
(int r, int g, int b) lutLevelsAt(int px, int py) {
  final tileX = px ~/ kLutSize;
  final tileY = py ~/ kLutSize;
  final r = px % kLutSize;
  final g = py % kLutSize;
  final b = tileY * kLutTiles + tileX;
  return (r, g, b);
}

RgbSample _lerp3(RgbSample a, RgbSample b, double t) => (
  a.$1 + (b.$1 - a.$1) * t,
  a.$2 + (b.$2 - a.$2) * t,
  a.$3 + (b.$3 - a.$3) * t,
);

/// 임의의 (r,g,b)->(r,g,b) 샘플러로 64^3 LUT PNG(RGBA8, 512x512) 생성.
Uint8List buildLutRgbaFromSampler(RgbSampler sample) {
  final data = Uint8List(kLutPx * kLutPx * 4);
  for (var b = 0; b < kLutSize; b++) {
    for (var g = 0; g < kLutSize; g++) {
      for (var r = 0; r < kLutSize; r++) {
        final (px, py) = lutPixelFor(r, g, b);
        final idx = (py * kLutPx + px) * 4;
        final (or, og, ob) = sample(
          r / (kLutSize - 1),
          g / (kLutSize - 1),
          b / (kLutSize - 1),
        );
        data[idx] = (or * 255).round().clamp(0, 255);
        data[idx + 1] = (og * 255).round().clamp(0, 255);
        data[idx + 2] = (ob * 255).round().clamp(0, 255);
        data[idx + 3] = 255;
      }
    }
  }
  return data;
}

/// LUT PNG의 raw RGBA 바이트에서 트라일리니어 샘플링 — `shaders/lut_filter.frag`
/// 의 샘플링 로직과 반드시 같은 수학을 쓴다(둘 중 하나를 고치면 반대쪽도).
/// red/green은 같은 blue 타일 안에서 bilinear, blue는 두 타일 사이를 lerp.
RgbSample sampleLutTrilinear(Uint8List rgba, double r, double g, double b) {
  const n = kLutSize;
  final rf = r.clamp(0.0, 1.0) * (n - 1);
  final gf = g.clamp(0.0, 1.0) * (n - 1);
  final bf = b.clamp(0.0, 1.0) * (n - 1);

  final r0 = rf.floor().clamp(0, n - 1);
  final r1 = (r0 + 1).clamp(0, n - 1);
  final rt = rf - r0;
  final g0 = gf.floor().clamp(0, n - 1);
  final g1 = (g0 + 1).clamp(0, n - 1);
  final gt = gf - g0;
  final b0 = bf.floor().clamp(0, n - 1);
  final b1 = (b0 + 1).clamp(0, n - 1);
  final bt = bf - b0;

  RgbSample texelAt(int ri, int gi, int bi) {
    final (px, py) = lutPixelFor(ri, gi, bi);
    final idx = (py * kLutPx + px) * 4;
    return (rgba[idx] / 255.0, rgba[idx + 1] / 255.0, rgba[idx + 2] / 255.0);
  }

  RgbSample bilinearAt(int bi) {
    final c00 = texelAt(r0, g0, bi);
    final c10 = texelAt(r1, g0, bi);
    final c01 = texelAt(r0, g1, bi);
    final c11 = texelAt(r1, g1, bi);
    return _lerp3(_lerp3(c00, c10, rt), _lerp3(c01, c11, rt), gt);
  }

  return _lerp3(bilinearAt(b0), bilinearAt(b1), bt);
}

/// 파싱된 `.cube` 파일 — red가 가장 빨리 바뀌는(row-major, b가 가장 바깥
/// 루프) 표준 순서로 데이터를 가진다: `data[b*size*size + g*size + r]`.
class CubeLut {
  final int size;
  final List<RgbSample> data;
  const CubeLut(this.size, this.data);
}

/// `.cube` 텍스트를 파싱. TITLE/주석/DOMAIN_MIN/MAX 라인은 무시(0..1 도메인
/// 가정 — 다른 도메인은 지원하지 않고 에러).
CubeLut parseCube(String text) {
  int? size;
  final data = <RgbSample>[];

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith('TITLE')) {
      continue;
    }
    if (line.startsWith('DOMAIN_MIN') || line.startsWith('DOMAIN_MAX')) {
      final parts = line.split(RegExp(r'\s+'));
      final values = parts.skip(1).map(double.parse);
      if (values.any((v) => v != 0 && v != 1)) {
        throw FormatException('DOMAIN이 0..1이 아닌 .cube는 지원하지 않음: $line');
      }
      continue;
    }
    if (line.startsWith('LUT_1D_SIZE')) {
      throw const FormatException('1D LUT(.cube)은 지원하지 않음');
    }
    if (line.startsWith('LUT_3D_SIZE')) {
      size = int.parse(line.split(RegExp(r'\s+'))[1]);
      continue;
    }

    final parts = line.split(RegExp(r'\s+'));
    if (parts.length != 3) continue; // 그 외 알려지지 않은 메타데이터 라인
    data.add((double.parse(parts[0]), double.parse(parts[1]), double.parse(parts[2])));
  }

  if (size == null) {
    throw const FormatException('.cube에 LUT_3D_SIZE가 없음');
  }
  final expected = size * size * size;
  if (data.length != expected) {
    throw FormatException(
      '.cube 데이터 라인 수(${data.length})가 LUT_3D_SIZE^3($expected)과 안 맞음',
    );
  }
  return CubeLut(size, data);
}

/// 임의 크기(.cube 보통 17/33/65)의 [CubeLut]을 64^3 LUT PNG RGBA 바이트로
/// 트라일리니어 리샘플.
Uint8List cubeToLutRgba(CubeLut cube) {
  final n = cube.size;

  RgbSample at(int r, int g, int b) => cube.data[b * n * n + g * n + r];

  RgbSample sample(double r, double g, double b) {
    if (n == 1) return at(0, 0, 0);
    final rf = r.clamp(0.0, 1.0) * (n - 1);
    final gf = g.clamp(0.0, 1.0) * (n - 1);
    final bf = b.clamp(0.0, 1.0) * (n - 1);

    final r0 = rf.floor().clamp(0, n - 1);
    final r1 = (r0 + 1).clamp(0, n - 1);
    final rt = rf - r0;
    final g0 = gf.floor().clamp(0, n - 1);
    final g1 = (g0 + 1).clamp(0, n - 1);
    final gt = gf - g0;
    final b0 = bf.floor().clamp(0, n - 1);
    final b1 = (b0 + 1).clamp(0, n - 1);
    final bt = bf - b0;

    RgbSample bilinearAt(int bi) {
      final c00 = at(r0, g0, bi);
      final c10 = at(r1, g0, bi);
      final c01 = at(r0, g1, bi);
      final c11 = at(r1, g1, bi);
      return _lerp3(_lerp3(c00, c10, rt), _lerp3(c01, c11, rt), gt);
    }

    return _lerp3(bilinearAt(b0), bilinearAt(b1), bt);
  }

  return buildLutRgbaFromSampler(sample);
}
