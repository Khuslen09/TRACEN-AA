import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// 지도 위 보라 톤 오버레이 + 발자취 경로 마스킹.
///
/// **목표**: "내가 간 길은 보라 막이 벗겨져서 원래 지도가 보이는" 스크래치 카드 효과.
///
/// **구현 방식**:
///   1. 화면 전체에 반투명 보라 사각형
///   2. 발자취 경로(픽셀 좌표)를 Path로 만들어 두꺼운 stroke
///   3. `BlendMode.dstOut` 으로 보라 막에서 그 stroke 모양 잘라냄
///   4. 결과: 발자취 부분만 투명 → 원래 지도가 비침
///
/// **한계** (솔직히):
///   - 지도 줌/팬 시 부모가 다시 픽셀 좌표 계산해서 [trackScreenPoints] 갱신해야 함
///   - 빠른 줌 중에는 0.1초 정도 발자취가 어긋날 수 있음
///   - 점이 많으면 (1000+) 성능 저하
///
/// **사용 방법** (부모 위젯):
///   1. GoogleMap의 onCameraMove에서 모든 발자취 LatLng를 screen coordinate로 변환
///   2. 변환된 [List<Offset>] 묶음을 [trackScreenPoints]로 전달
///   3. CustomPaint가 위 위에 떠서 마스킹 그림
class ScratchOverlayPainter extends CustomPainter {
  /// 발자취 경로들. 각 경로는 픽셀 좌표 점들의 리스트.
  /// 여러 경로 가능 (러닝 1, 러닝 2, day_track 1, day_track 2 등).
  final List<List<Offset>> trackScreenPoints;

  /// 보라 막 두께 = 발자취 stroke 두께 (벗겨낼 너비).
  /// 너무 가늘면 발자취 안 보이고, 너무 두꺼우면 보라 막 거의 다 벗겨짐.
  final double strokeWidth;

  /// 보라 오버레이 알파 (0.0~1.0). 18% 정도가 지도 가독성 OK.
  final double overlayAlpha;

  ScratchOverlayPainter({
    required this.trackScreenPoints,
    this.strokeWidth = 30,
    this.overlayAlpha = 0.18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 레이어 시작 — 이 안의 그리기는 BlendMode가 서로에게 영향을 줌
    canvas.saveLayer(rect, Paint());

    // 1. 보라 막 (전체 화면 채움)
    canvas.drawRect(
      rect,
      Paint()..color = AppColors.primary.withValues(alpha: overlayAlpha),
    );

    // 2. 발자취 경로들을 두꺼운 stroke로 그리되, BlendMode.dstOut으로
    //    보라 막에서 그 모양만 잘라냄 (구멍 뚫기)
    final scratchPaint = Paint()
      ..color = Colors
          .black // dstOut 모드에선 색은 무관, alpha만 사용
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.dstOut;

    for (final points in trackScreenPoints) {
      if (points.length < 2) continue;

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, scratchPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ScratchOverlayPainter old) {
    return old.trackScreenPoints != trackScreenPoints ||
        old.strokeWidth != strokeWidth ||
        old.overlayAlpha != overlayAlpha;
  }
}

/// CustomPaint를 감싸 IgnorePointer + 풀스크린 처리.
/// 부모는 Stack의 자식으로 이 위젯을 GoogleMap 위에 올리기만 하면 됨.
class ScratchOverlay extends StatelessWidget {
  final List<List<Offset>> trackScreenPoints;
  final double strokeWidth;
  final double overlayAlpha;

  const ScratchOverlay({
    super.key,
    required this.trackScreenPoints,
    this.strokeWidth = 30,
    this.overlayAlpha = 0.18,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: ScratchOverlayPainter(
            trackScreenPoints: trackScreenPoints,
            strokeWidth: strokeWidth,
            overlayAlpha: overlayAlpha,
          ),
        ),
      ),
    );
  }
}
