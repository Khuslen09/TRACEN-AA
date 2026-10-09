import '../../l10n/strings.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity_type.dart';
import '../../models/route.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/route_db_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import 'route_map_screen.dart';

/// 저장된 모든 여정의 리스트.
///
/// 디자인 결정:
///   - 월별 그룹핑 (sticky header 대신 일반 헤더 — 단순함 우선)
///   - 카드 형태로 정보 표시 (와이어프레임의 Picture Timeline 톤)
///   - 빈 상태 일러스트로 첫 사용자 경험 개선
///   - 카드 길게 누르기 → 삭제 확인 다이얼로그 (스와이프보다 모바일에서 안전)
///   - Pull-to-refresh — 핀 추가 후 돌아왔을 때 거리 갱신을 보장
class RouteListScreen extends StatefulWidget {
  /// 처음 걸어둘 종류 필터 — null이면 전체. 프로필의 종류별 통계에서 진입할 때 사용.
  final ActivityType? initialType;

  const RouteListScreen({super.key, this.initialType});

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  late Future<List<TraceRoute>> _routesFuture;

  /// 러닝/걷기/자전거 필터 — null이면 전체.
  late ActivityType? _type = widget.initialType;

  @override
  void initState() {
    super.initState();
    _routesFuture = _loadRoutes();
  }

  /// 현재 로그인된 사용자의 여정만 로드.
  /// 로그인 안 된 상태(개발 중)에서는 모든 여정 로드 fallback.
  Future<List<TraceRoute>> _loadRoutes() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return RouteDBService.getAllRoutes();
    return RouteDBService.getRoutesForUser(uid);
  }

  Future<void> _refresh() async {
    setState(() {
      _routesFuture = _loadRoutes();
    });
    await _routesFuture;
  }

  Future<void> _confirmDelete(TraceRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(l10n.deleteRunTitle, style: AppTextStyles.h3),
        content: Text(l10n.deleteRunBody, style: AppTextStyles.bodyMuted),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || route.id == null) return;
    await RouteDBService.deleteRoute(route.id!);
    CloudSyncService.syncRouteDeleted(route.uuid);
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.runDeleted)));
    }
  }

  Future<void> _openRoute(TraceRoute route) async {
    if (route.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RouteMapScreen(route: route)),
    );
    // 상세 화면에서 핀 변경 가능성 → 돌아오면 새로고침
    await _refresh();
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(l10n.myRuns),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<TraceRoute>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(message: l10n.loadFailed, onRetry: _refresh);
          }

          final all = snapshot.data ?? [];
          if (all.isEmpty) return const _EmptyState();
          final routes = _type == null
              ? all
              : all.where((r) => r.activityType == _type).toList();

          return Column(
            children: [
              _buildTypeFilter(),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _refresh,
                  child: routes.isEmpty
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 80),
                              child: Center(
                                child: Text(
                                  l10n.routeListEmptyForType(_type!.label),
                                  style: AppTextStyles.bodyMuted,
                                ),
                              ),
                            ),
                          ],
                        )
                      : _buildGroupedList(routes),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTypeFilter() {
    Widget chip(String label, ActivityType? type, IconData? icon) {
      final selected = _type == type;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: icon == null
              ? null
              : Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.gray500,
                ),
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _type = type),
          showCheckmark: false,
          selectedColor: AppColors.primary,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          labelStyle: AppTextStyles.smallBold.copyWith(
            color: selected ? Colors.white : AppColors.gray500,
          ),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        children: [
          chip(l10n.statAll, null, null),
          for (final t in ActivityType.values) chip(t.label, t, t.icon),
        ],
      ),
    );
  }

  /// 여정들을 "yyyy-MM" 키로 그룹핑한 후 월별 섹션으로 렌더링.
  Widget _buildGroupedList(List<TraceRoute> routes) {
    // 이미 startedAt DESC로 정렬된 상태로 들어옴 → 같은 순서 유지하며 그룹화
    final groups = <String, List<TraceRoute>>{};
    for (final r in routes) {
      final key = DateFormat('yyyy-MM').format(r.startedAt);
      groups.putIfAbsent(key, () => []).add(r);
    }

    final entries = groups.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: entries.length,
      itemBuilder: (context, groupIndex) {
        final group = entries[groupIndex];
        final monthLabel = _formatMonthHeader(group.key);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4, groupIndex == 0 ? 8 : 24, 4, 12),
              child: Text(
                monthLabel,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.gray500,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
            ),
            ...group.value.map(
              (route) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RouteCard(
                  route: route,
                  onTap: () => _openRoute(route),
                  onLongPress: () => _confirmDelete(route),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatMonthHeader(String key) {
    final parts = key.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.yMMMM(
      Strings.current.localeName,
    ).format(date).toUpperCase();
  }
}

// ──────────────────────────────────────────────────────────────
// Sub Widgets
// ──────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final TraceRoute route;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _RouteCard({
    required this.route,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final day = DateFormat('d').format(route.startedAt);
    final weekday = DateFormat.E(
      Strings.current.localeName,
    ).format(route.startedAt);
    final time = DateFormat.jm(
      Strings.current.localeName,
    ).format(route.startedAt);

    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.sm,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 날짜 뱃지 (와이어프레임의 보라 동그란 숫자 톤)
              _DateBadge(day: day, weekday: weekday),
              const SizedBox(width: 14),

              // 제목 + 거리 + 시간
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          route.activityType.icon,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            route.title,
                            style: AppTextStyles.bodyBold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (route.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  l10n.runInProgress,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.straighten_rounded,
                          size: 14,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDistance(route.distance),
                          style: AppTextStyles.small,
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(route.duration),
                          style: AppTextStyles.small,
                        ),
                        const SizedBox(width: 12),
                        Text(time, style: AppTextStyles.small),
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded, color: AppColors.gray300),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return Strings.current.durationHM(h, m);
    if (m > 0) return Strings.current.durationM(m);
    return Strings.current.durationS(d.inSeconds);
  }
}

/// 좌측 둥근 보라 뱃지 — 날짜 + 요일
class _DateBadge extends StatelessWidget {
  final String day;
  final String weekday;
  const _DateBadge({required this.day, required this.weekday});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: AppTextStyles.h3.copyWith(
              color: AppColors.primaryDark,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            weekday,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.near_me_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 24),
            Text(
              l10n.noRunsYet,
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              l10n.noRunsHint,
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.gray400,
          ),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.body),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}
