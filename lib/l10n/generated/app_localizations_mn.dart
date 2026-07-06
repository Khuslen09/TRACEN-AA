// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Mongolian (`mn`).
class AppLocalizationsMn extends AppLocalizations {
  AppLocalizationsMn([String locale = 'mn']) : super(locale);

  @override
  String get onboardingSkip => 'Алгасах';

  @override
  String get onboardingNext => 'Дараах';

  @override
  String get onboardingStart => 'Эхлүүлэх';

  @override
  String get onboarding1Title =>
      'Өөрийн замнасан замаа\nгазрын зураг дээр үлдээ';

  @override
  String get onboarding1Desc =>
      'Алхалт, гүйлт, аялал — хаана ч байсан\nAA-тай хамт алхаарай.';

  @override
  String get onboarding2Title => 'Онцгой мөчүүдээ\nтэмдэглэ';

  @override
  String get onboarding2Desc =>
      'Хүрсэн газартаа зураг, тэмдэглэл\nхадгалаарай.';

  @override
  String get onboarding3Title => 'Хаанаас ч дахин\nнээж үзээрэй';

  @override
  String get onboarding3Desc =>
      'Аюулгүй хадгалагдсан тул\nхэдийд ч дахин үзэх боломжтой.';

  @override
  String get settingsTitle => 'Тохиргоо';

  @override
  String get sectionAppearance => 'Гадаад төрх';

  @override
  String get darkModeTitle => 'Харанхуй горим';

  @override
  String get darkModeSubtitle => 'Хар дэвсгэр рүү шилжинэ';

  @override
  String get sectionLanguage => 'Хэл';

  @override
  String get languageTitle => 'Аппын хэл';

  @override
  String get languageSubtitle => 'Харагдах хэлээ сонгоно уу';

  @override
  String get languageSystemDefault => 'Төхөөрөмжийн хэлийг ашиглах';

  @override
  String get sectionTracking => 'Замнал бүртгэл';

  @override
  String get autoTrackingTitle => 'Автомат замнал бүртгэл';

  @override
  String get autoTrackingSubtitle =>
      'Апп ажиллаж байх хугацаанд явсан замыг газрын зураг дээр бүртгэнэ';

  @override
  String get sectionNotifications => 'Мэдэгдэл';

  @override
  String get locationNotifTitle => 'Байршил бүртгэлийн мэдэгдэл';

  @override
  String get locationNotifSubtitle => 'Зам бүртгэгдэж байх үед мэдэгдэл авна';

  @override
  String get memoNotifTitle => 'Тэмдэглэл хадгалсан мэдэгдэл';

  @override
  String get memoNotifSubtitle => 'Тэмдэглэл хадгалагдсан үед мэдэгдэнэ';

  @override
  String get runningNotifTitle => 'Гүйлтийн мэдэгдэл';

  @override
  String get runningNotifSubtitle => 'Гүйлт дууссаны дараа үр дүнг мэдэгдэнэ';

  @override
  String get sectionAccount => 'Бүртгэл';

  @override
  String get resetPasswordTitle => 'Нууц үг сэргээх';

  @override
  String get resetPasswordSubtitle => 'Сэргээх холбоосыг имэйлээр илгээнэ';

  @override
  String get noEmail => 'Имэйл алга';

  @override
  String get loggedInAccount => 'Нэвтэрсэн бүртгэл';

  @override
  String get sectionAppInfo => 'Аппын мэдээлэл';

  @override
  String get privacyPolicy => 'Нууцлалын бодлого';

  @override
  String get termsOfService => 'Үйлчилгээний нөхцөл';

  @override
  String get versionLabel => 'Хувилбар';

  @override
  String get signOut => 'Гарах';

  @override
  String get deleteAccountAction => 'Бүртгэл устгах';

  @override
  String get signOutConfirmTitle => 'Гарах уу?';

  @override
  String get signOutConfirmMessage =>
      'Замналын түүхээ ашиглахын тулд дахин нэвтрэх шаардлагатай болно.';

  @override
  String get deleteAccountConfirmTitle => 'Бүртгэлээ үнэхээр устгах уу?';

  @override
  String get deleteAccountConfirmMessage =>
      'Бүртгэлтэй холбоотой бүх мэдээлэл устах бөгөөд\nсэргээх боломжгүй.';

  @override
  String get cancel => 'Цуцлах';

  @override
  String get confirmDeleteAccount => 'Устгах';

  @override
  String get errorDeleteAccount => 'Бүртгэл устгах явцад алдаа гарлаа';

  @override
  String errorOpenUrl(String label) {
    return '$label хуудсыг нээж чадсангүй';
  }
}
