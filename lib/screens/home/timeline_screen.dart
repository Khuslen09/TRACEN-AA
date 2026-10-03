import '../../l10n/strings.dart';
import '../../l10n/generated/app_localizations.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/pin.dart';
import '../../models/timeline_entry.dart';
import '../../services/auth_service.dart';
import '../../services/route_db_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import '../pin_date_location_picker_screen.dart';
import 'widgets/pin_preview_sheet.dart';

/// Picture / Memo Timeline 화면.
///
/// 두 모드의 구조가 비슷해서 공통 화면으로 통합:
///   - Picture: 월별 헤더 + 일별 작은 사진 그리드
///   - Memo: 월별 헤더 + 큰 카드 (날짜 뱃지 + 메모 + 여정 정보)
///
/// 데이터 소스: 사용자의 모든 여정의 모든 핀 → 모드에 맞게 필터링.
/// (사진 모드 = photoPath/photoUrl 있는 핀만, 메모 모드 = memo 있는 핀만)
class TimelineScreen extends StatefulWidget {
  final TimelineMode initialMode;

  const TimelineScreen({super.key, this.initialMode = TimelineMode.picture});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

enum TimelineMode { picture, memo }

class _TimelineScreenState extends State<TimelineScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  late TimelineMode _mode = widget.initialMode;
  late Future<List<TimelineEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _entriesFuture = _fetchEntries();
  }

  Future<List<TimelineEntry>> _fetchEntries() async {
    final uid = AuthService.currentUser?.uid;
    final rows = await RouteDBService.getAllPinsWithRoute(
      userId: uid, // 사용자 격리. null이면 전체 (테스트 모드)
      photoOnly: _mode == TimelineMode.picture,
      memoOnly: _mode == TimelineMode.memo,
    );
    return rows.map(TimelineEntry.fromMap).toList();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _entriesFuture;
  }

  void _switchMode(TimelineMode next) {
    if (_mode == next) return;
    setState(() {
      _mode = next;
      _load();
    });
  }

  void _openPinPreview(Pin pin) {
    PinPreviewSheet.show(
      context,
      pin: pin,
      onDelete: () async {
        if (pin.id == null) return;
        await RouteDBService.deletePin(pin.id!);
        await _refresh();
      },
    );
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(l10n.navTimeline),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // TODO(Week 4+): 검색 기능
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.searchComingSoon)));
            },
          ),
        ],
      ),
      // **v5 신규**: 과거 날짜에도 핀 추가 가능
      // FAB를 endFloat → endDocked 옆 toggle 위로 띄워 겹침 방지
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60), // 토글 높이만큼 위로
        child: FloatingActionButton(
          onPressed: () async {
            final added = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => const PinDateLocationPickerScreen(),
              ),
            );
            if (added == true) await _refresh();
          },
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 6,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<TimelineEntry>>(
              future: _entriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  );
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return _EmptyState(mode: _mode);
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _refresh,
                  child: _buildGroupedList(entries),
                );
              },
            ),
          ),

          // 하단 Picture/Memo 토글 (HomeScreen 톤과 동일)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _ModeToggle(mode: _mode, onChanged: _switchMode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<TimelineEntry> entries) {
    // 월 단위로 그룹핑 (createdAt 기준)
    final groups = <String, List<TimelineEntry>>{};
    for (final e in entries) {
      final key = DateFormat('yyyy-MM').format(e.pin.createdAt);
      groups.putIfAbsent(key, () => []).add(e);
    }
    final groupKeys = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: groupKeys.length,
      itemBuilder: (context, i) {
        final key = groupKeys[i];
        final monthLabel = _formatMonthHeader(key);
        final groupEntries = groups[key]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4, i == 0 ? 8 : 24, 4, 12),
              child: Text(
                monthLabel,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.gray500,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
            ),
            if (_mode == TimelineMode.picture)
              _PictureMonthGrid(entries: groupEntries, onTap: _openPinPreview)
            else
              _MemoMonthList(entries: groupEntries, onTap: _openPinPreview),
          ],
        );
      },
    );
  }

  String _formatMonthHeader(String key) {
    final parts = key.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.yMMMM(Strings.current.localeName).format(date).toUpperCase();
  }
}

// ──────────────────────────────────────────────────────────────
// Picture mode — 일별로 그룹핑 후 사진 그리드
// ──────────────────────────────────────────────────────────────

class _PictureMonthGrid extends StatelessWidget {
  final List<TimelineEntry> entries;
  final ValueChanged<Pin> onTap;

  const _PictureMonthGrid({required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 일별 그룹핑
    final byDay = <int, List<TimelineEntry>>{};
    for (final e in entries) {
      final day = e.pin.createdAt.day;
      byDay.putIfAbsent(day, () => []).add(e);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days) ...[
          _DayRow(day: day, entries: byDay[day]!, onTap: onTap),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  final int day;
  final List<TimelineEntry> entries;
  final ValueChanged<Pin> onTap;

  const _DayRow({
    required this.day,
    required this.entries,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 날짜 뱃지
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: AppTextStyles.h3.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),

          // 사진 그리드 (가로 스크롤)
          Expanded(
            child: SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _PhotoThumbnail(
                  entry: entries[i],
                  onTap: () => onTap(entries[i].pin),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final TimelineEntry entry;
  final VoidCallback onTap;

  const _PhotoThumbnail({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(width: 88, height: 88, child: _buildImage(context)),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final pin = entry.pin;

    // 로컬 우선, 없으면 네트워크
    if (pin.photoPath != null && pin.photoPath!.isNotEmpty) {
      return Image.file(
        File(pin.photoPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(context),
      );
    }
    if (pin.photoUrl != null && pin.photoUrl!.isNotEmpty) {
      return Image.network(
        pin.photoUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(color: context.cardColor);
        },
        errorBuilder: (_, __, ___) => _fallback(context),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) => Container(
    color: context.cardColor,
    child: Icon(Icons.image_outlined, color: context.textTertiary, size: 28),
  );
}

// ──────────────────────────────────────────────────────────────
// Memo mode — 큰 카드 리스트
// ──────────────────────────────────────────────────────────────

class _MemoMonthList extends StatelessWidget {
  final List<TimelineEntry> entries;
  final ValueChanged<Pin> onTap;

  const _MemoMonthList({required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries) ...[
          _MemoCard(entry: e, onTap: () => onTap(e.pin)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MemoCard extends StatelessWidget {
  final TimelineEntry entry;
  final VoidCallback onTap;

  const _MemoCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final day = DateFormat('d').format(entry.pin.createdAt);
    final time = DateFormat.jm(Strings.current.localeName).format(entry.pin.createdAt);
    // 풀 날짜 — routeTitle이 비어있을 때 fallback으로 사용
    final fullDate = DateFormat('yyyy.MM.dd').format(entry.pin.createdAt);
    final topLabel = entry.routeTitle.isNotEmpty ? entry.routeTitle : fullDate;

    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.sm,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 날짜 뱃지
              Container(
                width: 48,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day,
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // 메모 본문
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            topLabel,
                            style: AppTextStyles.smallBold.copyWith(
                              color: context.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          time,
                          style: AppTextStyles.caption.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.pin.memo ?? '',
                      style: AppTextStyles.body.copyWith(
                        color: context.textPrimary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 공통 — 토글, 빈 상태
// ──────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final TimelineMode mode;
  final ValueChanged<TimelineMode> onChanged;

  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cardColor, // 다크모드 대응
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          _segment(context, l10n.modePhoto, TimelineMode.picture),
          _segment(context, l10n.modeMemo, TimelineMode.memo),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, TimelineMode value) {
    final selected = mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTextStyles.smallBold.copyWith(
              color: selected ? Colors.white : context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final TimelineMode mode;
  const _EmptyState({required this.mode});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPicture = mode == TimelineMode.picture;
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
              child: Icon(
                isPicture
                    ? Icons.photo_library_rounded
                    : Icons.edit_note_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 24),
            Text(
              isPicture ? l10n.noPhotosYet : l10n.noMemosYet,
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              isPicture
                  ? l10n.emptyPhotoHint
                  : l10n.emptyMemoHint,
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
