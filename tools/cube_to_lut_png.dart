/// `.cube` LUT 파일을 TRACEN이 쓰는 512x512(64^3, 8x8 타일) LUT PNG로 변환.
///
/// 실행: `dart run tools/cube_to_lut_png.dart <input.cube> <output.png>`
///
/// 나중에 Lightroom/DaVinci에서 내보낸 `.cube`로 LUT을 교체할 때 사용.
/// 자세한 교체 절차는 `tools/README.md` 참고.
library;

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:tracen/utils/lut_math.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('사용법: dart run tools/cube_to_lut_png.dart <input.cube> <output.png>');
    exit(1);
  }

  final inputFile = File(args[0]);
  if (!inputFile.existsSync()) {
    stderr.writeln('파일을 찾을 수 없음: ${args[0]}');
    exit(1);
  }

  final CubeLut cube;
  try {
    cube = parseCube(inputFile.readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('.cube 파싱 실패: ${e.message}');
    exit(1);
  }

  stdout.writeln('${args[0]} 읽음 (LUT_3D_SIZE=${cube.size})');

  final rgba = cubeToLutRgba(cube);
  final image = img.Image.fromBytes(
    width: kLutPx,
    height: kLutPx,
    bytes: rgba.buffer,
    numChannels: 4,
  );
  File(args[1]).writeAsBytesSync(img.encodePng(image));
  stdout.writeln('${cube.size}^3 -> 64^3로 리샘플해 ${args[1]}에 저장함');
}
