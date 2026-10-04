import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// 공유 카드 텍스트/선 색상(잉크) 프리셋 4종.
enum ShareInkColor {
  white(Color(0xFFFFFFFF)),
  black(Color(0xFF111111)),
  sunset(Color(0xFFFFB27A)),
  mint(Color(0xFF9FE3D0));

  final Color color;

  const ShareInkColor(this.color);

  String get label => switch (this) {
    ShareInkColor.white => Strings.current.shareInkWhite,
    ShareInkColor.black => Strings.current.shareInkBlack,
    ShareInkColor.sunset => Strings.current.shareInkSunset,
    ShareInkColor.mint => Strings.current.shareInkMint,
  };
}
