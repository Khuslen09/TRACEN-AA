import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/activity_type.dart';
import '../../../../services/run_metrics.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../theme/theme_extensions.dart';
import '../tracking_state.dart';

enum _Variant { big, balanced, thin }

/// 지표 패널 — 둥근 카드. [currentHeight]는 드래그 중에도 계속 바뀌는
/// "지금 실제로 쓸 수 있는 높이"이고, 이 값만으로 레이아웃을 고른다
/// (스냅 상태가 아니라 실측 높이 기준 — SplitTrackingLayout의 설계 의도 참고).
class TrackingMetricsPanel extends StatelessWidget {
  final ActivityType activityType;
  final ValueNotifier<TrackingMetrics> metricsListenable;
  final double currentHeight;

  // 레이아웃별 최소 필요 높이 — 이 밑으로 내려가면 즉시 더 작은 레이아웃으로.
  static const _minHeightBig = 380.0;
  static const _minHeightBalanced = 220.0;

  const TrackingMetricsPanel({
    super.key,
    required this.activityType,
    required this.metricsListenable,
    required this.currentHeight,
  });

  _Variant get _variant {
    if (currentHeight >= _minHeightBig) return _Variant.big;
    if (currentHeight >= _minHeightBalanced) return _Variant.balanced;
    return _Variant.thin;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.sm,
        ),
        child: ValueListenableBuilder<TrackingMetrics>(
          valueListenable: metricsListenable,
          builder: (context, m, _) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (_variant) {
                _Variant.big => _BigLayout(
                  key: const ValueKey('big'),
                  activityType: activityType,
                  m: m,
                  l10n: l10n,
                ),
                _Variant.balanced => _BalancedLayout(
                  key: const ValueKey('balanced'),
                  activityType: activityType,
                  m: m,
                  l10n: l10n,
                ),
                _Variant.thin => _ThinLayout(
                  key: const ValueKey('thin'),
                  activityType: activityType,
                  m: m,
                  l10n: l10n,
                ),
              },
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 공용 포맷 헬퍼
// ─────────────────────────────────────────────────────────────

String _primaryValue(ActivityType t, TrackingMetrics m) => t.usesPace
    ? RunMetrics.formatPace(m.currentPaceSecondsPerKm)
    : RunMetrics.formatSpeedKmh(m.currentSpeedKmh);

String _primaryUnit(ActivityType t) => t.usesPace ? '/km' : 'km/h';

String _avgValue(ActivityType t, TrackingMetrics m) => t.usesPace
    ? RunMetrics.formatPace(m.avgPaceSecondsPerKm)
    : RunMetrics.formatSpeedKmh(m.avgSpeedKmh);

const _tabularFigures = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
);

// ─────────────────────────────────────────────────────────────
// 1) 지표 크게 (metricsExpanded) — 주요 지표 초대형 + 2열 그리드
// ─────────────────────────────────────────────────────────────

class _BigLayout extends StatelessWidget {
  final ActivityType activityType;
  final TrackingMetrics m;
  final AppLocalizations l10n;

  const _BigLayout({
    super.key,
    required this.activityType,
    required this.m,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final gridItems = <(String, String)>[
      (l10n.runTime, RunMetrics.formatElapsed(m.elapsed)),
      (l10n.runDistance, RunMetrics.formatDistance(m.distanceMeters)),
      activityType.usesPace
          ? (l10n.runAvgPace, '${RunMetrics.formatPace(m.avgPaceSecondsPerKm)}/km')
          : (l10n.metricAvgSpeed, '${RunMetrics.formatSpeedKmh(m.avgSpeedKmh)} km/h'),
      if (!activityType.usesPace)
        (l10n.metricMaxSpeed, '${RunMetrics.formatSpeedKmh(m.maxSpeedKmh)} km/h'),
      (l10n.metricAltitude, '${m.altitudeMeters.toStringAsFixed(0)} m'),
      if (activityType.tracksSteps) (l10n.metricSteps, '${m.steps}'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activityType.usesPace ? l10n.runPace : l10n.metricSpeed,
          style: AppTextStyles.smallBold.copyWith(
            letterSpacing: 1.2,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _primaryValue(activityType, m),
                style: AppTextStyles.display
                    .copyWith(fontSize: 64, fontWeight: FontWeight.w800, color: AppColors.primary)
                    .merge(_tabularFigures),
              ),
              const SizedBox(width: 8),
              Text(
                _primaryUnit(activityType),
                style: AppTextStyles.h3.copyWith(color: context.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.6,
          children: [
            for (final item in gridItems) _GridStat(label: item.$1, value: item.$2),
          ],
        ),
      ],
    );
  }
}

class _GridStat extends StatelessWidget {
  final String label;
  final String value;
  const _GridStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: context.textTertiary)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppTextStyles.h3.copyWith(color: context.textPrimary).merge(_tabularFigures),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 2) 기본 (balanced) — 주요 지표 1개 크게 + 보조 3개
// ─────────────────────────────────────────────────────────────

class _BalancedLayout extends StatelessWidget {
  final ActivityType activityType;
  final TrackingMetrics m;
  final AppLocalizations l10n;

  const _BalancedLayout({
    super.key,
    required this.activityType,
    required this.m,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          activityType.usesPace ? l10n.runPace : l10n.metricSpeed,
          style: AppTextStyles.smallBold.copyWith(
            letterSpacing: 1.2,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _primaryValue(activityType, m),
                style: AppTextStyles.display
                    .copyWith(fontSize: 44, fontWeight: FontWeight.w800, color: AppColors.primary)
                    .merge(_tabularFigures),
              ),
              const SizedBox(width: 6),
              Text(
                _primaryUnit(activityType),
                style: AppTextStyles.body.copyWith(color: context.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatColumn(label: l10n.runTime, value: RunMetrics.formatElapsed(m.elapsed)),
            _StatDivider(),
            _StatColumn(label: l10n.runDistance, value: RunMetrics.formatDistance(m.distanceMeters)),
            _StatDivider(),
            _StatColumn(
              label: activityType.usesPace ? l10n.runAvgPace : l10n.metricAvgSpeed,
              value: _avgValue(activityType, m),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: context.textTertiary),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.h3
                  .copyWith(fontWeight: FontWeight.w700, color: context.textPrimary)
                  .merge(_tabularFigures),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: context.borderColor);
}

// ─────────────────────────────────────────────────────────────
// 3) 지도 크게 (mapExpanded) — 얇은 한 줄 바
// ─────────────────────────────────────────────────────────────

class _ThinLayout extends StatelessWidget {
  final ActivityType activityType;
  final TrackingMetrics m;
  final AppLocalizations l10n;

  const _ThinLayout({
    super.key,
    required this.activityType,
    required this.m,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(activityType.icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _primaryValue(activityType, m),
                  style: AppTextStyles.h2
                      .copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)
                      .merge(_tabularFigures),
                ),
                const SizedBox(width: 4),
                Text(
                  _primaryUnit(activityType),
                  style: AppTextStyles.small.copyWith(color: context.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          RunMetrics.formatElapsed(m.elapsed),
          style: AppTextStyles.bodyBold
              .copyWith(color: context.textPrimary)
              .merge(_tabularFigures),
        ),
      ],
    );
  }
}
