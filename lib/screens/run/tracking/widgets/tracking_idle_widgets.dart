import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/activity_type.dart';
import '../../../../services/activity_recorder.dart';
import '../../../../services/permission_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../theme/theme_extensions.dart';

/// 시작 대기(idle) 상태의 지표 패널 자리 — 활동 종류 선택 + GPS 상태.
///
/// 기록 화면과 같은 2분할 구조 안에서 위쪽 카드만 이 위젯으로 바뀐다.
/// [panelHeight]는 `SplitTrackingLayout.lockedMetricsHeight`로 그대로 넘겨
/// 대기 중에는 드래그 없이 고정 높이로 보여준다.
class TrackingIdlePanel extends StatelessWidget {
  static const double panelHeight = 262;

  final ActivityType selected;
  final ValueChanged<ActivityType> onSelected;
  final ValueListenable<double?> accuracyListenable;

  const TrackingIdlePanel({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.accuracyListenable,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.trackingIdleTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final t in ActivityType.values) ...[
                  if (t != ActivityType.values.first) const SizedBox(width: 8),
                  Expanded(
                    child: _TypeCard(
                      type: t,
                      hint: switch (t) {
                        ActivityType.running => l10n.trackingIdleHintRunning,
                        ActivityType.walking => l10n.trackingIdleHintWalking,
                        ActivityType.cycling => l10n.trackingIdleHintCycling,
                      },
                      selected: t == selected,
                      onTap: () => onSelected(t),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<double?>(
              valueListenable: accuracyListenable,
              builder: (context, acc, _) => _GpsStatusRow(accuracy: acc),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final ActivityType type;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBg = context.isDark
        ? AppColors.primary.withValues(alpha: 0.18)
        : AppColors.primaryLight;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 100,
        decoration: BoxDecoration(
          color: selected ? selectedBg : context.bgColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type.icon,
              size: 30,
              color: selected ? AppColors.primary : context.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              type.label,
              style: AppTextStyles.bodyBold.copyWith(
                color: context.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsStatusRow extends StatelessWidget {
  final double? accuracy;
  const _GpsStatusRow({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final acc = accuracy;
    final ready = acc != null && acc <= ActivityRecorder.readyAccuracyMeters;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          _PulsingDot(
            color: ready ? AppColors.success : AppColors.warning,
            pulsing: !ready,
          ),
          const SizedBox(width: 8),
          Text(
            ready ? l10n.trackingGpsReady : l10n.trackingGpsSearching,
            style: AppTextStyles.smallBold.copyWith(color: context.textPrimary),
          ),
          const Spacer(),
          if (acc != null)
            Text(
              '± ${acc.round()}m',
              style: AppTextStyles.small
                  .copyWith(color: context.textSecondary)
                  .merge(
                    const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
            ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool pulsing;
  const _PulsingDot({required this.color, required this.pulsing});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.pulsing && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.3).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// 대기 상태 하단 — 큰 "○○ 시작" 버튼. GPS가 아직 준비 전이면 살짝
/// 흐리게 보이지만 누를 수는 있다(누르면 화면 쪽에서 약한 신호 확인창).
class TrackingStartButton extends StatelessWidget {
  final ActivityType activityType;
  final bool gpsReady;
  final VoidCallback onPressed;

  const TrackingStartButton({
    super.key,
    required this.activityType,
    required this.gpsReady,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: gpsReady ? 1 : 0.6,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: AppShadows.primary,
            ),
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: onPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.trackingStartActivity(activityType.label),
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 위치 권한이 없을 때 시작 버튼 자리에 뜨는 안내 카드 — "사용 중"과
/// "항상"을 각각 따로 요청. 영구 거부면 설정 앱으로 보내는 버튼만.
class TrackingPermissionCard extends StatelessWidget {
  final AppPermissionStatus status;
  final VoidCallback onAllowWhileUsing;
  final VoidCallback onAllowAlways;
  final VoidCallback onOpenSettings;

  const TrackingPermissionCard({
    super.key,
    required this.status,
    required this.onAllowWhileUsing,
    required this.onAllowAlways,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final blocked = status == AppPermissionStatus.permanentlyDenied;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.trackingPermTitle,
                      style: AppTextStyles.h3.copyWith(
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.trackingPermBody,
                style: AppTextStyles.small.copyWith(
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              if (blocked)
                _PermButton(
                  label: l10n.trackingPermSettings,
                  primary: true,
                  onTap: onOpenSettings,
                )
              else ...[
                _PermButton(
                  label: l10n.trackingPermWhileUsing,
                  primary: true,
                  onTap: onAllowWhileUsing,
                ),
                const SizedBox(height: 8),
                _PermButton(
                  label: l10n.trackingPermAlways,
                  primary: false,
                  onTap: onAllowAlways,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PermButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _PermButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.primary : context.bgColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyBold.copyWith(
                color: primary ? Colors.white : context.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 3 → 2 → 1 카운트다운. 탭하면 바로 [onFinished].
class TrackingCountdownOverlay extends StatefulWidget {
  final VoidCallback onFinished;
  const TrackingCountdownOverlay({super.key, required this.onFinished});

  @override
  State<TrackingCountdownOverlay> createState() =>
      _TrackingCountdownOverlayState();
}

class _TrackingCountdownOverlayState extends State<TrackingCountdownOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  int _count = 3;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s != AnimationStatus.completed || _done) return;
      if (_count <= 1) {
        _finish();
      } else {
        setState(() => _count--);
        _c.forward(from: 0);
      }
    });
    _c.forward();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                final scale = t < 0.25 ? 1.5 - (t / 0.25) * 0.5 : 1.0;
                final opacity = t < 0.25
                    ? t / 0.25
                    : (t > 0.85 ? 1 - (t - 0.85) / 0.15 * 0.8 : 1.0);
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: Text(
                      '$_count',
                      style: const TextStyle(
                        fontSize: 140,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              l10n.trackingCountdownSkip,
              style: AppTextStyles.small.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
