import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_colors.dart';

/// 공유 카드 텍스트/선 색상(잉크) 프리셋 3종.
enum ShareInkColor {
  white(Color(0xFFFFFFFF)),
  black(Color(0xFF111111)),
  purple(AppColors.primary);

  final Color color;

  const ShareInkColor(this.color);

  String get label => switch (this) {
    ShareInkColor.white => Strings.current.shareInkWhite,
    ShareInkColor.black => Strings.current.shareInkBlack,
    ShareInkColor.purple => Strings.current.shareInkPurple,
  };
}
