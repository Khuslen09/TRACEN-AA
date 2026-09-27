import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/onboarding_service.dart';
import '../services/permission_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_extensions.dart';
import '../widgets/tracen_logo.dart';
import 'home/home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'permission_request_screen.dart';

/// 앱 시작 시 1.8초간 로고를 보여주고, 로그인 상태에 따라 분기.
///
/// 분기 로직:
///   - currentUser가 있으면 → HomeScreen (자동 로그인)
///   - 없으면 → LoginScreen
///
/// 디자인 결정:
///   - 페이드인 + 살짝 확대(scale 0.8 → 1.0) 모션
///   - 로고 아래 보라 글로우
///   - 1.8초 — 너무 짧으면 어색, 너무 길면 답답
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1800), _navigateNext);
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;

    try {
      // 0. 첫 실행이면 Onboarding 먼저 (로그인 여부 무관)
      final onboardingDone = await OnboardingService.isCompleted();
      if (!mounted) return;
      if (!onboardingDone) {
        _push(const OnboardingScreen());
        return;
      }

      // 1. 로그인 안 되어 있으면 → Login
      if (!AuthService.isLoggedIn) {
        _push(const LoginScreen());
        return;
      }

      // 2. 로그인은 됐지만 권한이 빠져있으면 → Permission
      final allGranted = await PermissionService.areAllGranted();
      if (!mounted) return;

      // 자동 로그인 케이스: 오프라인 중 쌓인 큐 처리 (fire-and-forget)
      CloudSyncService.flushQueue();

      if (!allGranted) {
        _push(const PermissionRequestScreen());
        return;
      }

      // 3. 모두 OK → Home
      _push(const HomeScreen());
    } catch (e) {
      // 어느 단계든 실패하면 최소 LoginScreen으로 — 흰 화면 방지
      debugPrint('[Splash] 라우팅 실패, LoginScreen 폴백: $e');
      if (mounted) _push(const LoginScreen());
    }
  }

  void _push(Widget destination) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          // 로고 뒤 부드러운 보라 글로우
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.6,
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.6),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          // 로고 + 워드마크
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Opacity(
                opacity: _fade.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TracenLogo(size: 72), // 40% 축소
                      const SizedBox(height: 16),
                      Text(
                        '나의 여정을 기록하다',
                        style: AppTextStyles.small.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
