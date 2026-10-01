import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/theme_extensions.dart';

/// 하단에 항상 떠 있는 컨트롤 바 — 일시정지/재개, 길게 눌러 종료, 카메라.
///
/// [barHeight]/[bottomMargin]은 safe area를 제외한 고정값이라 호출 측
/// (ActivityTrackingScreen)이 `MediaQuery` safe-area bottom과 더해서
/// GoogleMap의 padding을 계산하는 데 그대로 쓸 수 있다.
class TrackingControlsBar extends StatelessWidget {
  static const double barHeight = 80;
  static const double bottomMargin = 16;

  final bool isPaused;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  /// 사진 촬영 — 이번 UI 단계에서는 자리만, 실제 촬영 로직은 범위 밖.
  /// TODO(다음 단계): SaveFilesScreen 등과 연결.
  final VoidCallback? onCamera;

  const TrackingControlsBar({
    super.key,
    required this.isPaused,
    required this.onPauseResume,
    required this.onStop,
    this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: bottomMargin),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: barHeight,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: AppShadows.lg,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleButton(
                icon: Icons.camera_alt_rounded,
                onTap: onCamera,
                background: context.bgColor,
                foreground: context.textSecondary,
              ),
              GestureDetector(
                onLongPress: onStop,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.trackingHoldToStop)),
                  );
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stop_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              _CircleButton(
                icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                onTap: onPauseResume,
                background: AppColors.primary,
                foreground: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: foreground, size: 22),
        ),
      ),
    );
  }
}
