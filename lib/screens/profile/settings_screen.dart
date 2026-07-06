import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import '../../theme/theme_provider.dart';
import '../../theme/locale_provider.dart';
import '../forgot_password_screen.dart';
import '../login_screen.dart';

/// 설정 화면.
///
/// 섹션:
///   1. 알림 — 위치/메모/러닝 알림 토글 (현재는 UI만, 실 동작은 추후)
///   2. 계정 — 비밀번호 재설정 메일, 연결된 계정 보기
///   3. 앱 정보 — 개인정보 처리방침, 이용약관, 버전
///   4. 하단 — 로그아웃 / 회원 탈퇴
///
/// 알림 설정은 진짜로 동작하려면 FCM/local_notifications 패키지가 필요한데,
/// 발표 데모 범위 밖이라 토글 UI만 제공. 추후 Phase에서 실제 알림 구현.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 알림 토글 — UI 상태만. 실제 알림 시스템은 추후.
  bool _locationNotif = true;
  bool _memoNotif = false;
  bool _runningNotif = true;

  bool _autoTracking = true;
  bool _processing = false;
  String _version = '—';

  // ─────────────────────────────────────────────
  // 초기화
  // ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadTrackingPref();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _loadTrackingPref() async {
    final enabled = await TrackingService.isEnabled();
    if (mounted) setState(() => _autoTracking = enabled);
  }

  // ─────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────

  Future<void> _onAutoTrackingChanged(bool value) async {
    setState(() => _autoTracking = value);
    await TrackingService.setEnabled(value);
  }

  void _sendPasswordReset() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          prefilledEmail: AuthService.currentUser?.email,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmDialog(
      title: l10n.signOutConfirmTitle,
      message: l10n.signOutConfirmMessage,
      confirmLabel: l10n.signOut,
      destructive: true,
    );
    if (confirmed != true) return;

    await AuthService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmDialog(
      title: l10n.deleteAccountConfirmTitle,
      message: l10n.deleteAccountConfirmMessage,
      confirmLabel: l10n.confirmDeleteAccount,
      destructive: true,
    );
    if (confirmed != true) return;

    setState(() => _processing = true);
    try {
      await AuthService.deleteAccount();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (mounted) {
        _showSnack(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) _showSnack(l10n.errorDeleteAccount, isError: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _openExternalUrl(String url, String label) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        _showSnack(
          AppLocalizations.of(context).errorOpenUrl(label),
          isError: true,
        );
      }
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(title, style: AppTextStyles.h3),
        content: Text(message, style: AppTextStyles.bodyMuted),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: destructive ? AppColors.danger : null,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.gray900,
      ),
    );
  }

  Future<void> _pickLanguage() async {
    final localeProvider = context.read<LocaleProvider>();
    final l10n = AppLocalizations.of(context);

    // 바텀시트 dismiss(바깥 탭/뒤로가기)와 "기기 언어 사용" 선택을 구분하기 위해
    // 결과를 [Locale?] 형태로 감싼다 — 바깥 탭이면 최상위 null, 선택이면 리스트(내부가 null일 수도 있음).
    final result = await showModalBottomSheet<List<Locale?>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(l10n.languageTitle, style: AppTextStyles.h3),
              const SizedBox(height: 8),
              // 기기 언어 자동 감지 옵션
              ListTile(
                title: Text(l10n.languageSystemDefault),
                trailing: localeProvider.locale == null
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, <Locale?>[null]),
              ),
              for (final locale in LocaleProvider.supportedLocales)
                ListTile(
                  title: Text(localeProvider.labelFor(locale)),
                  trailing: localeProvider.locale?.languageCode ==
                          locale.languageCode
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, <Locale?>[locale]),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (result == null) return; // 바깥 탭으로 닫음 — 아무것도 바꾸지 않음
    await localeProvider.setLocale(result.first);
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final currentLanguageLabel = localeProvider.locale == null
        ? l10n.languageSystemDefault
        : localeProvider.labelFor(localeProvider.locale!);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── 외관 ──
          _SectionHeader(l10n.sectionAppearance),
          _SettingsCard(
            children: [
              _SwitchTile(
                icon: Icons.dark_mode_outlined,
                title: l10n.darkModeTitle,
                subtitle: l10n.darkModeSubtitle,
                value: context.watch<ThemeProvider>().isDark,
                onChanged: (_) => context.read<ThemeProvider>().toggle(),
              ),
            ],
          ),

          // ── 언어 ──
          _SectionHeader(l10n.sectionLanguage),
          _SettingsCard(
            children: [
              _NavTile(
                icon: Icons.language_rounded,
                title: l10n.languageTitle,
                subtitle: currentLanguageLabel,
                onTap: _pickLanguage,
              ),
            ],
          ),

          // ── 추적 ──
          _SectionHeader(l10n.sectionTracking),
          _SettingsCard(
            children: [
              _SwitchTile(
                icon: Icons.near_me_rounded,
                title: l10n.autoTrackingTitle,
                subtitle: l10n.autoTrackingSubtitle,
                value: _autoTracking,
                onChanged: _onAutoTrackingChanged,
              ),
            ],
          ),

          // ── 알림 ──
          _SectionHeader(l10n.sectionNotifications),
          _SettingsCard(
            children: [
              _SwitchTile(
                icon: Icons.location_on_outlined,
                title: l10n.locationNotifTitle,
                subtitle: l10n.locationNotifSubtitle,
                value: _locationNotif,
                onChanged: (v) => setState(() => _locationNotif = v),
              ),
              const _Divider(),
              _SwitchTile(
                icon: Icons.edit_note_rounded,
                title: l10n.memoNotifTitle,
                subtitle: l10n.memoNotifSubtitle,
                value: _memoNotif,
                onChanged: (v) => setState(() => _memoNotif = v),
              ),
              const _Divider(),
              _SwitchTile(
                icon: Icons.directions_run_rounded,
                title: l10n.runningNotifTitle,
                subtitle: l10n.runningNotifSubtitle,
                value: _runningNotif,
                onChanged: (v) => setState(() => _runningNotif = v),
              ),
            ],
          ),

          // ── 계정 ──
          _SectionHeader(l10n.sectionAccount),
          _SettingsCard(
            children: [
              _NavTile(
                icon: Icons.lock_outline_rounded,
                title: l10n.resetPasswordTitle,
                subtitle: l10n.resetPasswordSubtitle,
                onTap: _sendPasswordReset,
              ),
              const _Divider(),
              _NavTile(
                icon: Icons.email_outlined,
                title: AuthService.currentUser?.email ?? l10n.noEmail,
                subtitle: l10n.loggedInAccount,
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
            ],
          ),

          // ── 앱 정보 ──
          _SectionHeader(l10n.sectionAppInfo),
          _SettingsCard(
            children: [
              _NavTile(
                icon: Icons.privacy_tip_outlined,
                title: l10n.privacyPolicy,
                onTap: () => _openExternalUrl(
                  'https://khuslen09.github.io/TRACEN/#privacy',
                  l10n.privacyPolicy,
                ),
              ),
              const _Divider(),
              _NavTile(
                icon: Icons.description_outlined,
                title: l10n.termsOfService,
                onTap: () => _openExternalUrl(
                  'https://khuslen09.github.io/TRACEN/#terms',
                  l10n.termsOfService,
                ),
              ),
              const _Divider(),
              _NavTile(
                icon: Icons.info_outline_rounded,
                title: l10n.versionLabel,
                trailing: Text(_version, style: AppTextStyles.bodyMuted),
                onTap: null,
              ),
            ],
          ),

          // ── 로그아웃 / 탈퇴 ──
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton(
              onPressed: _processing ? null : _signOut,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: AppTextStyles.button,
              ),
              child: Text(l10n.signOut),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _processing ? null : _deleteAccount,
              child: Text(
                l10n.deleteAccountAction,
                style: AppTextStyles.small.copyWith(
                  color: AppColors.gray500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sub Widgets
// ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.gray500,
          letterSpacing: 1.5,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.sm,
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Container(height: 1, color: AppColors.gray100),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: context.textPrimary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTextStyles.small),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.gray200,
            thumbColor: WidgetStatePropertyAll(Colors.white),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isClickable = onTap != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: context.textPrimary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppTextStyles.small),
                  ],
                ],
              ),
            ),
            trailing ??
                (isClickable
                    ? const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.gray300,
                      )
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
