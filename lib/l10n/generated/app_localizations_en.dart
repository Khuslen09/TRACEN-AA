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
      'Walks, runs, travel — go anywhere\nwith Tracen by your side.';

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

  @override
  String get commonEmail => 'Email';

  @override
  String get commonPassword => 'Password';

  @override
  String get commonOr => 'or';

  @override
  String get commonLogin => 'Log in';

  @override
  String get loginEnterCredentials => 'Please enter your email and password';

  @override
  String get loginError => 'Something went wrong while logging in';

  @override
  String get googleLoginFailed => 'Google sign-in failed';

  @override
  String get loginWelcome => 'Welcome';

  @override
  String get loginSubtitle => 'Ready to record today\'s journey?';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get forgotPasswordLink => 'Forgot your password?';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithAppleSoon => 'Continue with Apple (coming soon)';

  @override
  String get noAccountYet => 'Don\'t have an account yet?';

  @override
  String get signUpAction => 'Sign up';

  @override
  String get nameRequired => 'Please enter your name';

  @override
  String get nameTooShort => 'Name must be at least 2 characters';

  @override
  String get emailRequired => 'Please enter your email';

  @override
  String get emailInvalid => 'That doesn\'t look like a valid email';

  @override
  String get passwordRequired => 'Please enter a password';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get passwordMismatch => 'Passwords don\'t match';

  @override
  String get agreeTermsRequired => 'Please agree to the terms';

  @override
  String get signUpError => 'Something went wrong while signing up';

  @override
  String get signUpTitle => 'Create your account';

  @override
  String get signUpSubtitle => 'Just a few details and you\'re done';

  @override
  String get nameLabel => 'Name';

  @override
  String get nameHint => 'Nickname or name';

  @override
  String get passwordHintMin6 => 'At least 6 characters';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get confirmPasswordHint => 'Enter it once more';

  @override
  String get signUpComplete => 'Create account';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get termsAgreePrefix => 'I agree to the ';

  @override
  String get termsAgreeTermsLink => 'Terms of Service';

  @override
  String get termsAgreeMiddle => ' and ';

  @override
  String get termsAgreePrivacyLink => 'Privacy Policy';

  @override
  String get termsAgreeSuffix => '';

  @override
  String get forgotPasswordDesc =>
      'Enter the email you signed up with and\nwe\'ll send you a password reset link.';

  @override
  String get sendResetEmail => 'Send reset email';

  @override
  String get resetEmailSentTitle => 'Email sent';

  @override
  String get resetEmailSentDesc =>
      'Check your inbox for the reset email.\nIf you don\'t see it, check your spam folder too.';

  @override
  String get backToLogin => 'Back to log in';

  @override
  String get tryAnotherEmail => 'Try a different email';

  @override
  String get authCancelled => 'Cancelled';

  @override
  String get authLoginRequired => 'You need to log in first';

  @override
  String get profileLoadFailed => 'Couldn\'t load your profile';

  @override
  String get authReauthRequired =>
      'Please log in again, then delete your account.';

  @override
  String get authErrorDisabled => 'This account has been disabled';

  @override
  String get authErrorWrongCredentials => 'Incorrect email or password';

  @override
  String get authErrorEmailInUse => 'This email is already registered';

  @override
  String get authErrorNetwork => 'Please check your network connection';

  @override
  String get authErrorTooMany =>
      'Too many attempts. Please try again in a moment';

  @override
  String authErrorGeneric(String code) {
    return 'Authentication failed ($code)';
  }

  @override
  String get permissionLater => 'Later';

  @override
  String get permissionTitle => 'Before you begin,\nlet\'s check permissions';

  @override
  String get permissionIntro =>
      'Tracen needs the following permissions to record your journeys.\nYou can change them anytime in Settings.';

  @override
  String get permLocationTitle => 'Location';

  @override
  String get permLocationReason =>
      'We use GPS to draw your route on the map\nand measure your journey distance';

  @override
  String get permCameraTitle => 'Camera';

  @override
  String get permCameraReason => 'Snap a photo right\nat special moments';

  @override
  String get permPhotosTitle => 'Photo library';

  @override
  String get permPhotosReason =>
      'Attach saved photos to pins\nfor richer memories';

  @override
  String get permAllowAll => 'Allow all';

  @override
  String get permStatusGranted => 'Allowed';

  @override
  String get permStatusNeeded => 'Needed';

  @override
  String get permStatusSettings => 'Open Settings';

  @override
  String get permStatusNotRequested => 'Not requested';

  @override
  String get permDeniedNotice =>
      'Some permissions were denied. Please turn them on in Settings.';

  @override
  String get permOpenSettings => 'Go to Settings';

  @override
  String get splashTagline => 'Record your journey';

  @override
  String get pinAdded => 'Pin added 📍';

  @override
  String get pinDeleted => 'Pin deleted';

  @override
  String get locationNotFound => 'Couldn\'t find your location';

  @override
  String get navMap => 'Map';

  @override
  String get navTimeline => 'Timeline';

  @override
  String get navProfile => 'Profile';

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get profileNoName => 'No name';

  @override
  String get statRuns => 'Runs';

  @override
  String get statDistance => 'Total distance';

  @override
  String get statPins => 'Pins';

  @override
  String get recentPhotos => 'Recent photos';

  @override
  String get seeAll => 'See all';

  @override
  String get noPhotosYet => 'No photos saved yet';

  @override
  String get saveError => 'Something went wrong while saving';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get emailReadOnly => 'Email can\'t be changed';

  @override
  String get save => 'Save';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Try again';

  @override
  String get runLocationPermissionNeeded => 'Location permission is required';

  @override
  String get runEndTitle => 'End your run?';

  @override
  String runEndBody(String km) {
    return 'You\'ve run $km km so far.';
  }

  @override
  String get runContinue => 'Continue';

  @override
  String get runEnd => 'End';

  @override
  String get runStartTitle => 'Start a run?';

  @override
  String get runStartHint =>
      'Recording starts once GPS is ready.\nDid you stretch? 🏃';

  @override
  String get runStartButton => 'Start';

  @override
  String get runGpsConnecting => 'Connecting to GPS...';

  @override
  String get runDistance => 'Distance';

  @override
  String get runTime => 'Time';

  @override
  String get runPace => 'Pace';

  @override
  String get runCalories => 'Calories';

  @override
  String get runLongPressHint => 'Long-press the map to add a pin';

  @override
  String get runInfoNotFound => 'Couldn\'t find that run';

  @override
  String get resultLoadFailed => 'Couldn\'t load the result';

  @override
  String get runComplete => 'Run complete';

  @override
  String get runAvgPace => 'Avg pace';

  @override
  String get unitCountSuffix => '';

  @override
  String get mapStart => 'Start';

  @override
  String get mapEnd => 'Finish';

  @override
  String get routeTooShort => 'The route is too short to display';

  @override
  String get deleteRunTitle => 'Delete this run?';

  @override
  String get deleteRunBody =>
      'The route and pins will be deleted too. This can\'t be undone.';

  @override
  String get runDeleted => 'Run deleted';

  @override
  String get myRuns => 'My runs';

  @override
  String get loadFailed => 'Failed to load';

  @override
  String get runInProgress => 'In progress';

  @override
  String durationHM(int h, int m) {
    return '${h}h ${m}m';
  }

  @override
  String durationM(int m) {
    return '${m}m';
  }

  @override
  String durationS(int s) {
    return '${s}s';
  }

  @override
  String get noRunsYet => 'No runs recorded yet';

  @override
  String get noRunsHint =>
      'Tap the purple run button on the map\nto start your first run.';

  @override
  String get invalidRoute => 'Invalid route';

  @override
  String get routeLoadFailed => 'Couldn\'t load the route';

  @override
  String pinCountValue(int count) {
    return '$count';
  }

  @override
  String get timelineSearchHint => 'Search by place, memo, or journey name';

  @override
  String get timelineSearchNoResults => 'No results found';

  @override
  String get modePhoto => 'Photos';

  @override
  String get modeMemo => 'Memos';

  @override
  String get noMemosYet => 'No memos saved yet';

  @override
  String get emptyPhotoHint =>
      'Snap a photo during your journey\nLong-press the map to add a pin';

  @override
  String get emptyMemoHint =>
      'Jot down thoughts along the way\nLong-press the map to add a pin';

  @override
  String get chipRestaurant => 'Restaurants';

  @override
  String get chipCafe => 'Cafés';

  @override
  String get chipPopup => 'Pop-up stores';

  @override
  String get chipBar => 'Bars';

  @override
  String get chipPark => 'Parks';

  @override
  String get chipShopping => 'Shopping';

  @override
  String get chipCulture => 'Culture';

  @override
  String get chipConvenience => 'Convenience stores';

  @override
  String get sugHip => 'Trendy vibe';

  @override
  String get sugQuiet => 'Quiet spot';

  @override
  String get sugInsta => 'Instagram-worthy';

  @override
  String get sugSpacious => 'Spacious';

  @override
  String get sugView => 'Great view';

  @override
  String get sugValue => 'Good value';

  @override
  String get sugTerrace => 'Outdoor terrace';

  @override
  String get sug24h => 'Open 24 hours';

  @override
  String get placeCheckLocationPermission =>
      'Please check location permission.';

  @override
  String get placeLocating => 'Getting your location…';

  @override
  String get placeNeedInput =>
      'Pick a category or type what you\'re looking for.';

  @override
  String get placeTitle => 'AI place picks';

  @override
  String get placeHeroTitle => 'Where should we go from here?';

  @override
  String get placeHeroDesc =>
      'Tell us what you\'re after\nand AI will find the best spots nearby';

  @override
  String get placeParty => 'Party size';

  @override
  String get placeWhere => 'Where do you want to go?';

  @override
  String get placeBeSpecific => 'Tell us more';

  @override
  String get placeInputHint =>
      'e.g. A trendy café for me and 3 friends\ne.g. A quiet restaurant that\'s great for a date';

  @override
  String get placeLocatingShort => 'Getting location...';

  @override
  String get placeRadius => 'Within 2 km of your location';

  @override
  String get placeLocationUnavailable => 'Couldn\'t get your location';

  @override
  String get placeRefresh => 'Refresh';

  @override
  String get placeSearching => 'AI is finding places...';

  @override
  String get placeGetRecs => 'Get recommendations';

  @override
  String placeGetRecsWith(int people, String chips) {
    return 'Get recommendations · $people · $chips';
  }

  @override
  String peopleCount(int value) {
    return '$value';
  }

  @override
  String get currentLocation => 'Current location';

  @override
  String placesRecommended(int count) {
    return '$count places for you';
  }

  @override
  String placesCount(int count) {
    return '$count places';
  }

  @override
  String get pinDeleteTooltip => 'Delete pin';

  @override
  String get pinEmpty => 'This pin has no content.';

  @override
  String get photoSavedToGallery => 'Photo saved to your gallery 📷';

  @override
  String saveFailedWith(String error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String get tapToClose => 'Tap to close';

  @override
  String get catGeneral => 'General';

  @override
  String get catFood => 'Food';

  @override
  String get catScenery => 'Sights';

  @override
  String get catCafe => 'Café';

  @override
  String get catWorkout => 'Workout';

  @override
  String get catMemo => 'Memo';

  @override
  String get addPin => 'Add a pin';

  @override
  String get pickerTapMapHint => 'Tap the map to move the location';

  @override
  String get today => 'Today';

  @override
  String get resetColorsTitle => 'Reset customization';

  @override
  String get resetColorsBody =>
      'Reset all category colors, icons, and names to their defaults?';

  @override
  String get reset => 'Reset';

  @override
  String get categoryColors => 'Customize categories';

  @override
  String get colorDefault => 'Default';

  @override
  String categoryColorTitle(String category) {
    return 'Customize $category';
  }

  @override
  String get presetColors => 'Preset colors';

  @override
  String get categoryNameLabel => 'Name';

  @override
  String get categoryNameHint => 'Category name';

  @override
  String get categoryIconLabel => 'Icon';

  @override
  String get apply => 'Apply';

  @override
  String get addMemoOrPhoto => 'Add at least one memo or photo';

  @override
  String get categoryLabel => 'Category';

  @override
  String get categoryCustomize => 'Customize';

  @override
  String get memoLabel => 'Memo';

  @override
  String get photoLabel => 'Photo';

  @override
  String get memoHint => 'Write a line about today...';

  @override
  String get gallery => 'Gallery';

  @override
  String get anotherPhoto => 'Another photo';

  @override
  String get retakePhoto => 'Retake';

  @override
  String get journey => 'Journey';

  @override
  String routeDefaultTitle(String date) {
    return 'Journey $date';
  }

  @override
  String get recoveredRecord => 'Previous record (auto-recovered)';

  @override
  String get placeErrNoGeminiKey =>
      'To use AI features, add GEMINI_API_KEY to .env.\nYou can get one for free at aistudio.google.com.';

  @override
  String placeErrNotEnough(int count) {
    return 'Not enough places nearby to recommend. (Candidates found: $count)\nPlease check that the Places API is enabled, billing is set up, and your location is correct.';
  }

  @override
  String get placeErrNoMapsKey =>
      'Google Maps API key is missing. (Check .env)';

  @override
  String get placeErrDenied =>
      'The Places API request was denied.\nEnable \"Places API\" in Google Cloud and make sure it\'s allowed in your API key restrictions.';

  @override
  String get placeErrQuota =>
      'API usage limit exceeded. Please check your billing account.';

  @override
  String get placeErrBadRequest =>
      'The search request was invalid. Please check your location.';

  @override
  String placeErrSearchFailed(String status) {
    return 'Place search failed: $status';
  }

  @override
  String aiErrNetwork(String error) {
    return 'Network error while calling the AI: $error';
  }

  @override
  String aiErrResponse(int code, String body) {
    return 'AI response error ($code)\n$body';
  }

  @override
  String get aiErrNoContent => 'Couldn\'t find content in the Gemini response.';

  @override
  String get aiErrBadStructure => 'The Gemini response structure is invalid.';

  @override
  String aiErrUnparsable(String raw) {
    return 'Couldn\'t understand the AI response. Please try again.\nResponse: $raw';
  }

  @override
  String get aiErrBadFormat =>
      'The AI response format is invalid. Please try again.';

  @override
  String get aiErrNoPick =>
      'The AI couldn\'t pick any places. Please try again.';

  @override
  String get aiErrTooFewValid => 'Not enough valid places. Please try again.';

  @override
  String get aiDefaultReason => 'A recommended place.';

  @override
  String get trackingChannelName => 'Tracen location tracking';

  @override
  String get trackingChannelDesc => 'Recording your route in the background.';

  @override
  String get trackingNotifTitle => 'Tracen is recording your route';

  @override
  String get trackingNotifText => 'Tracking your location in the background.';

  @override
  String get locationServiceOff =>
      'Location services are turned off. Please turn them on in your device settings.';

  @override
  String get locationPermissionDenied => 'Location permission was denied.';

  @override
  String get locationPermissionDeniedForever =>
      'Location permission was permanently denied. Please allow it in the app settings.';

  @override
  String get activityRunning => 'Running';

  @override
  String get activityWalking => 'Walking';

  @override
  String get activityCycling => 'Cycling';

  @override
  String get metricSpeed => 'Speed';

  @override
  String get metricAvgSpeed => 'Avg speed';

  @override
  String get metricMaxSpeed => 'Max speed';

  @override
  String get metricAltitude => 'Altitude';

  @override
  String get metricSteps => 'Steps';

  @override
  String get trackingPause => 'Pause';

  @override
  String get trackingResume => 'Resume';

  @override
  String get trackingHoldToStop => 'Hold to end';

  @override
  String get trackingBackToCurrentLocation => 'Back to current location';

  @override
  String get trackingLocatingGps => 'Finding your location…';

  @override
  String get trackingPreciseLocationOff =>
      'Precise location is off, so tracking may be less accurate.';

  @override
  String get trackingPreciseLocationTurnOn => 'Turn on';

  @override
  String get filterGoldenRoute => 'Golden Route';

  @override
  String get filterNightTrace => 'Night Trace';

  @override
  String get filterFadedMap => 'Faded Map';

  @override
  String get filterMonoPath => 'Mono Path';

  @override
  String get filterStrength => 'Strength';

  @override
  String get overlayTitle => 'TRACEN overlay';

  @override
  String get overlayDateStamp => 'Date stamp';

  @override
  String get overlayRoute => 'Today\'s route';

  @override
  String get overlayWatermark => 'Watermark';

  @override
  String get cameraEntry => 'TRACEN camera';

  @override
  String get cameraGrid => 'Grid';

  @override
  String get cameraSwitch => 'Switch camera';

  @override
  String get cameraRatio => 'Ratio';

  @override
  String get cameraMirrorFront => 'Mirror front camera';

  @override
  String get cameraFlashOff => 'Flash off';

  @override
  String get cameraFlashAuto => 'Flash auto';

  @override
  String get cameraFlashOn => 'Flash on';

  @override
  String get cameraPermissionNeeded => 'Camera access is needed to take photos';

  @override
  String get cameraUnavailable => 'Camera unavailable';

  @override
  String get photoProcessing => 'Applying filter…';

  @override
  String get sharePhoto => 'Share';

  @override
  String get pinShareTooltip => 'Create share card';

  @override
  String get shareEditorTitle => 'Edit story';

  @override
  String get shareTemplateMinimal => 'Minimal';

  @override
  String get shareTemplateFilm => 'Film';

  @override
  String get shareTemplateStamp => 'Stamp';

  @override
  String get shareToggleDate => 'Date';

  @override
  String get shareToggleMap => 'Map';

  @override
  String get shareTogglePlace => 'Place';

  @override
  String get shareToggleLogo => 'Logo';

  @override
  String get shareToggleRoute => 'Route';

  @override
  String get shareEditPlaceName => 'Edit place name';

  @override
  String get photoEditTitle => 'Edit photo';

  @override
  String get photoEditReset => 'Reset';

  @override
  String get photoEditTabFilter => 'Filter';

  @override
  String get photoEditTabTemplate => 'Template';

  @override
  String get photoEditTabDisplay => 'Display';

  @override
  String get photoEditTabColor => 'Color';

  @override
  String get shareInkWhite => 'White';

  @override
  String get shareInkBlack => 'Ink black';

  @override
  String get shareInkPurple => 'Purple';

  @override
  String get shareToInstagramStory => 'Share to Instagram Story';

  @override
  String get shareToOtherApps => 'Share to other apps';

  @override
  String get shareSaveToGallery => 'Save to Photos';

  @override
  String get shareStickerHint => 'Drag stickers to move them, pinch to resize';

  @override
  String get poiPickerTitle => 'Choose a place name';

  @override
  String poiPickerDistanceMeters(int meters) {
    return '${meters}m';
  }

  @override
  String get poiPickerNeighborhoodFallback => 'Use neighborhood name';

  @override
  String get poiPickerManualEntry => 'Enter manually';

  @override
  String get poiPickerManualHint => 'Enter a place name';

  @override
  String get poiPickerConfirm => 'Confirm';

  @override
  String get poiPickerNoCandidates => 'Couldn\'t find nearby places';
}
