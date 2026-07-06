import 'package:flutter/material.dart';

import '../services/permission_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_extensions.dart';
import 'home/home_screen.dart';

/// 권한 요청 안내 화면.
///
/// 표시 시점: 로그인 직후, Home 진입 전 1회 (모든 권한이 이미 허용된 경우는 스킵)
///
/// 디자인 원칙:
///   - 시스템 다이얼로그 띄우기 전에 "왜 필요한지" 먼저 설명 (iOS 표준 패턴)
///   - 3가지 권한을 카드로 한 화면에 — 각각 아이콘, 제목, 이유, 상태 뱃지
///   - "모두 허용하기" 버튼이 차례로 시스템 다이얼로그 호출
///   - 영구 거부된 권한이 있으면 → 앱 설정으로 이동 버튼 노출
///   - "나중에" 버튼 — 사용자가 일단 패스 가능 (나중에 기능 사용 시 다시 안내)
///
/// 화면을 닫고 Home으로 갈 때:
///   `Navigator.pushAndRemoveUntil` 사용 — 뒤로가기로 못 돌아오게.
class PermissionRequestScreen extends StatefulWidget {
  const PermissionRequestScreen({super.key});

  @override
  State<PermissionRequestScreen> createState() =>
      _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen>
    with WidgetsBindingObserver {
  AllPermissions _perms = const AllPermissions(
    location: AppPermissionStatus.notDetermined,
    camera: AppPermissionStatus.notDetermined,
    photos: AppPermissionStatus.notDetermined,
  );
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    // didChangeAppLifecycleState 받기 위해 옵저버 등록
    // 사용자가 "설정으로 이동" 후 돌아오면 권한 상태 다시 조회
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  // ─────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────

  Future<void> _refreshStatuses() async {
    final perms = await PermissionService.getAll();
    if (mounted) setState(() => _perms = perms);
  }

  /// "모두 허용하기" — 차례로 3개 권한을 시스템 다이얼로그로 요청.
  ///
  /// 이미 허용된 권한은 즉시 통과, 영구 거부된 것은 시스템이 다이얼로그를 안 띄우므로
  /// 그냥 다음 권한으로 넘어감.
  Future<void> _requestAll() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    try {
      // 위치 → 카메라 → 사진 순서. 위치가 가장 핵심이라 먼저.
      if (_perms.location != AppPermissionStatus.granted &&
          _perms.location != AppPermissionStatus.permanentlyDenied) {
        await PermissionService.requestLocation();
      }
      if (_perms.camera != AppPermissionStatus.granted &&
          _perms.camera != AppPermissionStatus.permanentlyDenied) {
        await PermissionService.requestCamera();
      }
      if (_perms.photos != AppPermissionStatus.granted &&
          _perms.photos != AppPermissionStatus.permanentlyDenied) {
        await PermissionService.requestPhotos();
      }

      await _refreshStatuses();

      // 모두 허용됐으면 자동으로 Home 이동
      if (mounted &&
          _perms.location == AppPermissionStatus.granted &&
          _perms.camera == AppPermissionStatus.granted &&
          _perms.photos == AppPermissionStatus.granted) {
        _goToHome();
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _goToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasAnyPermanentlyDenied =
        _perms.location == AppPermissionStatus.permanentlyDenied ||
        _perms.camera == AppPermissionStatus.permanentlyDenied ||
        _perms.photos == AppPermissionStatus.permanentlyDenied;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 우측 "나중에" 버튼
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _goToHome,
                  child: Text(
                    '나중에',
                    style: AppTextStyles.smallBold.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroIcon(),
                    const SizedBox(height: 24),
                    Text(
                      '시작하기 전에\n권한을 확인해주세요',
                      style: AppTextStyles.h1.copyWith(height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'AA가 여정을 기록하려면 다음 권한이 필요해요.\n'
                      '나중에 언제든 설정에서 변경할 수 있어요.',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 권한 카드 3개
              Expanded(
                child: ListView(
                  children: [
                    _PermissionCard(
                      icon: Icons.location_on_outlined,
                      title: '위치 정보',
                      reason: 'GPS로 이동 경로를 지도에 그리고\n여정 거리를 계산해요',
                      status: _perms.location,
                    ),
                    const SizedBox(height: 12),
                    _PermissionCard(
                      icon: Icons.camera_alt_outlined,
                      title: '카메라',
                      reason: '특별한 순간에 인증샷을\n바로 남길 수 있어요',
                      status: _perms.camera,
                    ),
                    const SizedBox(height: 12),
                    _PermissionCard(
                      icon: Icons.photo_library_outlined,
                      title: '사진 라이브러리',
                      reason: '저장된 사진을 핀에 첨부해서\n추억을 더 풍성하게 기록해요',
                      status: _perms.photos,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 하단 버튼
              if (hasAnyPermanentlyDenied)
                _SettingsButton(
                  onPressed: () async {
                    await PermissionService.openSettings();
                  },
                ),
              if (!hasAnyPermanentlyDenied)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppShadows.primary,
                  ),
                  child: ElevatedButton(
                    onPressed: _requesting ? null : _requestAll,
                    child: _requesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('모두 허용하기'),
                  ),
                ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sub Widgets
// ──────────────────────────────────────────────────────────────

class _HeroIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Icon(
        Icons.shield_outlined,
        color: AppColors.primary,
        size: 32,
      ),
    );
  }
}

/// 권한 한 개를 표현하는 카드.
class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String reason;
  final AppPermissionStatus status;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.reason,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아이콘
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),

          // 제목 + 이유
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: AppTextStyles.bodyBold)),
                    const SizedBox(width: 8),
                    _StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(reason, style: AppTextStyles.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 권한 상태별 색상 + 라벨.
class _StatusBadge extends StatelessWidget {
  final AppPermissionStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;
    late final IconData? icon;

    switch (status) {
      case AppPermissionStatus.granted:
        label = '허용됨';
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        icon = Icons.check_rounded;
        break;
      case AppPermissionStatus.denied:
        label = '필요함';
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
        icon = null;
        break;
      case AppPermissionStatus.permanentlyDenied:
        label = '설정 필요';
        bg = AppColors.danger.withValues(alpha: 0.12);
        fg = AppColors.danger;
        icon = Icons.error_outline_rounded;
        break;
      case AppPermissionStatus.notDetermined:
        label = '미요청';
        bg = AppColors.gray500.withValues(alpha: 0.15);
        fg = AppColors.gray500;
        icon = null;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SettingsButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '거부된 권한이 있어요. 설정에서 직접 켜주세요.',
                  style: AppTextStyles.small.copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppShadows.primary,
          ),
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.settings_rounded, size: 20),
            label: const Text('설정으로 이동'),
          ),
        ),
      ],
    );
  }
}
