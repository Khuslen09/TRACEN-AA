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
  String get onboarding1Desc => '산책, 러닝, 여행 — 어디든 Tracen과 \n함께 걸어요.';

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

  @override
  String get commonEmail => '이메일';

  @override
  String get commonPassword => '비밀번호';

  @override
  String get commonOr => '또는';

  @override
  String get commonLogin => '로그인';

  @override
  String get loginEnterCredentials => '이메일과 비밀번호를 입력해주세요';

  @override
  String get loginError => '로그인 중 오류가 발생했어요';

  @override
  String get googleLoginFailed => 'Google 로그인에 실패했어요';

  @override
  String get loginWelcome => '환영합니다';

  @override
  String get loginSubtitle => '오늘의 여정을 기록해볼까요';

  @override
  String get passwordHint => '비밀번호를 입력하세요';

  @override
  String get forgotPasswordLink => '비밀번호를 잊으셨나요?';

  @override
  String get continueWithGoogle => 'Google로 계속하기';

  @override
  String get continueWithAppleSoon => 'Apple로 계속하기 (준비 중)';

  @override
  String get noAccountYet => '아직 계정이 없으신가요?';

  @override
  String get signUpAction => '가입하기';

  @override
  String get nameRequired => '이름을 입력해주세요';

  @override
  String get nameTooShort => '이름은 2자 이상이어야 해요';

  @override
  String get emailRequired => '이메일을 입력해주세요';

  @override
  String get emailInvalid => '올바른 이메일 형식이 아니에요';

  @override
  String get passwordRequired => '비밀번호를 입력해주세요';

  @override
  String get passwordTooShort => '비밀번호는 6자 이상이어야 해요';

  @override
  String get passwordMismatch => '비밀번호가 일치하지 않아요';

  @override
  String get agreeTermsRequired => '약관에 동의해주세요';

  @override
  String get signUpError => '가입 중 오류가 발생했어요';

  @override
  String get signUpTitle => '계정 만들기';

  @override
  String get signUpSubtitle => '몇 가지 정보만 입력하면 끝나요';

  @override
  String get nameLabel => '이름';

  @override
  String get nameHint => '닉네임 또는 이름';

  @override
  String get passwordHintMin6 => '6자 이상';

  @override
  String get confirmPasswordLabel => '비밀번호 확인';

  @override
  String get confirmPasswordHint => '한 번 더 입력해주세요';

  @override
  String get signUpComplete => '가입 완료';

  @override
  String get alreadyHaveAccount => '이미 계정이 있으신가요?';

  @override
  String get termsAgreePrefix => '';

  @override
  String get termsAgreeTermsLink => '서비스 이용약관';

  @override
  String get termsAgreeMiddle => ' 및 ';

  @override
  String get termsAgreePrivacyLink => '개인정보처리방침';

  @override
  String get termsAgreeSuffix => '에 동의합니다';

  @override
  String get forgotPasswordDesc => '가입하신 이메일을 입력하시면\n비밀번호 재설정 링크를 보내드려요.';

  @override
  String get sendResetEmail => '재설정 메일 보내기';

  @override
  String get resetEmailSentTitle => '메일을 보냈어요';

  @override
  String get resetEmailSentDesc =>
      '받은편지함에서 재설정 메일을 확인해주세요.\n메일이 안 보이면 스팸함도 확인해보세요.';

  @override
  String get backToLogin => '로그인 화면으로';

  @override
  String get tryAnotherEmail => '다른 이메일로 다시 시도';

  @override
  String get authCancelled => '취소되었어요';

  @override
  String get authLoginRequired => '로그인이 필요해요';

  @override
  String get profileLoadFailed => '프로필을 불러올 수 없어요';

  @override
  String get authReauthRequired => '재로그인이 필요해요. 다시 로그인 후 탈퇴해주세요.';

  @override
  String get authErrorDisabled => '비활성화된 계정이에요';

  @override
  String get authErrorWrongCredentials => '이메일 또는 비밀번호가 일치하지 않아요';

  @override
  String get authErrorEmailInUse => '이미 가입된 이메일이에요';

  @override
  String get authErrorNetwork => '네트워크 연결을 확인해주세요';

  @override
  String get authErrorTooMany => '너무 많은 시도가 있었어요. 잠시 후 다시 시도해주세요';

  @override
  String authErrorGeneric(String code) {
    return '인증에 실패했어요 ($code)';
  }

  @override
  String get permissionLater => '나중에';

  @override
  String get permissionTitle => '시작하기 전에\n권한을 확인해주세요';

  @override
  String get permissionIntro =>
      'Tracen이 여정을 기록하려면 다음 권한이 필요해요.\n나중에 언제든 설정에서 변경할 수 있어요.';

  @override
  String get permLocationTitle => '위치 정보';

  @override
  String get permLocationReason => 'GPS로 이동 경로를 지도에 그리고\n여정 거리를 계산해요';

  @override
  String get permCameraTitle => '카메라';

  @override
  String get permCameraReason => '특별한 순간에 인증샷을\n바로 남길 수 있어요';

  @override
  String get permPhotosTitle => '사진 라이브러리';

  @override
  String get permPhotosReason => '저장된 사진을 핀에 첨부해서\n추억을 더 풍성하게 기록해요';

  @override
  String get permAllowAll => '모두 허용하기';

  @override
  String get permStatusGranted => '허용됨';

  @override
  String get permStatusNeeded => '필요함';

  @override
  String get permStatusSettings => '설정 필요';

  @override
  String get permStatusNotRequested => '미요청';

  @override
  String get permDeniedNotice => '거부된 권한이 있어요. 설정에서 직접 켜주세요.';

  @override
  String get permOpenSettings => '설정으로 이동';

  @override
  String get splashTagline => '나의 여정을 기록하다';

  @override
  String get pinAdded => '핀이 추가되었어요 📍';

  @override
  String get pinDeleted => '핀을 삭제했어요';

  @override
  String get locationNotFound => '위치를 찾을 수 없어요';

  @override
  String get navMap => '지도';

  @override
  String get navTimeline => '타임라인';

  @override
  String get navProfile => '프로필';

  @override
  String get profileEdit => '프로필 편집';

  @override
  String get profileNoName => '이름 없음';

  @override
  String get statRuns => '러닝';

  @override
  String get statDistance => '총 거리';

  @override
  String get statPins => '핀';

  @override
  String get recentPhotos => '최근 사진';

  @override
  String get seeAll => '전체 보기';

  @override
  String get noPhotosYet => '아직 저장된 사진이 없어요';

  @override
  String get saveError => '저장 중 오류가 발생했어요';

  @override
  String get changePhoto => '사진 변경';

  @override
  String get emailReadOnly => '이메일은 변경할 수 없어요';

  @override
  String get save => '저장';

  @override
  String get takePhoto => '카메라로 촬영';

  @override
  String get chooseFromGallery => '갤러리에서 선택';

  @override
  String get commonOk => '확인';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonRetry => '다시 시도';

  @override
  String get runLocationPermissionNeeded => '위치 권한이 필요합니다';

  @override
  String get runEndTitle => '러닝을 종료할까요?';

  @override
  String runEndBody(String km) {
    return '지금까지 $km km 달렸어요.';
  }

  @override
  String get runContinue => '계속';

  @override
  String get runEnd => '종료';

  @override
  String get runStartTitle => '러닝을 시작할까요?';

  @override
  String get runStartHint => 'GPS가 준비되면 기록이 시작돼요.\n스트레칭은 했나요? 🏃';

  @override
  String get runStartButton => '시작하기';

  @override
  String get runGpsConnecting => 'GPS 연결 중...';

  @override
  String get runDistance => '거리';

  @override
  String get runTime => '시간';

  @override
  String get runPace => '페이스';

  @override
  String get runCalories => '칼로리';

  @override
  String get runLongPressHint => '지도를 길게 눌러 핀 추가';

  @override
  String get runInfoNotFound => '러닝 정보를 찾을 수 없어요';

  @override
  String get resultLoadFailed => '결과를 불러올 수 없어요';

  @override
  String get runComplete => '러닝 완료';

  @override
  String get runAvgPace => '평균 페이스';

  @override
  String get unitCountSuffix => '개';

  @override
  String get mapStart => '시작';

  @override
  String get mapEnd => '도착';

  @override
  String get routeTooShort => '경로가 너무 짧아서 표시할 수 없어요';

  @override
  String get deleteRunTitle => '이 러닝을 삭제할까요?';

  @override
  String get deleteRunBody => '경로와 핀도 함께 삭제되며, 되돌릴 수 없어요.';

  @override
  String get runDeleted => '러닝을 삭제했어요';

  @override
  String get myRuns => '나의 러닝';

  @override
  String get loadFailed => '불러오기에 실패했어요';

  @override
  String get runInProgress => '진행 중';

  @override
  String durationHM(int h, int m) {
    return '$h시간 $m분';
  }

  @override
  String durationM(int m) {
    return '$m분';
  }

  @override
  String durationS(int s) {
    return '$s초';
  }

  @override
  String get noRunsYet => '아직 기록된 러닝이 없어요';

  @override
  String get noRunsHint => '지도 화면의 보라색 러닝 버튼을 눌러\n첫 러닝을 시작해보세요.';

  @override
  String get invalidRoute => '잘못된 여정입니다';

  @override
  String get routeLoadFailed => '경로를 불러올 수 없어요';

  @override
  String pinCountValue(int count) {
    return '$count개';
  }

  @override
  String get timelineSearchHint => '장소·메모·여정 이름으로 검색';

  @override
  String get timelineSearchNoResults => '검색 결과가 없어요';

  @override
  String get modePhoto => '사진';

  @override
  String get modeMemo => '메모';

  @override
  String get noMemosYet => '아직 저장된 메모가 없어요';

  @override
  String get emptyPhotoHint => '여정 중 인증샷을 남겨보세요\n지도를 길게 누르면 핀을 추가할 수 있어요';

  @override
  String get emptyMemoHint => '여정 중 떠오르는 생각을 메모해보세요\n지도를 길게 누르면 핀을 추가할 수 있어요';

  @override
  String get chipRestaurant => '맛집';

  @override
  String get chipCafe => '카페';

  @override
  String get chipPopup => '팝업스토어';

  @override
  String get chipBar => '술집';

  @override
  String get chipPark => '공원';

  @override
  String get chipShopping => '쇼핑';

  @override
  String get chipCulture => '문화';

  @override
  String get chipConvenience => '편의점';

  @override
  String get sugHip => '힙한 분위기';

  @override
  String get sugQuiet => '조용한 곳';

  @override
  String get sugInsta => '인스타 감성';

  @override
  String get sugSpacious => '넓은 곳';

  @override
  String get sugView => '뷰 좋은 곳';

  @override
  String get sugValue => '가성비';

  @override
  String get sugTerrace => '야외 테라스';

  @override
  String get sug24h => '24시간';

  @override
  String get placeCheckLocationPermission => '위치 권한을 확인해주세요.';

  @override
  String get placeLocating => '위치를 가져오는 중이에요.';

  @override
  String get placeNeedInput => '카테고리나 원하는 것을 입력해주세요.';

  @override
  String get placeTitle => 'AI 장소 추천';

  @override
  String get placeHeroTitle => '지금 여기서 어디 갈까요?';

  @override
  String get placeHeroDesc => '원하는 걸 자유롭게 말해주세요\nAI가 주변 최적 장소를 찾아드려요';

  @override
  String get placeParty => '인원';

  @override
  String get placeWhere => '어디 가고 싶어요?';

  @override
  String get placeBeSpecific => '더 구체적으로 말해줘요';

  @override
  String get placeInputHint => '예) 친구 3명이랑 힙한 분위기 카페 가고 싶어\n예) 데이트하기 좋은 조용한 맛집';

  @override
  String get placeLocatingShort => '위치 가져오는 중...';

  @override
  String get placeRadius => '현재 위치 기준 2km 반경';

  @override
  String get placeLocationUnavailable => '위치를 가져올 수 없어요';

  @override
  String get placeRefresh => '새로고침';

  @override
  String get placeSearching => 'AI가 장소 찾는 중...';

  @override
  String get placeGetRecs => '장소 추천 받기';

  @override
  String placeGetRecsWith(int people, String chips) {
    return '$people명 · $chips 추천 받기';
  }

  @override
  String peopleCount(int value) {
    return '$value명';
  }

  @override
  String get currentLocation => '현재 위치';

  @override
  String placesRecommended(int count) {
    return '$count곳 추천드려요';
  }

  @override
  String placesCount(int count) {
    return '$count곳';
  }

  @override
  String get pinDeleteTooltip => '핀 삭제';

  @override
  String get pinEmpty => '내용이 없는 핀이에요.';

  @override
  String get photoSavedToGallery => '사진이 갤러리에 저장됐어요 📷';

  @override
  String saveFailedWith(String error) {
    return '저장 실패: $error';
  }

  @override
  String get tapToClose => '탭하면 닫혀요';

  @override
  String get catGeneral => '일반';

  @override
  String get catFood => '음식';

  @override
  String get catScenery => '명소';

  @override
  String get catCafe => '카페';

  @override
  String get catWorkout => '운동';

  @override
  String get catMemo => '메모';

  @override
  String get addPin => '핀 추가';

  @override
  String get pickerTapMapHint => '지도를 탭해서 위치를 옮길 수 있어요';

  @override
  String get today => '오늘';

  @override
  String get resetColorsTitle => '커스터마이즈 초기화';

  @override
  String get resetColorsBody => '모든 카테고리의 색상/아이콘/이름을 기본값으로 되돌릴까요?';

  @override
  String get reset => '초기화';

  @override
  String get categoryColors => '카테고리 커스터마이즈';

  @override
  String get colorDefault => '기본';

  @override
  String categoryColorTitle(String category) {
    return '$category 커스터마이즈';
  }

  @override
  String get presetColors => '프리셋 색상';

  @override
  String get categoryNameLabel => '이름';

  @override
  String get categoryNameHint => '카테고리 이름';

  @override
  String get categoryIconLabel => '아이콘';

  @override
  String get apply => '적용';

  @override
  String get addMemoOrPhoto => '메모나 사진을 하나 이상 추가해주세요';

  @override
  String get categoryLabel => '카테고리';

  @override
  String get categoryCustomize => '커스터마이즈';

  @override
  String get memoLabel => '메모';

  @override
  String get photoLabel => '사진';

  @override
  String get memoHint => '오늘의 한 줄을 적어보세요...';

  @override
  String get gallery => '갤러리';

  @override
  String get anotherPhoto => '다른 사진';

  @override
  String get retakePhoto => '다시 촬영';

  @override
  String get journey => '여정';

  @override
  String routeDefaultTitle(String date) {
    return '$date 여정';
  }

  @override
  String get recoveredRecord => '이전 기록 (자동 복구)';

  @override
  String get placeErrNoGeminiKey =>
      'AI 기능을 쓰려면 .env에 GEMINI_API_KEY가 필요해요.\naistudio.google.com 에서 무료로 발급받을 수 있어요.';

  @override
  String placeErrNotEnough(int count) {
    return '주변에 추천할 장소가 충분하지 않아요. (검색된 후보: $count개)\nPlaces API 활성화 / 결제 계정 / 위치를 확인해주세요.';
  }

  @override
  String get placeErrNoMapsKey => 'Google Maps API 키가 없어요. (.env 확인)';

  @override
  String get placeErrDenied =>
      'Places API가 거부됐어요.\nGoogle Cloud에서 \"Places API\"를 활성화하고, API 키 제한에 Places를 추가했는지 확인해주세요.';

  @override
  String get placeErrQuota => 'API 사용 한도를 초과했어요. 결제 계정을 확인해주세요.';

  @override
  String get placeErrBadRequest => '검색 요청이 잘못됐어요. 위치 정보를 확인해주세요.';

  @override
  String placeErrSearchFailed(String status) {
    return '장소 검색 실패: $status';
  }

  @override
  String aiErrNetwork(String error) {
    return 'AI 호출 중 네트워크 오류가 났어요: $error';
  }

  @override
  String aiErrResponse(int code, String body) {
    return 'AI 응답 오류 ($code)\n$body';
  }

  @override
  String get aiErrNoContent => 'Gemini 응답에서 내용을 찾지 못했어요.';

  @override
  String get aiErrBadStructure => 'Gemini 응답 구조가 올바르지 않아요.';

  @override
  String aiErrUnparsable(String raw) {
    return 'AI 응답을 이해하지 못했어요. 다시 시도해주세요.\n응답: $raw';
  }

  @override
  String get aiErrBadFormat => 'AI 응답 형식이 올바르지 않아요. 다시 시도해주세요.';

  @override
  String get aiErrNoPick => 'AI가 장소를 고르지 못했어요. 다시 시도해주세요.';

  @override
  String get aiErrTooFewValid => '유효한 장소가 부족해요. 다시 시도해주세요.';

  @override
  String get aiDefaultReason => '추천 장소예요.';

  @override
  String get trackingChannelName => 'Tracen 위치 추적';

  @override
  String get trackingChannelDesc => '백그라운드에서 경로를 기록하고 있습니다.';

  @override
  String get trackingNotifTitle => 'Tracen 경로 기록 중';

  @override
  String get trackingNotifText => '백그라운드에서 위치를 추적하고 있습니다.';

  @override
  String get locationServiceOff => '위치 서비스가 꺼져 있습니다. 디바이스 설정에서 켜주세요.';

  @override
  String get locationPermissionDenied => '위치 권한이 거부되었습니다.';

  @override
  String get locationPermissionDeniedForever =>
      '위치 권한이 영구 거부되었습니다. 앱 설정에서 허용해주세요.';

  @override
  String get activityRunning => '러닝';

  @override
  String get activityWalking => '걷기';

  @override
  String get activityCycling => '자전거';

  @override
  String get metricSpeed => '속도';

  @override
  String get metricAvgSpeed => '평균 속도';

  @override
  String get metricMaxSpeed => '최고 속도';

  @override
  String get metricAltitude => '고도';

  @override
  String get metricSteps => '걸음 수';

  @override
  String get trackingPause => '일시정지';

  @override
  String get trackingResume => '재개';

  @override
  String get trackingHoldToStop => '길게 눌러서 종료';

  @override
  String get trackingBackToCurrentLocation => '현재 위치로';

  @override
  String get trackingLocatingGps => '위치를 찾는 중…';

  @override
  String get trackingPreciseLocationOff => '정확한 위치가 꺼져 있어 기록이 부정확할 수 있어요.';

  @override
  String get trackingPreciseLocationTurnOn => '켜기';

  @override
  String get filterGoldenRoute => 'Golden Route';

  @override
  String get filterNightTrace => 'Night Trace';

  @override
  String get filterFadedMap => 'Faded Map';

  @override
  String get filterMonoPath => 'Mono Path';

  @override
  String get filterStrength => '강도';

  @override
  String get overlayTitle => 'TRACEN 오버레이';

  @override
  String get overlayDateStamp => '날짜 스탬프';

  @override
  String get overlayRoute => '오늘의 경로';

  @override
  String get overlayWatermark => '워터마크';

  @override
  String get cameraEntry => 'TRACEN 카메라';

  @override
  String get cameraGrid => '그리드';

  @override
  String get cameraSwitch => '카메라 전환';

  @override
  String get cameraRatio => '비율';

  @override
  String get cameraMirrorFront => '전면 카메라 미러링';

  @override
  String get cameraFlashOff => '플래시 끔';

  @override
  String get cameraFlashAuto => '플래시 자동';

  @override
  String get cameraFlashOn => '플래시 켬';

  @override
  String get cameraPermissionNeeded => '촬영하려면 카메라 권한이 필요해요';

  @override
  String get cameraUnavailable => '카메라를 사용할 수 없어요';

  @override
  String get photoProcessing => '필터 적용 중…';

  @override
  String get sharePhoto => '공유';

  @override
  String get pinShareTooltip => '공유 카드 만들기';

  @override
  String get shareEditorTitle => '스토리 편집';

  @override
  String get shareTemplateMinimal => '미니멀';

  @override
  String get shareTemplateFilm => '필름';

  @override
  String get shareTemplateStamp => '스탬프';

  @override
  String get shareToggleDate => '날짜';

  @override
  String get shareToggleMap => '지도';

  @override
  String get shareTogglePlace => '위치명';

  @override
  String get shareToggleLogo => '로고';

  @override
  String get shareToggleRoute => '경로';

  @override
  String get shareEditPlaceName => '위치명 수정';

  @override
  String get photoEditTitle => '사진 편집';

  @override
  String get photoEditReset => '초기화';

  @override
  String get photoEditTabFilter => '필터';

  @override
  String get photoEditTabTemplate => '템플릿';

  @override
  String get photoEditTabDisplay => '표시';

  @override
  String get photoEditTabColor => '색상';

  @override
  String get shareInkWhite => '흰색';

  @override
  String get shareInkBlack => '먹색';

  @override
  String get shareInkPurple => '보라';

  @override
  String get shareToInstagramStory => '인스타 스토리에 공유';

  @override
  String get shareToOtherApps => '다른 앱으로 공유';

  @override
  String get shareSaveToGallery => '사진에 저장';

  @override
  String get shareStickerHint => '스티커를 끌어서 옮기고, 두 손가락으로 크기를 바꿔요';

  @override
  String get poiPickerTitle => '위치명 선택';

  @override
  String poiPickerDistanceMeters(int meters) {
    return '${meters}m';
  }

  @override
  String get poiPickerNeighborhoodFallback => '동네 이름 사용';

  @override
  String get poiPickerManualEntry => '직접 입력';

  @override
  String get poiPickerManualHint => '위치명을 입력하세요';

  @override
  String get poiPickerConfirm => '확인';

  @override
  String get poiPickerNoCandidates => '근처 장소를 찾지 못했어요';

  @override
  String get trackingIdleTitle => '어떤 여정을 기록할까요?';

  @override
  String get trackingIdleHintRunning => '페이스 기록';

  @override
  String get trackingIdleHintWalking => '페이스·걸음';

  @override
  String get trackingIdleHintCycling => '속도 기록';

  @override
  String get trackingGpsSearching => 'GPS 신호 찾는 중…';

  @override
  String get trackingGpsReady => '준비 완료';

  @override
  String trackingStartActivity(String activity) {
    return '$activity 시작';
  }

  @override
  String get trackingWeakGpsTitle => 'GPS 신호가 약해요';

  @override
  String get trackingWeakGpsBody => '지금 시작하면 처음 몇십 미터가 부정확할 수 있어요. 그래도 시작할까요?';

  @override
  String get trackingWait => '기다리기';

  @override
  String get trackingStartAnyway => '시작';

  @override
  String get trackingCountdownSkip => '탭하면 바로 시작';

  @override
  String get trackingPermTitle => '위치 권한이 필요해요';

  @override
  String get trackingPermBody =>
      '여정을 지도에 그리려면 위치 접근을 허용해 주세요. 화면을 꺼도 기록하려면 \'항상 허용\'이 필요해요.';

  @override
  String get trackingPermWhileUsing => '앱 사용 중 허용';

  @override
  String get trackingPermAlways => '항상 허용 (백그라운드 기록)';

  @override
  String get trackingPermSettings => '설정에서 허용하기';

  @override
  String get trackingShortTitle => '짧은 기록이에요';

  @override
  String trackingShortBody(String summary) {
    return '$summary 기록이에요. 저장할까요?';
  }

  @override
  String get resultDone => '오늘의 여정 완료';

  @override
  String get resultMovingTime => '이동 시간';

  @override
  String get resultElevationGain => '고도 상승';

  @override
  String get resultSplitsKm => 'km별 구간';

  @override
  String get resultSplits5Km => '5km 구간';

  @override
  String get resultFastestHint => '가장 빠른 구간 강조';

  @override
  String get resultPhotos => '여정 속 사진';

  @override
  String get resultMemo => '한 줄 메모';

  @override
  String get resultMemoHint => '오늘 여정은 어땠나요?';

  @override
  String get resultSave => '여정 저장';

  @override
  String get resultSaveShort => '저장';

  @override
  String get resultSaved => '여정을 저장했어요';

  @override
  String get resultDiscardTitle => '기록을 버릴까요?';

  @override
  String get resultDiscardBody => '저장하지 않으면 이 여정은 삭제돼요.';

  @override
  String get resultDiscard => '버리기';

  @override
  String get resultCancel => '취소';

  @override
  String get resultTimeMorning => '아침';

  @override
  String get resultTimeAfternoon => '오후';

  @override
  String get resultTimeEvening => '저녁';

  @override
  String get resultTimeNight => '밤';

  @override
  String resultAutoTitle(String date, String timeOfDay, String activity) {
    return '$date $timeOfDay $activity';
  }

  @override
  String get activityShareTitle => '여정 공유';

  @override
  String get activityShareTemplateRoute => '경로';

  @override
  String get activityShareTemplateStats => '기록';

  @override
  String get activityShareTemplatePhoto => '사진';

  @override
  String get activityShareTemplateSticker => '투명 스티커';

  @override
  String get activityShareStickerHint => '사진을 추가해 위에 얹거나, 인스타에서 스티커로 붙여 쓰세요';

  @override
  String get activityShareAddPhoto => '사진 추가';

  @override
  String get activityShareChangePhoto => '사진 변경';

  @override
  String get activityShareRemovePhoto => '사진 빼기';

  @override
  String get activityShareTakePhoto => '카메라로 촬영';

  @override
  String get shareInstagramUnavailable => '인스타그램을 열 수 없어 공유 시트로 열어요';
}
