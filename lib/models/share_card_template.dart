import '../l10n/strings.dart';

/// 핀 공유 카드 템플릿 3종.
enum ShareCardTemplate {
  minimal,
  film,
  stamp;

  /// 현재 앱 언어의 표시 이름. [PinCategory.label]과 같은 패턴.
  String get label => switch (this) {
    ShareCardTemplate.minimal => Strings.current.shareTemplateMinimal,
    ShareCardTemplate.film => Strings.current.shareTemplateFilm,
    ShareCardTemplate.stamp => Strings.current.shareTemplateStamp,
  };
}
