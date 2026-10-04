/// 앱 언어(ko/en/mn)를 `geocoding` 패키지의 `setLocaleIdentifier`가 기대하는
/// 로케일 식별자로 매핑. 기기 언어가 아니라 **앱 설정 언어**를 따라가게 하는
/// 게 사용자 결정 사항 — [TracenOverlayService]와 [PlaceNameService]가 공유.
String geocodingLocaleFor(String appLocale) => switch (appLocale) {
  'ko' => 'ko_KR',
  'mn' => 'mn_MN',
  _ => 'en_US',
};
