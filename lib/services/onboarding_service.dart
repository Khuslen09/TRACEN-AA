import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding 슬라이드를 봤는지 여부를 OS-level 영구 저장소에 기록.
///
/// SharedPreferences는 앱 삭제 전까지 유지됨.
/// 사용자가 앱을 재설치하면 다시 첫 실행으로 간주되어 Onboarding 노출.
class OnboardingService {
  OnboardingService._();

  static const _key = 'onboarding_completed';

  /// 사용자가 이미 Onboarding을 봤는지 여부.
  /// 앱 시작 시 SplashScreen에서 호출.
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// Onboarding 완료 표시. 마지막 슬라이드의 "시작하기" 버튼에서 호출.
  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// 디버그/테스트용 — Onboarding을 다시 보고 싶을 때.
  /// 제품에서는 노출하지 않지만, Settings에 숨겨진 디버그 메뉴로 노출 가능.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
