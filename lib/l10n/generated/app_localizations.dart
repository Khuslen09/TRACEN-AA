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
  /// **'산책, 러닝, 여행 — 어디든 Tracen과 \n함께 걸어요.'**
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

  /// No description provided for @commonEmail.
  ///
  /// In ko, this message translates to:
  /// **'이메일'**
  String get commonEmail;

  /// No description provided for @commonPassword.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호'**
  String get commonPassword;

  /// No description provided for @commonOr.
  ///
  /// In ko, this message translates to:
  /// **'또는'**
  String get commonOr;

  /// No description provided for @commonLogin.
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get commonLogin;

  /// No description provided for @loginEnterCredentials.
  ///
  /// In ko, this message translates to:
  /// **'이메일과 비밀번호를 입력해주세요'**
  String get loginEnterCredentials;

  /// No description provided for @loginError.
  ///
  /// In ko, this message translates to:
  /// **'로그인 중 오류가 발생했어요'**
  String get loginError;

  /// No description provided for @googleLoginFailed.
  ///
  /// In ko, this message translates to:
  /// **'Google 로그인에 실패했어요'**
  String get googleLoginFailed;

  /// No description provided for @loginWelcome.
  ///
  /// In ko, this message translates to:
  /// **'환영합니다'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'오늘의 여정을 기록해볼까요'**
  String get loginSubtitle;

  /// No description provided for @passwordHint.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 입력하세요'**
  String get passwordHint;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 잊으셨나요?'**
  String get forgotPasswordLink;

  /// No description provided for @continueWithGoogle.
  ///
  /// In ko, this message translates to:
  /// **'Google로 계속하기'**
  String get continueWithGoogle;

  /// No description provided for @continueWithAppleSoon.
  ///
  /// In ko, this message translates to:
  /// **'Apple로 계속하기 (준비 중)'**
  String get continueWithAppleSoon;

  /// No description provided for @noAccountYet.
  ///
  /// In ko, this message translates to:
  /// **'아직 계정이 없으신가요?'**
  String get noAccountYet;

  /// No description provided for @signUpAction.
  ///
  /// In ko, this message translates to:
  /// **'가입하기'**
  String get signUpAction;

  /// No description provided for @nameRequired.
  ///
  /// In ko, this message translates to:
  /// **'이름을 입력해주세요'**
  String get nameRequired;

  /// No description provided for @nameTooShort.
  ///
  /// In ko, this message translates to:
  /// **'이름은 2자 이상이어야 해요'**
  String get nameTooShort;

  /// No description provided for @emailRequired.
  ///
  /// In ko, this message translates to:
  /// **'이메일을 입력해주세요'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In ko, this message translates to:
  /// **'올바른 이메일 형식이 아니에요'**
  String get emailInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 입력해주세요'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호는 6자 이상이어야 해요'**
  String get passwordTooShort;

  /// No description provided for @passwordMismatch.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호가 일치하지 않아요'**
  String get passwordMismatch;

  /// No description provided for @agreeTermsRequired.
  ///
  /// In ko, this message translates to:
  /// **'약관에 동의해주세요'**
  String get agreeTermsRequired;

  /// No description provided for @signUpError.
  ///
  /// In ko, this message translates to:
  /// **'가입 중 오류가 발생했어요'**
  String get signUpError;

  /// No description provided for @signUpTitle.
  ///
  /// In ko, this message translates to:
  /// **'계정 만들기'**
  String get signUpTitle;

  /// No description provided for @signUpSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'몇 가지 정보만 입력하면 끝나요'**
  String get signUpSubtitle;

  /// No description provided for @nameLabel.
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get nameLabel;

  /// No description provided for @nameHint.
  ///
  /// In ko, this message translates to:
  /// **'닉네임 또는 이름'**
  String get nameHint;

  /// No description provided for @passwordHintMin6.
  ///
  /// In ko, this message translates to:
  /// **'6자 이상'**
  String get passwordHintMin6;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 확인'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In ko, this message translates to:
  /// **'한 번 더 입력해주세요'**
  String get confirmPasswordHint;

  /// No description provided for @signUpComplete.
  ///
  /// In ko, this message translates to:
  /// **'가입 완료'**
  String get signUpComplete;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In ko, this message translates to:
  /// **'이미 계정이 있으신가요?'**
  String get alreadyHaveAccount;

  /// No description provided for @termsAgreePrefix.
  ///
  /// In ko, this message translates to:
  /// **''**
  String get termsAgreePrefix;

  /// No description provided for @termsAgreeTermsLink.
  ///
  /// In ko, this message translates to:
  /// **'서비스 이용약관'**
  String get termsAgreeTermsLink;

  /// No description provided for @termsAgreeMiddle.
  ///
  /// In ko, this message translates to:
  /// **' 및 '**
  String get termsAgreeMiddle;

  /// No description provided for @termsAgreePrivacyLink.
  ///
  /// In ko, this message translates to:
  /// **'개인정보처리방침'**
  String get termsAgreePrivacyLink;

  /// No description provided for @termsAgreeSuffix.
  ///
  /// In ko, this message translates to:
  /// **'에 동의합니다'**
  String get termsAgreeSuffix;

  /// No description provided for @forgotPasswordDesc.
  ///
  /// In ko, this message translates to:
  /// **'가입하신 이메일을 입력하시면\n비밀번호 재설정 링크를 보내드려요.'**
  String get forgotPasswordDesc;

  /// No description provided for @sendResetEmail.
  ///
  /// In ko, this message translates to:
  /// **'재설정 메일 보내기'**
  String get sendResetEmail;

  /// No description provided for @resetEmailSentTitle.
  ///
  /// In ko, this message translates to:
  /// **'메일을 보냈어요'**
  String get resetEmailSentTitle;

  /// No description provided for @resetEmailSentDesc.
  ///
  /// In ko, this message translates to:
  /// **'받은편지함에서 재설정 메일을 확인해주세요.\n메일이 안 보이면 스팸함도 확인해보세요.'**
  String get resetEmailSentDesc;

  /// No description provided for @backToLogin.
  ///
  /// In ko, this message translates to:
  /// **'로그인 화면으로'**
  String get backToLogin;

  /// No description provided for @tryAnotherEmail.
  ///
  /// In ko, this message translates to:
  /// **'다른 이메일로 다시 시도'**
  String get tryAnotherEmail;

  /// No description provided for @authCancelled.
  ///
  /// In ko, this message translates to:
  /// **'취소되었어요'**
  String get authCancelled;

  /// No description provided for @authLoginRequired.
  ///
  /// In ko, this message translates to:
  /// **'로그인이 필요해요'**
  String get authLoginRequired;

  /// No description provided for @profileLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'프로필을 불러올 수 없어요'**
  String get profileLoadFailed;

  /// No description provided for @authReauthRequired.
  ///
  /// In ko, this message translates to:
  /// **'재로그인이 필요해요. 다시 로그인 후 탈퇴해주세요.'**
  String get authReauthRequired;

  /// No description provided for @authErrorDisabled.
  ///
  /// In ko, this message translates to:
  /// **'비활성화된 계정이에요'**
  String get authErrorDisabled;

  /// No description provided for @authErrorWrongCredentials.
  ///
  /// In ko, this message translates to:
  /// **'이메일 또는 비밀번호가 일치하지 않아요'**
  String get authErrorWrongCredentials;

  /// No description provided for @authErrorEmailInUse.
  ///
  /// In ko, this message translates to:
  /// **'이미 가입된 이메일이에요'**
  String get authErrorEmailInUse;

  /// No description provided for @authErrorNetwork.
  ///
  /// In ko, this message translates to:
  /// **'네트워크 연결을 확인해주세요'**
  String get authErrorNetwork;

  /// No description provided for @authErrorTooMany.
  ///
  /// In ko, this message translates to:
  /// **'너무 많은 시도가 있었어요. 잠시 후 다시 시도해주세요'**
  String get authErrorTooMany;

  /// No description provided for @authErrorGeneric.
  ///
  /// In ko, this message translates to:
  /// **'인증에 실패했어요 ({code})'**
  String authErrorGeneric(String code);

  /// No description provided for @permissionLater.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get permissionLater;

  /// No description provided for @permissionTitle.
  ///
  /// In ko, this message translates to:
  /// **'시작하기 전에\n권한을 확인해주세요'**
  String get permissionTitle;

  /// No description provided for @permissionIntro.
  ///
  /// In ko, this message translates to:
  /// **'Tracen이 여정을 기록하려면 다음 권한이 필요해요.\n나중에 언제든 설정에서 변경할 수 있어요.'**
  String get permissionIntro;

  /// No description provided for @permLocationTitle.
  ///
  /// In ko, this message translates to:
  /// **'위치 정보'**
  String get permLocationTitle;

  /// No description provided for @permLocationReason.
  ///
  /// In ko, this message translates to:
  /// **'GPS로 이동 경로를 지도에 그리고\n여정 거리를 계산해요'**
  String get permLocationReason;

  /// No description provided for @permCameraTitle.
  ///
  /// In ko, this message translates to:
  /// **'카메라'**
  String get permCameraTitle;

  /// No description provided for @permCameraReason.
  ///
  /// In ko, this message translates to:
  /// **'특별한 순간에 인증샷을\n바로 남길 수 있어요'**
  String get permCameraReason;

  /// No description provided for @permPhotosTitle.
  ///
  /// In ko, this message translates to:
  /// **'사진 라이브러리'**
  String get permPhotosTitle;

  /// No description provided for @permPhotosReason.
  ///
  /// In ko, this message translates to:
  /// **'저장된 사진을 핀에 첨부해서\n추억을 더 풍성하게 기록해요'**
  String get permPhotosReason;

  /// No description provided for @permAllowAll.
  ///
  /// In ko, this message translates to:
  /// **'모두 허용하기'**
  String get permAllowAll;

  /// No description provided for @permStatusGranted.
  ///
  /// In ko, this message translates to:
  /// **'허용됨'**
  String get permStatusGranted;

  /// No description provided for @permStatusNeeded.
  ///
  /// In ko, this message translates to:
  /// **'필요함'**
  String get permStatusNeeded;

  /// No description provided for @permStatusSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정 필요'**
  String get permStatusSettings;

  /// No description provided for @permStatusNotRequested.
  ///
  /// In ko, this message translates to:
  /// **'미요청'**
  String get permStatusNotRequested;

  /// No description provided for @permDeniedNotice.
  ///
  /// In ko, this message translates to:
  /// **'거부된 권한이 있어요. 설정에서 직접 켜주세요.'**
  String get permDeniedNotice;

  /// No description provided for @permOpenSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정으로 이동'**
  String get permOpenSettings;

  /// No description provided for @splashTagline.
  ///
  /// In ko, this message translates to:
  /// **'나의 여정을 기록하다'**
  String get splashTagline;

  /// No description provided for @pinAdded.
  ///
  /// In ko, this message translates to:
  /// **'핀이 추가되었어요 📍'**
  String get pinAdded;

  /// No description provided for @pinDeleted.
  ///
  /// In ko, this message translates to:
  /// **'핀을 삭제했어요'**
  String get pinDeleted;

  /// No description provided for @locationNotFound.
  ///
  /// In ko, this message translates to:
  /// **'위치를 찾을 수 없어요'**
  String get locationNotFound;

  /// No description provided for @navMap.
  ///
  /// In ko, this message translates to:
  /// **'지도'**
  String get navMap;

  /// No description provided for @navTimeline.
  ///
  /// In ko, this message translates to:
  /// **'타임라인'**
  String get navTimeline;

  /// No description provided for @navProfile.
  ///
  /// In ko, this message translates to:
  /// **'프로필'**
  String get navProfile;

  /// No description provided for @profileEdit.
  ///
  /// In ko, this message translates to:
  /// **'프로필 편집'**
  String get profileEdit;

  /// No description provided for @profileNoName.
  ///
  /// In ko, this message translates to:
  /// **'이름 없음'**
  String get profileNoName;

  /// No description provided for @statRuns.
  ///
  /// In ko, this message translates to:
  /// **'러닝'**
  String get statRuns;

  /// No description provided for @statDistance.
  ///
  /// In ko, this message translates to:
  /// **'총 거리'**
  String get statDistance;

  /// No description provided for @statPins.
  ///
  /// In ko, this message translates to:
  /// **'핀'**
  String get statPins;

  /// No description provided for @recentPhotos.
  ///
  /// In ko, this message translates to:
  /// **'최근 사진'**
  String get recentPhotos;

  /// No description provided for @seeAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 보기'**
  String get seeAll;

  /// No description provided for @noPhotosYet.
  ///
  /// In ko, this message translates to:
  /// **'아직 저장된 사진이 없어요'**
  String get noPhotosYet;

  /// No description provided for @saveError.
  ///
  /// In ko, this message translates to:
  /// **'저장 중 오류가 발생했어요'**
  String get saveError;

  /// No description provided for @changePhoto.
  ///
  /// In ko, this message translates to:
  /// **'사진 변경'**
  String get changePhoto;

  /// No description provided for @emailReadOnly.
  ///
  /// In ko, this message translates to:
  /// **'이메일은 변경할 수 없어요'**
  String get emailReadOnly;

  /// No description provided for @save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get save;

  /// No description provided for @takePhoto.
  ///
  /// In ko, this message translates to:
  /// **'카메라로 촬영'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In ko, this message translates to:
  /// **'갤러리에서 선택'**
  String get chooseFromGallery;

  /// No description provided for @commonOk.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get commonOk;

  /// No description provided for @commonDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get commonDelete;

  /// No description provided for @commonRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get commonRetry;

  /// No description provided for @runLocationPermissionNeeded.
  ///
  /// In ko, this message translates to:
  /// **'위치 권한이 필요합니다'**
  String get runLocationPermissionNeeded;

  /// No description provided for @runEndTitle.
  ///
  /// In ko, this message translates to:
  /// **'러닝을 종료할까요?'**
  String get runEndTitle;

  /// No description provided for @runEndBody.
  ///
  /// In ko, this message translates to:
  /// **'지금까지 {km} km 달렸어요.'**
  String runEndBody(String km);

  /// No description provided for @runContinue.
  ///
  /// In ko, this message translates to:
  /// **'계속'**
  String get runContinue;

  /// No description provided for @runEnd.
  ///
  /// In ko, this message translates to:
  /// **'종료'**
  String get runEnd;

  /// No description provided for @runStartTitle.
  ///
  /// In ko, this message translates to:
  /// **'러닝을 시작할까요?'**
  String get runStartTitle;

  /// No description provided for @runStartHint.
  ///
  /// In ko, this message translates to:
  /// **'GPS가 준비되면 기록이 시작돼요.\n스트레칭은 했나요? 🏃'**
  String get runStartHint;

  /// No description provided for @runStartButton.
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get runStartButton;

  /// No description provided for @runGpsConnecting.
  ///
  /// In ko, this message translates to:
  /// **'GPS 연결 중...'**
  String get runGpsConnecting;

  /// No description provided for @runDistance.
  ///
  /// In ko, this message translates to:
  /// **'거리'**
  String get runDistance;

  /// No description provided for @runTime.
  ///
  /// In ko, this message translates to:
  /// **'시간'**
  String get runTime;

  /// No description provided for @runPace.
  ///
  /// In ko, this message translates to:
  /// **'페이스'**
  String get runPace;

  /// No description provided for @runCalories.
  ///
  /// In ko, this message translates to:
  /// **'칼로리'**
  String get runCalories;

  /// No description provided for @runLongPressHint.
  ///
  /// In ko, this message translates to:
  /// **'지도를 길게 눌러 핀 추가'**
  String get runLongPressHint;

  /// No description provided for @runInfoNotFound.
  ///
  /// In ko, this message translates to:
  /// **'러닝 정보를 찾을 수 없어요'**
  String get runInfoNotFound;

  /// No description provided for @resultLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'결과를 불러올 수 없어요'**
  String get resultLoadFailed;

  /// No description provided for @runComplete.
  ///
  /// In ko, this message translates to:
  /// **'러닝 완료'**
  String get runComplete;

  /// No description provided for @runAvgPace.
  ///
  /// In ko, this message translates to:
  /// **'평균 페이스'**
  String get runAvgPace;

  /// No description provided for @unitCountSuffix.
  ///
  /// In ko, this message translates to:
  /// **'개'**
  String get unitCountSuffix;

  /// No description provided for @mapStart.
  ///
  /// In ko, this message translates to:
  /// **'시작'**
  String get mapStart;

  /// No description provided for @mapEnd.
  ///
  /// In ko, this message translates to:
  /// **'도착'**
  String get mapEnd;

  /// No description provided for @routeTooShort.
  ///
  /// In ko, this message translates to:
  /// **'경로가 너무 짧아서 표시할 수 없어요'**
  String get routeTooShort;

  /// No description provided for @deleteRunTitle.
  ///
  /// In ko, this message translates to:
  /// **'이 러닝을 삭제할까요?'**
  String get deleteRunTitle;

  /// No description provided for @deleteRunBody.
  ///
  /// In ko, this message translates to:
  /// **'경로와 핀도 함께 삭제되며, 되돌릴 수 없어요.'**
  String get deleteRunBody;

  /// No description provided for @runDeleted.
  ///
  /// In ko, this message translates to:
  /// **'러닝을 삭제했어요'**
  String get runDeleted;

  /// No description provided for @myRuns.
  ///
  /// In ko, this message translates to:
  /// **'나의 러닝'**
  String get myRuns;

  /// No description provided for @loadFailed.
  ///
  /// In ko, this message translates to:
  /// **'불러오기에 실패했어요'**
  String get loadFailed;

  /// No description provided for @runInProgress.
  ///
  /// In ko, this message translates to:
  /// **'진행 중'**
  String get runInProgress;

  /// No description provided for @durationHM.
  ///
  /// In ko, this message translates to:
  /// **'{h}시간 {m}분'**
  String durationHM(int h, int m);

  /// No description provided for @durationM.
  ///
  /// In ko, this message translates to:
  /// **'{m}분'**
  String durationM(int m);

  /// No description provided for @durationS.
  ///
  /// In ko, this message translates to:
  /// **'{s}초'**
  String durationS(int s);

  /// No description provided for @noRunsYet.
  ///
  /// In ko, this message translates to:
  /// **'아직 기록된 러닝이 없어요'**
  String get noRunsYet;

  /// No description provided for @noRunsHint.
  ///
  /// In ko, this message translates to:
  /// **'지도 화면의 보라색 러닝 버튼을 눌러\n첫 러닝을 시작해보세요.'**
  String get noRunsHint;

  /// No description provided for @invalidRoute.
  ///
  /// In ko, this message translates to:
  /// **'잘못된 여정입니다'**
  String get invalidRoute;

  /// No description provided for @routeLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'경로를 불러올 수 없어요'**
  String get routeLoadFailed;

  /// No description provided for @pinCountValue.
  ///
  /// In ko, this message translates to:
  /// **'{count}개'**
  String pinCountValue(int count);

  /// No description provided for @searchComingSoon.
  ///
  /// In ko, this message translates to:
  /// **'검색 기능은 곧 추가됩니다'**
  String get searchComingSoon;

  /// No description provided for @modePhoto.
  ///
  /// In ko, this message translates to:
  /// **'사진'**
  String get modePhoto;

  /// No description provided for @modeMemo.
  ///
  /// In ko, this message translates to:
  /// **'메모'**
  String get modeMemo;

  /// No description provided for @noMemosYet.
  ///
  /// In ko, this message translates to:
  /// **'아직 저장된 메모가 없어요'**
  String get noMemosYet;

  /// No description provided for @emptyPhotoHint.
  ///
  /// In ko, this message translates to:
  /// **'여정 중 인증샷을 남겨보세요\n지도를 길게 누르면 핀을 추가할 수 있어요'**
  String get emptyPhotoHint;

  /// No description provided for @emptyMemoHint.
  ///
  /// In ko, this message translates to:
  /// **'여정 중 떠오르는 생각을 메모해보세요\n지도를 길게 누르면 핀을 추가할 수 있어요'**
  String get emptyMemoHint;

  /// No description provided for @chipRestaurant.
  ///
  /// In ko, this message translates to:
  /// **'맛집'**
  String get chipRestaurant;

  /// No description provided for @chipCafe.
  ///
  /// In ko, this message translates to:
  /// **'카페'**
  String get chipCafe;

  /// No description provided for @chipPopup.
  ///
  /// In ko, this message translates to:
  /// **'팝업스토어'**
  String get chipPopup;

  /// No description provided for @chipBar.
  ///
  /// In ko, this message translates to:
  /// **'술집'**
  String get chipBar;

  /// No description provided for @chipPark.
  ///
  /// In ko, this message translates to:
  /// **'공원'**
  String get chipPark;

  /// No description provided for @chipShopping.
  ///
  /// In ko, this message translates to:
  /// **'쇼핑'**
  String get chipShopping;

  /// No description provided for @chipCulture.
  ///
  /// In ko, this message translates to:
  /// **'문화'**
  String get chipCulture;

  /// No description provided for @chipConvenience.
  ///
  /// In ko, this message translates to:
  /// **'편의점'**
  String get chipConvenience;

  /// No description provided for @sugHip.
  ///
  /// In ko, this message translates to:
  /// **'힙한 분위기'**
  String get sugHip;

  /// No description provided for @sugQuiet.
  ///
  /// In ko, this message translates to:
  /// **'조용한 곳'**
  String get sugQuiet;

  /// No description provided for @sugInsta.
  ///
  /// In ko, this message translates to:
  /// **'인스타 감성'**
  String get sugInsta;

  /// No description provided for @sugSpacious.
  ///
  /// In ko, this message translates to:
  /// **'넓은 곳'**
  String get sugSpacious;

  /// No description provided for @sugView.
  ///
  /// In ko, this message translates to:
  /// **'뷰 좋은 곳'**
  String get sugView;

  /// No description provided for @sugValue.
  ///
  /// In ko, this message translates to:
  /// **'가성비'**
  String get sugValue;

  /// No description provided for @sugTerrace.
  ///
  /// In ko, this message translates to:
  /// **'야외 테라스'**
  String get sugTerrace;

  /// No description provided for @sug24h.
  ///
  /// In ko, this message translates to:
  /// **'24시간'**
  String get sug24h;

  /// No description provided for @placeCheckLocationPermission.
  ///
  /// In ko, this message translates to:
  /// **'위치 권한을 확인해주세요.'**
  String get placeCheckLocationPermission;

  /// No description provided for @placeLocating.
  ///
  /// In ko, this message translates to:
  /// **'위치를 가져오는 중이에요.'**
  String get placeLocating;

  /// No description provided for @placeNeedInput.
  ///
  /// In ko, this message translates to:
  /// **'카테고리나 원하는 것을 입력해주세요.'**
  String get placeNeedInput;

  /// No description provided for @placeTitle.
  ///
  /// In ko, this message translates to:
  /// **'AI 장소 추천'**
  String get placeTitle;

  /// No description provided for @placeHeroTitle.
  ///
  /// In ko, this message translates to:
  /// **'지금 여기서 어디 갈까요?'**
  String get placeHeroTitle;

  /// No description provided for @placeHeroDesc.
  ///
  /// In ko, this message translates to:
  /// **'원하는 걸 자유롭게 말해주세요\nAI가 주변 최적 장소를 찾아드려요'**
  String get placeHeroDesc;

  /// No description provided for @placeParty.
  ///
  /// In ko, this message translates to:
  /// **'인원'**
  String get placeParty;

  /// No description provided for @placeWhere.
  ///
  /// In ko, this message translates to:
  /// **'어디 가고 싶어요?'**
  String get placeWhere;

  /// No description provided for @placeBeSpecific.
  ///
  /// In ko, this message translates to:
  /// **'더 구체적으로 말해줘요'**
  String get placeBeSpecific;

  /// No description provided for @placeInputHint.
  ///
  /// In ko, this message translates to:
  /// **'예) 친구 3명이랑 힙한 분위기 카페 가고 싶어\n예) 데이트하기 좋은 조용한 맛집'**
  String get placeInputHint;

  /// No description provided for @placeLocatingShort.
  ///
  /// In ko, this message translates to:
  /// **'위치 가져오는 중...'**
  String get placeLocatingShort;

  /// No description provided for @placeRadius.
  ///
  /// In ko, this message translates to:
  /// **'현재 위치 기준 2km 반경'**
  String get placeRadius;

  /// No description provided for @placeLocationUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'위치를 가져올 수 없어요'**
  String get placeLocationUnavailable;

  /// No description provided for @placeRefresh.
  ///
  /// In ko, this message translates to:
  /// **'새로고침'**
  String get placeRefresh;

  /// No description provided for @placeSearching.
  ///
  /// In ko, this message translates to:
  /// **'AI가 장소 찾는 중...'**
  String get placeSearching;

  /// No description provided for @placeGetRecs.
  ///
  /// In ko, this message translates to:
  /// **'장소 추천 받기'**
  String get placeGetRecs;

  /// No description provided for @placeGetRecsWith.
  ///
  /// In ko, this message translates to:
  /// **'{people}명 · {chips} 추천 받기'**
  String placeGetRecsWith(int people, String chips);

  /// No description provided for @peopleCount.
  ///
  /// In ko, this message translates to:
  /// **'{value}명'**
  String peopleCount(int value);

  /// No description provided for @currentLocation.
  ///
  /// In ko, this message translates to:
  /// **'현재 위치'**
  String get currentLocation;

  /// No description provided for @placesRecommended.
  ///
  /// In ko, this message translates to:
  /// **'{count}곳 추천드려요'**
  String placesRecommended(int count);

  /// No description provided for @placesCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}곳'**
  String placesCount(int count);

  /// No description provided for @pinDeleteTooltip.
  ///
  /// In ko, this message translates to:
  /// **'핀 삭제'**
  String get pinDeleteTooltip;

  /// No description provided for @pinEmpty.
  ///
  /// In ko, this message translates to:
  /// **'내용이 없는 핀이에요.'**
  String get pinEmpty;

  /// No description provided for @photoSavedToGallery.
  ///
  /// In ko, this message translates to:
  /// **'사진이 갤러리에 저장됐어요 📷'**
  String get photoSavedToGallery;

  /// No description provided for @saveFailedWith.
  ///
  /// In ko, this message translates to:
  /// **'저장 실패: {error}'**
  String saveFailedWith(String error);

  /// No description provided for @tapToClose.
  ///
  /// In ko, this message translates to:
  /// **'탭하면 닫혀요'**
  String get tapToClose;

  /// No description provided for @catGeneral.
  ///
  /// In ko, this message translates to:
  /// **'일반'**
  String get catGeneral;

  /// No description provided for @catFood.
  ///
  /// In ko, this message translates to:
  /// **'음식'**
  String get catFood;

  /// No description provided for @catScenery.
  ///
  /// In ko, this message translates to:
  /// **'명소'**
  String get catScenery;

  /// No description provided for @catCafe.
  ///
  /// In ko, this message translates to:
  /// **'카페'**
  String get catCafe;

  /// No description provided for @catWorkout.
  ///
  /// In ko, this message translates to:
  /// **'운동'**
  String get catWorkout;

  /// No description provided for @catMemo.
  ///
  /// In ko, this message translates to:
  /// **'메모'**
  String get catMemo;

  /// No description provided for @addPin.
  ///
  /// In ko, this message translates to:
  /// **'핀 추가'**
  String get addPin;

  /// No description provided for @pickerTapMapHint.
  ///
  /// In ko, this message translates to:
  /// **'지도를 탭해서 위치를 옮길 수 있어요'**
  String get pickerTapMapHint;

  /// No description provided for @today.
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get today;

  /// No description provided for @resetColorsTitle.
  ///
  /// In ko, this message translates to:
  /// **'커스터마이즈 초기화'**
  String get resetColorsTitle;

  /// No description provided for @resetColorsBody.
  ///
  /// In ko, this message translates to:
  /// **'모든 카테고리의 색상/아이콘/이름을 기본값으로 되돌릴까요?'**
  String get resetColorsBody;

  /// No description provided for @reset.
  ///
  /// In ko, this message translates to:
  /// **'초기화'**
  String get reset;

  /// No description provided for @categoryColors.
  ///
  /// In ko, this message translates to:
  /// **'카테고리 커스터마이즈'**
  String get categoryColors;

  /// No description provided for @colorDefault.
  ///
  /// In ko, this message translates to:
  /// **'기본'**
  String get colorDefault;

  /// No description provided for @categoryColorTitle.
  ///
  /// In ko, this message translates to:
  /// **'{category} 커스터마이즈'**
  String categoryColorTitle(String category);

  /// No description provided for @presetColors.
  ///
  /// In ko, this message translates to:
  /// **'프리셋 색상'**
  String get presetColors;

  /// No description provided for @categoryNameLabel.
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get categoryNameLabel;

  /// No description provided for @categoryNameHint.
  ///
  /// In ko, this message translates to:
  /// **'카테고리 이름'**
  String get categoryNameHint;

  /// No description provided for @categoryIconLabel.
  ///
  /// In ko, this message translates to:
  /// **'아이콘'**
  String get categoryIconLabel;

  /// No description provided for @apply.
  ///
  /// In ko, this message translates to:
  /// **'적용'**
  String get apply;

  /// No description provided for @addMemoOrPhoto.
  ///
  /// In ko, this message translates to:
  /// **'메모나 사진을 하나 이상 추가해주세요'**
  String get addMemoOrPhoto;

  /// No description provided for @categoryLabel.
  ///
  /// In ko, this message translates to:
  /// **'카테고리'**
  String get categoryLabel;

  /// No description provided for @categoryCustomize.
  ///
  /// In ko, this message translates to:
  /// **'커스터마이즈'**
  String get categoryCustomize;

  /// No description provided for @memoLabel.
  ///
  /// In ko, this message translates to:
  /// **'메모'**
  String get memoLabel;

  /// No description provided for @photoLabel.
  ///
  /// In ko, this message translates to:
  /// **'사진'**
  String get photoLabel;

  /// No description provided for @memoHint.
  ///
  /// In ko, this message translates to:
  /// **'오늘의 한 줄을 적어보세요...'**
  String get memoHint;

  /// No description provided for @gallery.
  ///
  /// In ko, this message translates to:
  /// **'갤러리'**
  String get gallery;

  /// No description provided for @anotherPhoto.
  ///
  /// In ko, this message translates to:
  /// **'다른 사진'**
  String get anotherPhoto;

  /// No description provided for @retakePhoto.
  ///
  /// In ko, this message translates to:
  /// **'다시 촬영'**
  String get retakePhoto;

  /// No description provided for @journey.
  ///
  /// In ko, this message translates to:
  /// **'여정'**
  String get journey;

  /// No description provided for @routeDefaultTitle.
  ///
  /// In ko, this message translates to:
  /// **'{date} 여정'**
  String routeDefaultTitle(String date);

  /// No description provided for @recoveredRecord.
  ///
  /// In ko, this message translates to:
  /// **'이전 기록 (자동 복구)'**
  String get recoveredRecord;

  /// No description provided for @placeErrNoGeminiKey.
  ///
  /// In ko, this message translates to:
  /// **'AI 기능을 쓰려면 .env에 GEMINI_API_KEY가 필요해요.\naistudio.google.com 에서 무료로 발급받을 수 있어요.'**
  String get placeErrNoGeminiKey;

  /// No description provided for @placeErrNotEnough.
  ///
  /// In ko, this message translates to:
  /// **'주변에 추천할 장소가 충분하지 않아요. (검색된 후보: {count}개)\nPlaces API 활성화 / 결제 계정 / 위치를 확인해주세요.'**
  String placeErrNotEnough(int count);

  /// No description provided for @placeErrNoMapsKey.
  ///
  /// In ko, this message translates to:
  /// **'Google Maps API 키가 없어요. (.env 확인)'**
  String get placeErrNoMapsKey;

  /// No description provided for @placeErrDenied.
  ///
  /// In ko, this message translates to:
  /// **'Places API가 거부됐어요.\nGoogle Cloud에서 \"Places API\"를 활성화하고, API 키 제한에 Places를 추가했는지 확인해주세요.'**
  String get placeErrDenied;

  /// No description provided for @placeErrQuota.
  ///
  /// In ko, this message translates to:
  /// **'API 사용 한도를 초과했어요. 결제 계정을 확인해주세요.'**
  String get placeErrQuota;

  /// No description provided for @placeErrBadRequest.
  ///
  /// In ko, this message translates to:
  /// **'검색 요청이 잘못됐어요. 위치 정보를 확인해주세요.'**
  String get placeErrBadRequest;

  /// No description provided for @placeErrSearchFailed.
  ///
  /// In ko, this message translates to:
  /// **'장소 검색 실패: {status}'**
  String placeErrSearchFailed(String status);

  /// No description provided for @aiErrNetwork.
  ///
  /// In ko, this message translates to:
  /// **'AI 호출 중 네트워크 오류가 났어요: {error}'**
  String aiErrNetwork(String error);

  /// No description provided for @aiErrResponse.
  ///
  /// In ko, this message translates to:
  /// **'AI 응답 오류 ({code})\n{body}'**
  String aiErrResponse(int code, String body);

  /// No description provided for @aiErrNoContent.
  ///
  /// In ko, this message translates to:
  /// **'Gemini 응답에서 내용을 찾지 못했어요.'**
  String get aiErrNoContent;

  /// No description provided for @aiErrBadStructure.
  ///
  /// In ko, this message translates to:
  /// **'Gemini 응답 구조가 올바르지 않아요.'**
  String get aiErrBadStructure;

  /// No description provided for @aiErrUnparsable.
  ///
  /// In ko, this message translates to:
  /// **'AI 응답을 이해하지 못했어요. 다시 시도해주세요.\n응답: {raw}'**
  String aiErrUnparsable(String raw);

  /// No description provided for @aiErrBadFormat.
  ///
  /// In ko, this message translates to:
  /// **'AI 응답 형식이 올바르지 않아요. 다시 시도해주세요.'**
  String get aiErrBadFormat;

  /// No description provided for @aiErrNoPick.
  ///
  /// In ko, this message translates to:
  /// **'AI가 장소를 고르지 못했어요. 다시 시도해주세요.'**
  String get aiErrNoPick;

  /// No description provided for @aiErrTooFewValid.
  ///
  /// In ko, this message translates to:
  /// **'유효한 장소가 부족해요. 다시 시도해주세요.'**
  String get aiErrTooFewValid;

  /// No description provided for @aiDefaultReason.
  ///
  /// In ko, this message translates to:
  /// **'추천 장소예요.'**
  String get aiDefaultReason;

  /// No description provided for @trackingChannelName.
  ///
  /// In ko, this message translates to:
  /// **'Tracen 위치 추적'**
  String get trackingChannelName;

  /// No description provided for @trackingChannelDesc.
  ///
  /// In ko, this message translates to:
  /// **'백그라운드에서 경로를 기록하고 있습니다.'**
  String get trackingChannelDesc;

  /// No description provided for @trackingNotifTitle.
  ///
  /// In ko, this message translates to:
  /// **'Tracen 경로 기록 중'**
  String get trackingNotifTitle;

  /// No description provided for @trackingNotifText.
  ///
  /// In ko, this message translates to:
  /// **'백그라운드에서 위치를 추적하고 있습니다.'**
  String get trackingNotifText;

  /// No description provided for @locationServiceOff.
  ///
  /// In ko, this message translates to:
  /// **'위치 서비스가 꺼져 있습니다. 디바이스 설정에서 켜주세요.'**
  String get locationServiceOff;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In ko, this message translates to:
  /// **'위치 권한이 거부되었습니다.'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionDeniedForever.
  ///
  /// In ko, this message translates to:
  /// **'위치 권한이 영구 거부되었습니다. 앱 설정에서 허용해주세요.'**
  String get locationPermissionDeniedForever;

  /// No description provided for @activityRunning.
  ///
  /// In ko, this message translates to:
  /// **'러닝'**
  String get activityRunning;

  /// No description provided for @activityWalking.
  ///
  /// In ko, this message translates to:
  /// **'걷기'**
  String get activityWalking;

  /// No description provided for @activityCycling.
  ///
  /// In ko, this message translates to:
  /// **'자전거'**
  String get activityCycling;

  /// No description provided for @metricSpeed.
  ///
  /// In ko, this message translates to:
  /// **'속도'**
  String get metricSpeed;

  /// No description provided for @metricAvgSpeed.
  ///
  /// In ko, this message translates to:
  /// **'평균 속도'**
  String get metricAvgSpeed;

  /// No description provided for @metricMaxSpeed.
  ///
  /// In ko, this message translates to:
  /// **'최고 속도'**
  String get metricMaxSpeed;

  /// No description provided for @metricAltitude.
  ///
  /// In ko, this message translates to:
  /// **'고도'**
  String get metricAltitude;

  /// No description provided for @metricSteps.
  ///
  /// In ko, this message translates to:
  /// **'걸음 수'**
  String get metricSteps;

  /// No description provided for @trackingPause.
  ///
  /// In ko, this message translates to:
  /// **'일시정지'**
  String get trackingPause;

  /// No description provided for @trackingResume.
  ///
  /// In ko, this message translates to:
  /// **'재개'**
  String get trackingResume;

  /// No description provided for @trackingHoldToStop.
  ///
  /// In ko, this message translates to:
  /// **'길게 눌러서 종료'**
  String get trackingHoldToStop;

  /// No description provided for @trackingBackToCurrentLocation.
  ///
  /// In ko, this message translates to:
  /// **'현재 위치로'**
  String get trackingBackToCurrentLocation;

  /// No description provided for @trackingLocatingGps.
  ///
  /// In ko, this message translates to:
  /// **'위치를 찾는 중…'**
  String get trackingLocatingGps;

  /// No description provided for @trackingPreciseLocationOff.
  ///
  /// In ko, this message translates to:
  /// **'정확한 위치가 꺼져 있어 기록이 부정확할 수 있어요.'**
  String get trackingPreciseLocationOff;

  /// No description provided for @trackingPreciseLocationTurnOn.
  ///
  /// In ko, this message translates to:
  /// **'켜기'**
  String get trackingPreciseLocationTurnOn;
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
