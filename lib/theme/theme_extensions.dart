import 'package:flutter/material.dart';
import 'app_colors.dart';

extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bgColor =>
      isDark ? AppColors.darkBackground : AppColors.background;

  Color get cardColor =>
      isDark ? AppColors.darkCard : AppColors.surface;

  Color get borderColor =>
      isDark ? AppColors.darkBorder : AppColors.border;

  Color get textPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

  Color get textTertiary =>
      isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
}
