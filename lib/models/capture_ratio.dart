/// 촬영 비율 — 전부 세로(portrait) 기준, [aspect]는 가로/세로.
enum CaptureRatio {
  r4x5(4 / 5),
  r1x1(1.0),
  r9x16(9 / 16);

  final double aspect;
  const CaptureRatio(this.aspect);
}
