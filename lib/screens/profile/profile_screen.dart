import '../../l10n/generated/app_localizations.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/timeline_entry.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/route_db_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import '../home/timeline_screen.dart';
import '../home/widgets/pin_preview_sheet.dart';
import 'profile_edit_screen.dart';
import 'settings_screen.dart';

/// 프로필 화면.
///
/// 구성:
///   1. 상단 헤더 — 프로필 사진 + 닉네임 + 이메일 + 편집/설정 버튼
///   2. 통계 카드 — 총 여정 / 총 거리 / 총 핀
///   3. 최근 사진 그리드 — 가장 최근 핀 6개 (사진 있는 것)
///   4. "타임라인 전체 보기" 버튼
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  late Future<_ProfileData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_ProfileData> _loadData() async {
    final user = await AuthService.fetchCurrentUserProfile();
    final uid = AuthService.currentUser?.uid;

    final stats = await RouteDBService.getUserStats(uid);

    final pinRows = await RouteDBService.getAllPinsWithRoute(
      userId: uid,
      photoOnly: true,
    );
    final recentPhotos = pinRows.take(6).map(TimelineEntry.fromMap).toList();

    return _ProfileData(user: user, stats: stats, recentPhotos: recentPhotos);
  }

  Future<void> _refresh() async {
    setState(() => _dataFuture = _loadData());
    await _dataFuture;
  }

  Future<void> _openEdit(AppUser? user) async {
    if (user == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditScreen(user: user)),
    );
    if (updated == true) await _refresh();
  }

  Future<void> _openSettings() async {
    final shouldRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (shouldRefresh == true && mounted) await _refresh();
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: FutureBuilder<_ProfileData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return Center(child: Text(l10n.profileLoadFailed));
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(data.user),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ProfileHeader(user: data.user),
                      const SizedBox(height: 24),
                      _StatsCard(stats: data.stats),
                      const SizedBox(height: 28),
                      _RecentPhotosSection(
                        entries: data.recentPhotos,
                        onSeeAll: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TimelineScreen(),
                            ),
                          );
                        },
                        onTapPhoto: (entry) {
                          PinPreviewSheet.show(
                            context,
                            pin: entry.pin,
                            onDelete: () async {
                              if (entry.pin.id == null) return;
                              await RouteDBService.deletePin(entry.pin.id!);
                              await _refresh();
                            },
                          );
                        },
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(AppUser? user) {
    return SliverAppBar(
      backgroundColor: context.bgColor,
      elevation: 0,
      pinned: true,
      title: Text(l10n.navProfile),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 22),
          onPressed: () => _openEdit(user),
          tooltip: l10n.profileEdit,
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 22),
          onPressed: _openSettings,
          tooltip: l10n.settingsTitle,
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sub Widgets
// ──────────────────────────────────────────────────────────────

class _ProfileData {
  final AppUser? user;
  final UserStats stats;
  final List<TimelineEntry> recentPhotos;

  const _ProfileData({
    required this.user,
    required this.stats,
    required this.recentPhotos,
  });
}

class _ProfileHeader extends StatelessWidget {
  final AppUser? user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = user?.name ?? l10n.profileNoName;
    final email = user?.email ?? '';

    return Column(
      children: [
        _Avatar(photoUrl: user?.photoUrl, size: 96),
        const SizedBox(height: 16),
        Text(name, style: AppTextStyles.h2),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(email, style: AppTextStyles.small),
        ],
      ],
    );
  }
}

/// 프로필 사진 — URL 우선, 없으면 첫 글자 이니셜.
class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final double size;
  const _Avatar({required this.photoUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final hasUrl = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasUrl
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
        boxShadow: AppShadows.md,
      ),
      child: ClipOval(
        child: hasUrl
            ? _NetworkOrFile(url: photoUrl!)
            : Center(
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: size * 0.5,
                ),
              ),
      ),
    );
  }
}

/// http(s)면 Image.network, 아니면 Image.file.
/// (사용자가 막 사진 바꾼 직후 로컬 경로일 수 있음)
class _NetworkOrFile extends StatelessWidget {
  final String url;

  const _NetworkOrFile({required this.url});

  @override
  Widget build(BuildContext context) {
    final isRemote = url.startsWith('http');
    final fallback = Container(
      color: AppColors.primaryLight,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        color: AppColors.primary,
        size: 36,
      ),
    );

    if (isRemote) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (ctx, child, p) =>
            p == null ? child : Container(color: AppColors.primaryLight),
      );
    }
    return Image.file(
      File(url),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _StatsCard extends StatelessWidget {
  final UserStats stats;
  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          _StatItem(
            label: l10n.statRuns,
            value: '${stats.routeCount}',
            icon: Icons.near_me_rounded,
          ),
          _StatDivider(),
          _StatItem(
            label: l10n.statDistance,
            value: stats.formattedDistance,
            icon: Icons.straighten_rounded,
          ),
          _StatDivider(),
          _StatItem(
            label: l10n.statPins,
            value: '${stats.pinCount}',
            icon: Icons.place_rounded,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.h3),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.border);
  }
}

class _RecentPhotosSection extends StatelessWidget {
  final List<TimelineEntry> entries;
  final VoidCallback onSeeAll;
  final ValueChanged<TimelineEntry> onTapPhoto;

  const _RecentPhotosSection({
    required this.entries,
    required this.onSeeAll,
    required this.onTapPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.recentPhotos, style: AppTextStyles.h3)),
            TextButton(onPressed: onSeeAll, child: Text(l10n.seeAll)),
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          _EmptyPhotos()
        else
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final e in entries)
                GestureDetector(
                  onTap: () => onTapPhoto(e),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _PhotoTile(entry: e),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final TimelineEntry entry;
  const _PhotoTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final pin = entry.pin;
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
        errorBuilder: (_, __, ___) => _fallback(context),
        loadingBuilder: (ctx, child, p) =>
            p == null ? child : Container(color: context.cardColor),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) => Container(
    color: context.cardColor,
    child: Icon(Icons.image_outlined, color: context.textTertiary),
  );
}

class _EmptyPhotos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            color: context.textTertiary,
            size: 32,
          ),
          SizedBox(height: 8),
          Text(
            l10n.noPhotosYet,
            style: AppTextStyles.small.copyWith(color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}
