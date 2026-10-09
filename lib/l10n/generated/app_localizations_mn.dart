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
      'Алхалт, гүйлт, аялал — хаана ч байсан\nTracen-тэй хамт алхаарай.';

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

  @override
  String get commonEmail => 'И-мэйл';

  @override
  String get commonPassword => 'Нууц үг';

  @override
  String get commonOr => 'эсвэл';

  @override
  String get commonLogin => 'Нэвтрэх';

  @override
  String get loginEnterCredentials => 'И-мэйл болон нууц үгээ оруулна уу';

  @override
  String get loginError => 'Нэвтрэх үед алдаа гарлаа';

  @override
  String get googleLoginFailed => 'Google-ээр нэвтрэх амжилтгүй боллоо';

  @override
  String get loginWelcome => 'Тавтай морил';

  @override
  String get loginSubtitle => 'Өнөөдрийн аяллаа тэмдэглэх үү?';

  @override
  String get passwordHint => 'Нууц үгээ оруулна уу';

  @override
  String get forgotPasswordLink => 'Нууц үгээ мартсан уу?';

  @override
  String get continueWithGoogle => 'Google-ээр үргэлжлүүлэх';

  @override
  String get continueWithAppleSoon => 'Apple-ээр үргэлжлүүлэх (тун удахгүй)';

  @override
  String get noAccountYet => 'Бүртгэл байхгүй юу?';

  @override
  String get signUpAction => 'Бүртгүүлэх';

  @override
  String get nameRequired => 'Нэрээ оруулна уу';

  @override
  String get nameTooShort => 'Нэр хамгийн багадаа 2 тэмдэгттэй байх ёстой';

  @override
  String get emailRequired => 'И-мэйлээ оруулна уу';

  @override
  String get emailInvalid => 'И-мэйл хаягийн формат буруу байна';

  @override
  String get passwordRequired => 'Нууц үгээ оруулна уу';

  @override
  String get passwordTooShort =>
      'Нууц үг хамгийн багадаа 6 тэмдэгттэй байх ёстой';

  @override
  String get passwordMismatch => 'Нууц үг таарахгүй байна';

  @override
  String get agreeTermsRequired => 'Үйлчилгээний нөхцөлтэй зөвшөөрнө үү';

  @override
  String get signUpError => 'Бүртгүүлэх үед алдаа гарлаа';

  @override
  String get signUpTitle => 'Бүртгэл үүсгэх';

  @override
  String get signUpSubtitle => 'Хэдхэн мэдээлэл оруулахад л болно';

  @override
  String get nameLabel => 'Нэр';

  @override
  String get nameHint => 'Хоч эсвэл нэр';

  @override
  String get passwordHintMin6 => 'Хамгийн багадаа 6 тэмдэгт';

  @override
  String get confirmPasswordLabel => 'Нууц үг давтах';

  @override
  String get confirmPasswordHint => 'Дахин оруулна уу';

  @override
  String get signUpComplete => 'Бүртгэл үүсгэх';

  @override
  String get alreadyHaveAccount => 'Бүртгэлтэй юу?';

  @override
  String get termsAgreePrefix => '';

  @override
  String get termsAgreeTermsLink => 'Үйлчилгээний нөхцөл';

  @override
  String get termsAgreeMiddle => ' болон ';

  @override
  String get termsAgreePrivacyLink => 'Нууцлалын бодлогыг';

  @override
  String get termsAgreeSuffix => ' зөвшөөрч байна';

  @override
  String get forgotPasswordDesc =>
      'Бүртгүүлсэн и-мэйл хаягаа оруулбал\nнууц үг сэргээх холбоос илгээнэ.';

  @override
  String get sendResetEmail => 'Сэргээх и-мэйл илгээх';

  @override
  String get resetEmailSentTitle => 'И-мэйл илгээлээ';

  @override
  String get resetEmailSentDesc =>
      'Ирсэн захидлын хайрцгаасаа сэргээх и-мэйлийг шалгана уу.\nОлдохгүй бол спам хавтсаа шалгаарай.';

  @override
  String get backToLogin => 'Нэвтрэх хуудас руу буцах';

  @override
  String get tryAnotherEmail => 'Өөр и-мэйлээр дахин оролдох';

  @override
  String get authCancelled => 'Цуцлагдлаа';

  @override
  String get authLoginRequired => 'Эхлээд нэвтрэх шаардлагатай';

  @override
  String get profileLoadFailed => 'Профайлыг ачаалж чадсангүй';

  @override
  String get authReauthRequired =>
      'Дахин нэвтэрсний дараа бүртгэлээ устгана уу.';

  @override
  String get authErrorDisabled => 'Энэ бүртгэл идэвхгүй болсон байна';

  @override
  String get authErrorWrongCredentials => 'И-мэйл эсвэл нууц үг буруу байна';

  @override
  String get authErrorEmailInUse => 'Энэ и-мэйл аль хэдийн бүртгэгдсэн байна';

  @override
  String get authErrorNetwork => 'Сүлжээний холболтоо шалгана уу';

  @override
  String get authErrorTooMany =>
      'Хэт олон удаа оролдлоо. Түр хүлээгээд дахин оролдоно уу';

  @override
  String authErrorGeneric(String code) {
    return 'Баталгаажуулалт амжилтгүй боллоо ($code)';
  }

  @override
  String get permissionLater => 'Дараа нь';

  @override
  String get permissionTitle => 'Эхлэхийн өмнө\nзөвшөөрлөө шалгаарай';

  @override
  String get permissionIntro =>
      'Tracen таны аяллыг тэмдэглэхэд дараах зөвшөөрлүүд хэрэгтэй.\nДараа нь тохиргооноос хэзээ ч өөрчилж болно.';

  @override
  String get permLocationTitle => 'Байршил';

  @override
  String get permLocationReason =>
      'GPS-ээр таны замыг газрын зураг дээр зурж,\nаяллын зайг тооцоолно';

  @override
  String get permCameraTitle => 'Камер';

  @override
  String get permCameraReason => 'Онцгой мөчид\nшууд зураг авч болно';

  @override
  String get permPhotosTitle => 'Зургийн сан';

  @override
  String get permPhotosReason =>
      'Хадгалсан зургаа тэмдэгтэй холбож\nсанамжаа баяжуулаарай';

  @override
  String get permAllowAll => 'Бүгдийг зөвшөөрөх';

  @override
  String get permStatusGranted => 'Зөвшөөрсөн';

  @override
  String get permStatusNeeded => 'Шаардлагатай';

  @override
  String get permStatusSettings => 'Тохиргоо хэрэгтэй';

  @override
  String get permStatusNotRequested => 'Хараахан хүсээгүй';

  @override
  String get permDeniedNotice =>
      'Зарим зөвшөөрлийг татгалзсан байна. Тохиргооноос өөрөө асаана уу.';

  @override
  String get permOpenSettings => 'Тохиргоо руу очих';

  @override
  String get splashTagline => 'Аяллаа тэмдэглээрэй';

  @override
  String get pinAdded => 'Тэмдэг нэмэгдлээ 📍';

  @override
  String get pinDeleted => 'Тэмдгийг устгалаа';

  @override
  String get locationNotFound => 'Байршлыг олж чадсангүй';

  @override
  String get navMap => 'Газрын зураг';

  @override
  String get navTimeline => 'Түүх';

  @override
  String get navProfile => 'Профайл';

  @override
  String get profileEdit => 'Профайл засах';

  @override
  String get profileNoName => 'Нэргүй';

  @override
  String get statRuns => 'Гүйлт';

  @override
  String get statDistance => 'Нийт зай';

  @override
  String get statPins => 'Тэмдэг';

  @override
  String get recentPhotos => 'Сүүлийн зургууд';

  @override
  String get seeAll => 'Бүгдийг харах';

  @override
  String get noPhotosYet => 'Хадгалсан зураг хараахан алга';

  @override
  String get saveError => 'Хадгалах үед алдаа гарлаа';

  @override
  String get changePhoto => 'Зураг солих';

  @override
  String get emailReadOnly => 'И-мэйлийг өөрчлөх боломжгүй';

  @override
  String get save => 'Хадгалах';

  @override
  String get takePhoto => 'Камераар зураг авах';

  @override
  String get chooseFromGallery => 'Галлерейгаас сонгох';

  @override
  String get commonOk => 'За';

  @override
  String get commonDelete => 'Устгах';

  @override
  String get commonRetry => 'Дахин оролдох';

  @override
  String get runLocationPermissionNeeded => 'Байршлын зөвшөөрөл шаардлагатай';

  @override
  String get runEndTitle => 'Гүйлтээ дуусгах уу?';

  @override
  String runEndBody(String km) {
    return 'Одоогоор $km км гүйлээ.';
  }

  @override
  String get runContinue => 'Үргэлжлүүлэх';

  @override
  String get runEnd => 'Дуусгах';

  @override
  String get runStartTitle => 'Гүйлт эхлүүлэх үү?';

  @override
  String get runStartHint =>
      'GPS бэлэн болмогц бүртгэл эхэлнэ.\nДасгал сунгалт хийсэн үү? 🏃';

  @override
  String get runStartButton => 'Эхлэх';

  @override
  String get runGpsConnecting => 'GPS холбогдож байна...';

  @override
  String get runDistance => 'Зай';

  @override
  String get runTime => 'Хугацаа';

  @override
  String get runPace => 'Темп';

  @override
  String get runCalories => 'Калори';

  @override
  String get runLongPressHint =>
      'Тэмдэг нэмэхийн тулд газрын зургийг удаан дар';

  @override
  String get runInfoNotFound => 'Гүйлтийн мэдээлэл олдсонгүй';

  @override
  String get resultLoadFailed => 'Үр дүнг ачаалж чадсангүй';

  @override
  String get runComplete => 'Гүйлт дууслаа';

  @override
  String get runAvgPace => 'Дундаж темп';

  @override
  String get unitCountSuffix => '';

  @override
  String get mapStart => 'Эхлэл';

  @override
  String get mapEnd => 'Төгсгөл';

  @override
  String get routeTooShort => 'Маршрут хэт богино тул харуулах боломжгүй';

  @override
  String get deleteRunTitle => 'Энэ гүйлтийг устгах уу?';

  @override
  String get deleteRunBody =>
      'Маршрут болон тэмдгүүд хамт устах бөгөөд сэргээх боломжгүй.';

  @override
  String get runDeleted => 'Гүйлтийг устгалаа';

  @override
  String get myRuns => 'Миний гүйлтүүд';

  @override
  String get loadFailed => 'Ачаалж чадсангүй';

  @override
  String get runInProgress => 'Явагдаж байна';

  @override
  String durationHM(int h, int m) {
    return '$h цаг $m мин';
  }

  @override
  String durationM(int m) {
    return '$m мин';
  }

  @override
  String durationS(int s) {
    return '$s сек';
  }

  @override
  String get noRunsYet => 'Бүртгэгдсэн гүйлт хараахан алга';

  @override
  String get noRunsHint =>
      'Газрын зураг дээрх нил ягаан гүйлтийн товчийг дарж\nэхний гүйлтээ эхлүүлээрэй.';

  @override
  String get invalidRoute => 'Буруу маршрут';

  @override
  String get routeLoadFailed => 'Маршрутыг ачаалж чадсангүй';

  @override
  String pinCountValue(int count) {
    return '$count';
  }

  @override
  String get timelineSearchHint => 'Газар, тэмдэглэл, аяллын нэрээр хайх';

  @override
  String get timelineSearchNoResults => 'Хайлтын илэрц олдсонгүй';

  @override
  String get modePhoto => 'Зураг';

  @override
  String get modeMemo => 'Тэмдэглэл';

  @override
  String get noMemosYet => 'Хадгалсан тэмдэглэл хараахан алга';

  @override
  String get emptyPhotoHint =>
      'Аяллын үеэр зураг аваарай\nГазрын зургийг удаан дарж тэмдэг нэмнэ';

  @override
  String get emptyMemoHint =>
      'Аяллын үеэр санаанд буусан зүйлээ тэмдэглээрэй\nГазрын зургийг удаан дарж тэмдэг нэмнэ';

  @override
  String get chipRestaurant => 'Ресторан';

  @override
  String get chipCafe => 'Кафе';

  @override
  String get chipPopup => 'Поп-ап дэлгүүр';

  @override
  String get chipBar => 'Бар';

  @override
  String get chipPark => 'Цэцэрлэгт хүрээлэн';

  @override
  String get chipShopping => 'Дэлгүүр хэсэх';

  @override
  String get chipCulture => 'Соёл';

  @override
  String get chipConvenience => 'Мини маркет';

  @override
  String get sugHip => 'Загварлаг уур амьсгал';

  @override
  String get sugQuiet => 'Нам гүм газар';

  @override
  String get sugInsta => 'Инстаграмд тохирсон';

  @override
  String get sugSpacious => 'Өргөн уудам';

  @override
  String get sugView => 'Үзэсгэлэнтэй харагдац';

  @override
  String get sugValue => 'Хямд бөгөөд сайн';

  @override
  String get sugTerrace => 'Гадаа тагт';

  @override
  String get sug24h => '24 цагийн';

  @override
  String get placeCheckLocationPermission => 'Байршлын зөвшөөрлөө шалгана уу.';

  @override
  String get placeLocating => 'Байршлыг олж байна…';

  @override
  String get placeNeedInput => 'Ангилал сонгох эсвэл хайж буйгаа бичнэ үү.';

  @override
  String get placeTitle => 'AI газрын санал';

  @override
  String get placeHeroTitle => 'Одоо хаашаа явах вэ?';

  @override
  String get placeHeroDesc =>
      'Хүссэнээ чөлөөтэй хэлээрэй\nAI ойролцоох хамгийн сайн газрыг олно';

  @override
  String get placeParty => 'Хүний тоо';

  @override
  String get placeWhere => 'Хаашаа явмаар байна?';

  @override
  String get placeBeSpecific => 'Илүү дэлгэрэнгүй хэлээрэй';

  @override
  String get placeInputHint =>
      'Жишээ: 3 найзтайгаа загварлаг кафе явмаар байна\nЖишээ: болзоонд тохиромжтой нам гүм ресторан';

  @override
  String get placeLocatingShort => 'Байршил олж байна...';

  @override
  String get placeRadius => 'Одоогийн байршлаас 2 км радиуст';

  @override
  String get placeLocationUnavailable => 'Байршлыг олж чадсангүй';

  @override
  String get placeRefresh => 'Шинэчлэх';

  @override
  String get placeSearching => 'AI газар хайж байна...';

  @override
  String get placeGetRecs => 'Санал авах';

  @override
  String placeGetRecsWith(int people, String chips) {
    return 'Санал авах · $people · $chips';
  }

  @override
  String peopleCount(int value) {
    return '$value';
  }

  @override
  String get currentLocation => 'Одоогийн байршил';

  @override
  String placesRecommended(int count) {
    return 'Танд $count газар санал болгож байна';
  }

  @override
  String placesCount(int count) {
    return '$count газар';
  }

  @override
  String get pinDeleteTooltip => 'Тэмдгийг устгах';

  @override
  String get pinEmpty => 'Энэ тэмдэгт агуулга алга.';

  @override
  String get photoSavedToGallery => 'Зураг галлерейд хадгалагдлаа 📷';

  @override
  String saveFailedWith(String error) {
    return 'Хадгалж чадсангүй: $error';
  }

  @override
  String get tapToClose => 'Дарж хаана уу';

  @override
  String get catGeneral => 'Ерөнхий';

  @override
  String get catFood => 'Хоол';

  @override
  String get catScenery => 'Үзвэрт газар';

  @override
  String get catCafe => 'Кафе';

  @override
  String get catWorkout => 'Дасгал';

  @override
  String get catMemo => 'Тэмдэглэл';

  @override
  String get addPin => 'Тэмдэг нэмэх';

  @override
  String get pickerTapMapHint =>
      'Байршлыг өөрчлөхийн тулд газрын зураг дээр дарна уу';

  @override
  String get today => 'Өнөөдөр';

  @override
  String get resetColorsTitle => 'Өөрчлөлтийг анхны байдалд оруулах';

  @override
  String get resetColorsBody =>
      'Бүх ангиллын өнгө/дүрс тэмдэг/нэрийг анхны утгад буцаах уу?';

  @override
  String get reset => 'Буцаах';

  @override
  String get categoryColors => 'Ангилал өөрчлөх';

  @override
  String get colorDefault => 'Үндсэн';

  @override
  String categoryColorTitle(String category) {
    return '$category өөрчлөх';
  }

  @override
  String get presetColors => 'Бэлэн өнгө';

  @override
  String get categoryNameLabel => 'Нэр';

  @override
  String get categoryNameHint => 'Ангиллын нэр';

  @override
  String get categoryIconLabel => 'Дүрс тэмдэг';

  @override
  String get apply => 'Хэрэглэх';

  @override
  String get addMemoOrPhoto =>
      'Хамгийн багадаа нэг тэмдэглэл эсвэл зураг нэмнэ үү';

  @override
  String get categoryLabel => 'Ангилал';

  @override
  String get categoryCustomize => 'Өөрчлөх';

  @override
  String get memoLabel => 'Тэмдэглэл';

  @override
  String get photoLabel => 'Зураг';

  @override
  String get memoHint => 'Өнөөдрийн тухай нэг мөр бичээрэй...';

  @override
  String get gallery => 'Галлерей';

  @override
  String get anotherPhoto => 'Өөр зураг';

  @override
  String get retakePhoto => 'Дахин авах';

  @override
  String get journey => 'Аялал';

  @override
  String routeDefaultTitle(String date) {
    return '$date аялал';
  }

  @override
  String get recoveredRecord => 'Өмнөх бүртгэл (автоматаар сэргээсэн)';

  @override
  String get placeErrNoGeminiKey =>
      'AI боломжийг ашиглахын тулд .env-д GEMINI_API_KEY нэмнэ үү.\naistudio.google.com дээрээс үнэгүй авч болно.';

  @override
  String placeErrNotEnough(int count) {
    return 'Ойролцоо санал болгох газар хангалттай биш байна. (Олдсон нэр дэвшигч: $count)\nPlaces API идэвхтэй эсэх, төлбөрийн бүртгэл болон байршлаа шалгана уу.';
  }

  @override
  String get placeErrNoMapsKey =>
      'Google Maps API түлхүүр алга. (.env-г шалгана уу)';

  @override
  String get placeErrDenied =>
      'Places API хүсэлтийг татгалзсан.\nGoogle Cloud дээр \"Places API\"-г идэвхжүүлж, API түлхүүрийн хязгаарлалтад нэмсэн эсэхээ шалгана уу.';

  @override
  String get placeErrQuota =>
      'API ашиглалтын хязгаараас хэтэрлээ. Төлбөрийн бүртгэлээ шалгана уу.';

  @override
  String get placeErrBadRequest =>
      'Хайлтын хүсэлт буруу байна. Байршлаа шалгана уу.';

  @override
  String placeErrSearchFailed(String status) {
    return 'Газар хайх амжилтгүй: $status';
  }

  @override
  String aiErrNetwork(String error) {
    return 'AI руу хандах үед сүлжээний алдаа гарлаа: $error';
  }

  @override
  String aiErrResponse(int code, String body) {
    return 'AI хариултын алдаа ($code)\n$body';
  }

  @override
  String get aiErrNoContent => 'Gemini-ийн хариултаас агуулга олдсонгүй.';

  @override
  String get aiErrBadStructure => 'Gemini-ийн хариултын бүтэц буруу байна.';

  @override
  String aiErrUnparsable(String raw) {
    return 'AI-ийн хариултыг ойлгож чадсангүй. Дахин оролдоно уу.\nХариулт: $raw';
  }

  @override
  String get aiErrBadFormat =>
      'AI-ийн хариултын формат буруу байна. Дахин оролдоно уу.';

  @override
  String get aiErrNoPick => 'AI газар сонгож чадсангүй. Дахин оролдоно уу.';

  @override
  String get aiErrTooFewValid =>
      'Хүчинтэй газар хангалтгүй байна. Дахин оролдоно уу.';

  @override
  String get aiDefaultReason => 'Санал болгож буй газар.';

  @override
  String get trackingChannelName => 'Tracen байршил хянах';

  @override
  String get trackingChannelDesc => 'Дэвсгэрт таны замыг тэмдэглэж байна.';

  @override
  String get trackingNotifTitle => 'Tracen замыг тэмдэглэж байна';

  @override
  String get trackingNotifText => 'Дэвсгэрт байршлыг хянаж байна.';

  @override
  String get locationServiceOff =>
      'Байршлын үйлчилгээ унтраастай байна. Төхөөрөмжийн тохиргооноос асаана уу.';

  @override
  String get locationPermissionDenied => 'Байршлын зөвшөөрлийг татгалзсан.';

  @override
  String get locationPermissionDeniedForever =>
      'Байршлын зөвшөөрлийг үүрд татгалзсан. Апп-ын тохиргооноос зөвшөөрнө үү.';

  @override
  String get activityRunning => 'Гүйлт';

  @override
  String get activityWalking => 'Алхалт';

  @override
  String get activityCycling => 'Дугуй унах';

  @override
  String get metricSpeed => 'Хурд';

  @override
  String get metricAvgSpeed => 'Дундаж хурд';

  @override
  String get metricMaxSpeed => 'Дээд хурд';

  @override
  String get metricAltitude => 'Өндөр';

  @override
  String get metricSteps => 'Алхам';

  @override
  String get trackingPause => 'Түр зогсоох';

  @override
  String get trackingResume => 'Үргэлжлүүлэх';

  @override
  String get trackingHoldToStop => 'Дуусгахын тулд удаан дарна уу';

  @override
  String get trackingBackToCurrentLocation => 'Одоогийн байршил руу';

  @override
  String get trackingLocatingGps => 'Байршил тодорхойлж байна…';

  @override
  String get trackingPreciseLocationOff =>
      'Нарийвчилсан байршил унтарсан тул бүртгэл буруу байж болзошгүй.';

  @override
  String get trackingPreciseLocationTurnOn => 'Асаах';

  @override
  String get filterGoldenRoute => 'Golden Route';

  @override
  String get filterNightTrace => 'Night Trace';

  @override
  String get filterFadedMap => 'Faded Map';

  @override
  String get filterMonoPath => 'Mono Path';

  @override
  String get filterStrength => 'Хүч';

  @override
  String get overlayTitle => 'TRACEN давхарга';

  @override
  String get overlayDateStamp => 'Огнооны тамга';

  @override
  String get overlayRoute => 'Өнөөдрийн зам';

  @override
  String get overlayWatermark => 'Усан тэмдэг';

  @override
  String get cameraEntry => 'TRACEN камер';

  @override
  String get cameraGrid => 'Тор';

  @override
  String get cameraSwitch => 'Камер солих';

  @override
  String get cameraRatio => 'Харьцаа';

  @override
  String get cameraMirrorFront => 'Урд камерыг тольдох';

  @override
  String get cameraFlashOff => 'Гэрэл унтраах';

  @override
  String get cameraFlashAuto => 'Гэрэл автомат';

  @override
  String get cameraFlashOn => 'Гэрэл асаах';

  @override
  String get cameraPermissionNeeded =>
      'Зураг авахын тулд камерын зөвшөөрөл хэрэгтэй';

  @override
  String get cameraUnavailable => 'Камер ашиглах боломжгүй';

  @override
  String get photoProcessing => 'Шүүлтүүр хэрэглэж байна…';

  @override
  String get sharePhoto => 'Хуваалцах';

  @override
  String get pinShareTooltip => 'Хуваалцах карт үүсгэх';

  @override
  String get shareEditorTitle => 'Түүх засах';

  @override
  String get shareTemplateMinimal => 'Минимал';

  @override
  String get shareTemplateFilm => 'Кино хальс';

  @override
  String get shareTemplateStamp => 'Тамга';

  @override
  String get shareToggleDate => 'Огноо';

  @override
  String get shareToggleMap => 'Газрын зураг';

  @override
  String get shareTogglePlace => 'Байршлын нэр';

  @override
  String get shareToggleLogo => 'Лого';

  @override
  String get shareToggleRoute => 'Маршрут';

  @override
  String get shareEditPlaceName => 'Байршлын нэр засах';

  @override
  String get photoEditTitle => 'Зураг засах';

  @override
  String get photoEditReset => 'Дахин тохируулах';

  @override
  String get photoEditTabFilter => 'Шүүлтүүр';

  @override
  String get photoEditTabTemplate => 'Загвар';

  @override
  String get photoEditTabDisplay => 'Харуулах';

  @override
  String get photoEditTabColor => 'Өнгө';

  @override
  String get shareInkWhite => 'Цагаан';

  @override
  String get shareInkBlack => 'Бэх хар';

  @override
  String get shareInkPurple => 'Ягаан';

  @override
  String get shareToInstagramStory => 'Instagram Story-д хуваалцах';

  @override
  String get shareToOtherApps => 'Бусад аппаар хуваалцах';

  @override
  String get shareSaveToGallery => 'Зурагт хадгалах';

  @override
  String get shareStickerHint =>
      'Наалтыг чирж зөөж, хоёр хуруугаар хэмжээг нь өөрчилнө үү';

  @override
  String get poiPickerTitle => 'Байршлын нэр сонгох';

  @override
  String poiPickerDistanceMeters(int meters) {
    return '$metersм';
  }

  @override
  String get poiPickerNeighborhoodFallback => 'Хорооллын нэр ашиглах';

  @override
  String get poiPickerManualEntry => 'Гараар оруулах';

  @override
  String get poiPickerManualHint => 'Байршлын нэрийг оруулна уу';

  @override
  String get poiPickerConfirm => 'Баталгаажуулах';

  @override
  String get poiPickerNoCandidates => 'Ойролцоо байршил олдсонгүй';

  @override
  String get trackingIdleTitle => 'Ямар аялал тэмдэглэх вэ?';

  @override
  String get trackingIdleHintRunning => 'Хурдац';

  @override
  String get trackingIdleHintWalking => 'Хурдац · алхам';

  @override
  String get trackingIdleHintCycling => 'Хурд';

  @override
  String get trackingGpsSearching => 'GPS дохио хайж байна…';

  @override
  String get trackingGpsReady => 'Бэлэн';

  @override
  String trackingStartActivity(String activity) {
    return '$activity эхлүүлэх';
  }

  @override
  String get trackingWeakGpsTitle => 'GPS дохио сул байна';

  @override
  String get trackingWeakGpsBody =>
      'Эхний хэдэн арван метр буруу бичигдэж магадгүй. Эхлүүлэх үү?';

  @override
  String get trackingWait => 'Хүлээх';

  @override
  String get trackingStartAnyway => 'Эхлүүлэх';

  @override
  String get trackingCountdownSkip => 'Шууд эхлүүлэхийн тулд дарна уу';

  @override
  String get trackingPermTitle => 'Байршлын зөвшөөрөл хэрэгтэй';

  @override
  String get trackingPermBody =>
      'Аяллаа газрын зураг дээр зурахын тулд байршлын хандалтыг зөвшөөрнө үү. Дэлгэц унтарсан үед ч бичихийн тулд \"Үргэлж\" сонгоно уу.';

  @override
  String get trackingPermWhileUsing => 'Ашиглах үед зөвшөөрөх';

  @override
  String get trackingPermAlways => 'Үргэлж зөвшөөрөх (арын горим)';

  @override
  String get trackingPermSettings => 'Тохиргоо нээх';

  @override
  String get trackingShortTitle => 'Богино бичлэг';

  @override
  String trackingShortBody(String summary) {
    return 'Зөвхөн $summary. Хадгалах уу?';
  }

  @override
  String get resultDone => 'Аялал дууслаа';

  @override
  String get resultMovingTime => 'Хөдөлсөн хугацаа';

  @override
  String get resultElevationGain => 'Өндрийн өсөлт';

  @override
  String get resultSplitsKm => 'Км тутмын хэсэг';

  @override
  String get resultSplits5Km => '5 км хэсэг';

  @override
  String get resultFastestHint => 'Хамгийн хурдан хэсэг тодорсон';

  @override
  String get resultPhotos => 'Аяллын зургууд';

  @override
  String get resultMemo => 'Товч тэмдэглэл';

  @override
  String get resultMemoHint => 'Өнөөдрийн аялал ямар байв?';

  @override
  String get resultSave => 'Аялал хадгалах';

  @override
  String get resultSaveShort => 'Хадгалах';

  @override
  String get resultSaved => 'Аялал хадгалагдлаа';

  @override
  String get resultDiscardTitle => 'Энэ бичлэгийг устгах уу?';

  @override
  String get resultDiscardBody => 'Хадгалахгүй бол энэ аялал устана.';

  @override
  String get resultDiscard => 'Устгах';

  @override
  String get resultCancel => 'Болих';

  @override
  String get resultTimeMorning => 'Өглөөний';

  @override
  String get resultTimeAfternoon => 'Өдрийн';

  @override
  String get resultTimeEvening => 'Оройн';

  @override
  String get resultTimeNight => 'Шөнийн';

  @override
  String resultAutoTitle(String date, String timeOfDay, String activity) {
    return '$date · $timeOfDay $activity';
  }

  @override
  String get activityShareTitle => 'Аялал хуваалцах';

  @override
  String get activityShareTemplateRoute => 'Маршрут';

  @override
  String get activityShareTemplateStats => 'Үзүүлэлт';

  @override
  String get activityShareTemplatePhoto => 'Зураг';

  @override
  String get activityShareTemplateSticker => 'Тунгалаг наалт';

  @override
  String get activityShareStickerHint =>
      'Доор нь зураг нэмэх эсвэл Instagram-д стикер болгон нийтлээрэй';

  @override
  String get activityShareAddPhoto => 'Зураг нэмэх';

  @override
  String get activityShareChangePhoto => 'Зураг солих';

  @override
  String get activityShareRemovePhoto => 'Зураг хасах';

  @override
  String get activityShareTakePhoto => 'Зураг авах';

  @override
  String get shareInstagramUnavailable =>
      'Instagram нээгдсэнгүй — хуваалцах цонхоор нээж байна';
}
