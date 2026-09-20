import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/onboarding_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_extensions.dart';
import 'login_screen.dart';

/// AA 첫 실행 시 보여주는 Onboarding.
///
/// 3장 슬라이드로 핵심 가치를 전달:
///   1. 경로 추적 — "걸은 길을 지도에 그려요"
///   2. 사진/메모 핀 — "특별한 순간을 남겨요"
///   3. 클라우드 백업 — "어떤 기기에서든 다시 볼 수 있어요"
///
/// 디자인 결정:
///   - 일러스트 대신 큰 보라 아이콘 + 헤드라인 — 일러스트 없이도 톤 유지
///   - PageView로 좌우 스와이프 가능
///   - 우상단 "건너뛰기" — 강제 안 함
///   - 마지막 페이지에서만 "시작하기" 버튼
///
/// 완료 시 [OnboardingService.markCompleted] → LoginScreen으로 이동.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  List<_OnboardingPageData> _pages(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      _OnboardingPageData(
        icon: Icons.near_me_rounded,
        title: l10n.onboarding1Title,
        description: l10n.onboarding1Desc,
      ),
      _OnboardingPageData(
        icon: Icons.photo_camera_outlined,
        title: l10n.onboarding2Title,
        description: l10n.onboarding2Desc,
      ),
      _OnboardingPageData(
        icon: Icons.cloud_done_outlined,
        title: l10n.onboarding3Title,
        description: l10n.onboarding3Desc,
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isLast(BuildContext context) => _index == _pages(context).length - 1;

  Future<void> _finish() async {
    await OnboardingService.markCompleted();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _next(BuildContext context) {
    if (_isLast(context)) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = _pages(context);
    final isLast = _isLast(context);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 상단: 우측 건너뛰기
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    l10n.onboardingSkip,
                    style: AppTextStyles.smallBold.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ),
            ),

            // 본문 슬라이드
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _OnboardingPage(data: pages[i]),
              ),
            ),

            // 인디케이터 + 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              child: Column(
                children: [
                  _PageIndicator(count: pages.length, current: _index),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppShadows.primary,
                      ),
                      child: ElevatedButton(
                        onPressed: () => _next(context),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            isLast ? l10n.onboardingStart : l10n.onboardingNext,
                            key: ValueKey(isLast),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sub Widgets
// ──────────────────────────────────────────────────────────────

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 일러스트 자리 — 보라 그라데이션 동그라미 안에 큰 아이콘
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryLight,
                  AppColors.primary.withValues(alpha: 0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: AppColors.primary, size: 88),
          ),
          const SizedBox(height: 48),

          Text(
            data.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h1.copyWith(height: 1.3),
          ),
          const SizedBox(height: 14),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }
}

/// 페이지 인디케이터 — 작은 점들, 현재 페이지는 길쭉한 알약 형태.
class _PageIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _PageIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.gray300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
