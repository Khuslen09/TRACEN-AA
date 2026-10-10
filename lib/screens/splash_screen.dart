import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/category_sync_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/onboarding_service.dart';
import '../services/permission_service.dart';
import '../theme/theme_extensions.dart';
import 'home/home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'permission_request_screen.dart';

/// 앱 시작 시 첫 화면 — 아무것도 그리지 않고(배경색만) 첫 프레임 직후
/// 바로 다음 화면으로 분기한다. 예전엔 1.8초간 로고·태그라인을 보여줬지만
/// 뺐다.
///
/// 분기 로직:
///   - 첫 실행이면 → OnboardingScreen
///   - currentUser가 없으면 → LoginScreen
///   - 권한이 빠져있으면 → PermissionRequestScreen
///   - 모두 OK → HomeScreen (자동 로그인)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigateNext());
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
      // 다른 기기에서 바꾼 카테고리 받기 (fire-and-forget — 오면 화면이 갱신됨)
      CategorySyncService.pull();

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
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: context.bgColor);
  }
}
