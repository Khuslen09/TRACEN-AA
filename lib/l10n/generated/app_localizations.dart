import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_mn.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
    Locale('mn'),
  ];

  /// 온보딩 건너뛰기 버튼
  ///
  /// In ko, this message translates to:
  /// **'건너뛰기'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get onboardingStart;

  /// No description provided for @onboarding1Title.
  ///
  /// In ko, this message translates to:
  /// **'당신만의 길을\n지도에 남겨보세요'**
  String get onboarding1Title;

  /// No description provided for @onboarding1Desc.
  ///
  /// In ko, this message translates to:
  /// **'산책, 러닝, 여행 — 어디든 AA와 \n함께 걸어요.'**
  String get onboarding1Desc;

  /// No description provided for @onboarding2Title.
  ///
  /// In ko, this message translates to:
  /// **'특별한 순간을\n기록해보세요'**
  String get onboarding2Title;

  /// No description provided for @onboarding2Desc.
  ///
  /// In ko, this message translates to:
  /// **'도착한 곳에서 사진과 메모를\n남겨보세요.'**
  String get onboarding2Desc;

  /// No description provided for @onboarding3Title.
  ///
  /// In ko, this message translates to:
  /// **'어디서든\n다시 꺼내보세요'**
  String get onboarding3Title;

  /// No description provided for @onboarding3Desc.
  ///
  /// In ko, this message translates to:
  /// **'안전하게 저장되어\n언제든 다시 꺼내볼 수 있어요.'**
  String get onboarding3Desc;

  /// No description provided for @settingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTitle;

  /// No description provided for @sectionAppearance.
  ///
  /// In ko, this message translates to:
  /// **'외관'**
  String get sectionAppearance;

  /// No description provided for @darkModeTitle.
  ///
  /// In ko, this message translates to:
  /// **'다크 모드'**
  String get darkModeTitle;

  /// No description provided for @darkModeSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'어두운 배경으로 전환해요'**
  String get darkModeSubtitle;

  /// No description provided for @sectionLanguage.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get sectionLanguage;

  /// No description provided for @languageTitle.
  ///
  /// In ko, this message translates to:
  /// **'앱 언어'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'표시 언어를 선택하세요'**
  String get languageSubtitle;

  /// No description provided for @languageSystemDefault.
  ///
  /// In ko, this message translates to:
  /// **'기기 언어 사용'**
  String get languageSystemDefault;

  /// No description provided for @sectionTracking.
  ///
  /// In ko, this message translates to:
  /// **'추적'**
  String get sectionTracking;

  /// No description provided for @autoTrackingTitle.
  ///
  /// In ko, this message translates to:
  /// **'자동 발자취 기록'**
  String get autoTrackingTitle;

  /// No description provided for @autoTrackingSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'앱이 켜진 동안 이동 경로를 지도에 기록해요'**
  String get autoTrackingSubtitle;

  /// No description provided for @sectionNotifications.
  ///
  /// In ko, this message translates to:
  /// **'알림'**
  String get sectionNotifications;

  /// No description provided for @locationNotifTitle.
  ///
  /// In ko, this message translates to:
  /// **'위치 추적 알림'**
  String get locationNotifTitle;

  /// No description provided for @locationNotifSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'경로 기록 중 알림을 받아요'**
  String get locationNotifSubtitle;

  /// No description provided for @memoNotifTitle.
  ///
  /// In ko, this message translates to:
  /// **'메모 저장 알림'**
  String get memoNotifTitle;

  /// No description provided for @memoNotifSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'메모가 저장됐을 때 알려드려요'**
  String get memoNotifSubtitle;

  /// No description provided for @runningNotifTitle.
  ///
  /// In ko, this message translates to:
  /// **'러닝 알림'**
  String get runningNotifTitle;

  /// No description provided for @runningNotifSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'러닝 완료 시 결과를 알려드려요'**
  String get runningNotifSubtitle;

  /// No description provided for @sectionAccount.
  ///
  /// In ko, this message translates to:
  /// **'계정'**
  String get sectionAccount;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 재설정'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'재설정 링크를 메일로 보내드려요'**
  String get resetPasswordSubtitle;

  /// No description provided for @noEmail.
  ///
  /// In ko, this message translates to:
  /// **'이메일 없음'**
  String get noEmail;

  /// No description provided for @loggedInAccount.
  ///
  /// In ko, this message translates to:
  /// **'로그인된 계정'**
  String get loggedInAccount;

  /// No description provided for @sectionAppInfo.
  ///
  /// In ko, this message translates to:
  /// **'앱 정보'**
  String get sectionAppInfo;

  /// No description provided for @privacyPolicy.
  ///
  /// In ko, this message translates to:
  /// **'개인정보 처리방침'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In ko, this message translates to:
  /// **'서비스 이용약관'**
  String get termsOfService;

  /// No description provided for @versionLabel.
  ///
  /// In ko, this message translates to:
  /// **'버전'**
  String get versionLabel;

  /// No description provided for @signOut.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get signOut;

  /// No description provided for @deleteAccountAction.
  ///
  /// In ko, this message translates to:
  /// **'회원 탈퇴'**
  String get deleteAccountAction;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃 할까요?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmMessage.
  ///
  /// In ko, this message translates to:
  /// **'다시 로그인해야 여정 기록을 이용할 수 있어요.'**
  String get signOutConfirmMessage;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In ko, this message translates to:
  /// **'정말 탈퇴하시겠어요?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmMessage.
  ///
  /// In ko, this message translates to:
  /// **'계정과 관련된 모든 정보가 삭제되며,\n복구할 수 없어요.'**
  String get deleteAccountConfirmMessage;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @confirmDeleteAccount.
  ///
  /// In ko, this message translates to:
  /// **'탈퇴하기'**
  String get confirmDeleteAccount;

  /// No description provided for @errorDeleteAccount.
  ///
  /// In ko, this message translates to:
  /// **'탈퇴 중 오류가 발생했어요'**
  String get errorDeleteAccount;

  /// No description provided for @errorOpenUrl.
  ///
  /// In ko, this message translates to:
  /// **'{label} 페이지를 열 수 없어요'**
  String errorOpenUrl(String label);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko', 'mn'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
    case 'mn':
      return AppLocalizationsMn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
