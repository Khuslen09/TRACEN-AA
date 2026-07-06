// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get onboardingSkip => '건너뛰기';

  @override
  String get onboardingNext => '다음';

  @override
  String get onboardingStart => '시작하기';

  @override
  String get onboarding1Title => '당신만의 길을\n지도에 남겨보세요';

  @override
  String get onboarding1Desc => '산책, 러닝, 여행 — 어디든 AA와 \n함께 걸어요.';

  @override
  String get onboarding2Title => '특별한 순간을\n기록해보세요';

  @override
  String get onboarding2Desc => '도착한 곳에서 사진과 메모를\n남겨보세요.';

  @override
  String get onboarding3Title => '어디서든\n다시 꺼내보세요';

  @override
  String get onboarding3Desc => '안전하게 저장되어\n언제든 다시 꺼내볼 수 있어요.';

  @override
  String get settingsTitle => '설정';

  @override
  String get sectionAppearance => '외관';

  @override
  String get darkModeTitle => '다크 모드';

  @override
  String get darkModeSubtitle => '어두운 배경으로 전환해요';

  @override
  String get sectionLanguage => '언어';

  @override
  String get languageTitle => '앱 언어';

  @override
  String get languageSubtitle => '표시 언어를 선택하세요';

  @override
  String get languageSystemDefault => '기기 언어 사용';

  @override
  String get sectionTracking => '추적';

  @override
  String get autoTrackingTitle => '자동 발자취 기록';

  @override
  String get autoTrackingSubtitle => '앱이 켜진 동안 이동 경로를 지도에 기록해요';

  @override
  String get sectionNotifications => '알림';

  @override
  String get locationNotifTitle => '위치 추적 알림';

  @override
  String get locationNotifSubtitle => '경로 기록 중 알림을 받아요';

  @override
  String get memoNotifTitle => '메모 저장 알림';

  @override
  String get memoNotifSubtitle => '메모가 저장됐을 때 알려드려요';

  @override
  String get runningNotifTitle => '러닝 알림';

  @override
  String get runningNotifSubtitle => '러닝 완료 시 결과를 알려드려요';

  @override
  String get sectionAccount => '계정';

  @override
  String get resetPasswordTitle => '비밀번호 재설정';

  @override
  String get resetPasswordSubtitle => '재설정 링크를 메일로 보내드려요';

  @override
  String get noEmail => '이메일 없음';

  @override
  String get loggedInAccount => '로그인된 계정';

  @override
  String get sectionAppInfo => '앱 정보';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get termsOfService => '서비스 이용약관';

  @override
  String get versionLabel => '버전';

  @override
  String get signOut => '로그아웃';

  @override
  String get deleteAccountAction => '회원 탈퇴';

  @override
  String get signOutConfirmTitle => '로그아웃 할까요?';

  @override
  String get signOutConfirmMessage => '다시 로그인해야 여정 기록을 이용할 수 있어요.';

  @override
  String get deleteAccountConfirmTitle => '정말 탈퇴하시겠어요?';

  @override
  String get deleteAccountConfirmMessage => '계정과 관련된 모든 정보가 삭제되며,\n복구할 수 없어요.';

  @override
  String get cancel => '취소';

  @override
  String get confirmDeleteAccount => '탈퇴하기';

  @override
  String get errorDeleteAccount => '탈퇴 중 오류가 발생했어요';

  @override
  String errorOpenUrl(String label) {
    return '$label 페이지를 열 수 없어요';
  }
}
