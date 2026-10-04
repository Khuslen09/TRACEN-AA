import 'package:flutter_test/flutter_test.dart';
import 'package:tracen/utils/lut_math.dart';

const _identity2Cube = '''
TITLE "identity 2x2x2"
# 주석 라인
LUT_3D_SIZE 2
DOMAIN_MIN 0.0 0.0 0.0
DOMAIN_MAX 1.0 1.0 1.0
0.0 0.0 0.0
1.0 0.0 0.0
0.0 1.0 0.0
1.0 1.0 0.0
0.0 0.0 1.0
1.0 0.0 1.0
0.0 1.0 1.0
1.0 1.0 1.0
''';

void main() {
  test('2^3 identity .cube 파싱', () {
    final cube = parseCube(_identity2Cube);
    expect(cube.size, 2);
    expect(cube.data.length, 8);
    // red-fastest 순서: 첫 데이터 라인은 (r=0,g=0,b=0), 둘째는 (r=1,g=0,b=0).
    expect(cube.data[0], (0.0, 0.0, 0.0));
    expect(cube.data[1], (1.0, 0.0, 0.0));
    expect(cube.data[7], (1.0, 1.0, 1.0));
  });

  test('identity .cube를 64^3로 리샘플해도 identity 보존', () {
    final cube = parseCube(_identity2Cube);
    final rgba = cubeToLutRgba(cube);
    for (final v in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final (r, g, b) = sampleLutTrilinear(rgba, v, v, v);
      expect(r, closeTo(v, 1 / 255));
      expect(g, closeTo(v, 1 / 255));
      expect(b, closeTo(v, 1 / 255));
    }
  });

  test('데이터 라인 수가 안 맞으면 FormatException', () {
    const bad = '''
LUT_3D_SIZE 2
0.0 0.0 0.0
1.0 0.0 0.0
''';
    expect(() => parseCube(bad), throwsFormatException);
  });

  test('LUT_3D_SIZE가 없으면 FormatException', () {
    const bad = '''
0.0 0.0 0.0
1.0 0.0 0.0
''';
    expect(() => parseCube(bad), throwsFormatException);
  });

  test('0..1이 아닌 DOMAIN은 지원하지 않음', () {
    const bad = '''
LUT_3D_SIZE 2
DOMAIN_MIN 0.0 0.0 0.0
DOMAIN_MAX 2.0 2.0 2.0
0.0 0.0 0.0
1.0 0.0 0.0
0.0 1.0 0.0
1.0 1.0 0.0
0.0 0.0 1.0
1.0 0.0 1.0
0.0 1.0 1.0
1.0 1.0 1.0
''';
    expect(() => parseCube(bad), throwsFormatException);
  });
}
