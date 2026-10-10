import '../l10n/strings.dart';

/// 핀 공유 카드 템플릿.
///
/// [original]은 템플릿 없이 사진만 — 스티커·어둡게 깔리는 스크림 모두 없음.
enum ShareCardTemplate {
  original,
  minimal,
  film,
  stamp;

  /// 현재 앱 언어의 표시 이름. [PinCategory.label]과 같은 패턴.
  String get label => switch (this) {
    ShareCardTemplate.original => Strings.current.shareTemplateOriginal,
    ShareCardTemplate.minimal => Strings.current.shareTemplateMinimal,
    ShareCardTemplate.film => Strings.current.shareTemplateFilm,
    ShareCardTemplate.stamp => Strings.current.shareTemplateStamp,
  };
}
