// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get Started';

  @override
  String get onboarding1Title => 'Trace your own path\non the map';

  @override
  String get onboarding1Desc =>
      'Walks, runs, travel — go anywhere\nwith AA by your side.';

  @override
  String get onboarding2Title => 'Capture special\nmoments';

  @override
  String get onboarding2Desc => 'Leave a photo and a note\nwherever you go.';

  @override
  String get onboarding3Title => 'Pick up right where\nyou left off';

  @override
  String get onboarding3Desc =>
      'Safely stored in the cloud,\nready whenever you are.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get darkModeTitle => 'Dark Mode';

  @override
  String get darkModeSubtitle => 'Switch to a darker background';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get languageTitle => 'App Language';

  @override
  String get languageSubtitle => 'Choose your display language';

  @override
  String get languageSystemDefault => 'Use device language';

  @override
  String get sectionTracking => 'Tracking';

  @override
  String get autoTrackingTitle => 'Auto Path Tracking';

  @override
  String get autoTrackingSubtitle =>
      'Record your path on the map while the app is running';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get locationNotifTitle => 'Location Tracking Alerts';

  @override
  String get locationNotifSubtitle =>
      'Get notified while your route is being recorded';

  @override
  String get memoNotifTitle => 'Note Saved Alerts';

  @override
  String get memoNotifSubtitle => 'Get notified when a note is saved';

  @override
  String get runningNotifTitle => 'Running Alerts';

  @override
  String get runningNotifSubtitle => 'Get notified when a run is completed';

  @override
  String get sectionAccount => 'Account';

  @override
  String get resetPasswordTitle => 'Reset Password';

  @override
  String get resetPasswordSubtitle => 'We\'ll send a reset link to your email';

  @override
  String get noEmail => 'No email';

  @override
  String get loggedInAccount => 'Signed-in account';

  @override
  String get sectionAppInfo => 'About';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get versionLabel => 'Version';

  @override
  String get signOut => 'Sign Out';

  @override
  String get deleteAccountAction => 'Delete Account';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmMessage =>
      'You\'ll need to sign in again to access your trip history.';

  @override
  String get deleteAccountConfirmTitle => 'Delete your account?';

  @override
  String get deleteAccountConfirmMessage =>
      'All account data will be permanently deleted\nand cannot be recovered.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmDeleteAccount => 'Delete';

  @override
  String get errorDeleteAccount =>
      'Something went wrong while deleting your account';

  @override
  String errorOpenUrl(String label) {
    return 'Couldn\'t open $label';
  }
}
