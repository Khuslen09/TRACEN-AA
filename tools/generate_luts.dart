/// TRACEN 필터 4종의 레시피([FilterRecipe])로부터 64^3 LUT PNG를 굽는다.
///
/// 실행: `dart run tools/generate_luts.dart [--out assets/luts]`
///
/// 결과는 `assets/luts/<filter-id>.png` + `assets/luts/identity.png`
/// (셰이더 검증용 — 아무 색도 안 바뀌어야 함).
///
/// 나중에 Lightroom/DaVinci에서 만든 `.cube`로 교체하려면
/// `tools/cube_to_lut_png.dart`와 `tools/README.md`를 참고.
library;

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:tracen/models/camera_filter.dart';
import 'package:tracen/models/filter_recipe.dart';
import 'package:tracen/utils/lut_math.dart';

void main(List<String> args) {
  var outDir = 'assets/luts';
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--out') outDir = args[i + 1];
  }

  Directory(outDir).createSync(recursive: true);

  for (final filter in TracenFilter.values) {
    _writeLut(filter.recipe, '$outDir/${filter.id}.png');
    _reportSkinDeviation(filter);
  }
  _writeLut(FilterRecipe.identity, '$outDir/identity.png');

  stdout.writeln('Done. LUTs written to $outDir/');
}

void _writeLut(FilterRecipe recipe, String path) {
  final rgba = buildLutRgbaFromSampler(recipe.applyRgb);
  final image = img.Image.fromBytes(
    width: kLutPx,
    height: kLutPx,
    bytes: rgba.buffer,
    numChannels: 4,
  );
  File(path).writeAsBytesSync(img.encodePng(image));
  stdout.writeln('  wrote $path (${rgba.length} bytes raw, 512x512 RGBA8)');
}

/// 피부톤 몇 개를 찍어보고 hue가 얼마나 틀어졌는지 콘솔에 요약 — 실제
/// Monk 스케일 전체 검증은 `test/camera_filter/filter_recipe_test.dart`가
/// 하고, 여기서는 LUT을 구울 때마다 빠르게 한 번 더 확인하는 용도.
void _reportSkinDeviation(TracenFilter filter) {
  const sample = (0xa0 / 255, 0x7e / 255, 0x56 / 255); // 중간 톤 피부
  final (r, g, b) = filter.recipe.applyRgb(sample.$1, sample.$2, sample.$3);
  stdout.writeln(
    '  ${filter.id}: 중간 피부톤 샘플 '
    '(${sample.$1.toStringAsFixed(2)},${sample.$2.toStringAsFixed(2)},${sample.$3.toStringAsFixed(2)}) '
    '-> (${r.toStringAsFixed(2)},${g.toStringAsFixed(2)},${b.toStringAsFixed(2)})',
  );
}
