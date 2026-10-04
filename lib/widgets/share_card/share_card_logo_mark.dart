import 'package:flutter/material.dart';

import 'share_card_fonts.dart';

/// 공유 카드 로고 마크 — "TRACEN" 워드마크 텍스트만(아이콘 없음).
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
    final wordmark = Text(
      'TRACEN',
      style: ShareCardFonts.unbounded(size: fontSize, weight: FontWeight.w700, color: color, letterSpacing: fontSize * 0.28),
    );

    if (direction == Axis.vertical) {
      return RotatedBox(quarterTurns: 3, child: wordmark);
    }
    return wordmark;
  }
}
