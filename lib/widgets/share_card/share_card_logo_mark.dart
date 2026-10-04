import 'package:flutter/material.dart';

import 'share_card_fonts.dart';

/// 공유 카드 로고 마크 — 작은 손그림 경로 아이콘(꺾은선 + 끝점) + "TRACEN"
/// 워드마크. 기존 `assets/icon/tracen_logo.svg`(지도 화면 워터마크용)와는
/// 별개 — 이쪽은 카드 전용의 더 미니멀한 마크.
class ShareCardLogoMark extends StatelessWidget {
  final Color color;
  final double iconSize;
  final double fontSize;
  final Axis direction;

  const ShareCardLogoMark({
    super.key,
    required this.color,
    this.iconSize = 14,
    this.fontSize = 10,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size.square(iconSize),
      painter: _RouteMarkPainter(color: color),
    );
    final wordmark = Text(
      'TRACEN',
      style: ShareCardFonts.unbounded(size: fontSize, weight: FontWeight.w700, color: color, letterSpacing: fontSize * 0.28),
    );

    if (direction == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 6),
          RotatedBox(quarterTurns: 3, child: wordmark),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [icon, const SizedBox(width: 6), wordmark],
    );
  }
}

class _RouteMarkPainter extends CustomPainter {
  final Color color;
  const _RouteMarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.85)
      ..lineTo(size.width * 0.45, size.height * 0.35)
      ..lineTo(size.width * 0.65, size.height * 0.6)
      ..lineTo(size.width * 0.92, size.height * 0.15);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.15),
      size.shortestSide * 0.1,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteMarkPainter oldDelegate) => oldDelegate.color != color;
}
