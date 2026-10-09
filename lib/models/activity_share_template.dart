import '../l10n/strings.dart';

/// 러닝/워킹/사이클링 기록 공유 카드 템플릿.
///
/// - [route]: 경로를 크게 그린 아트 카드
/// - [stats]: 거리 숫자를 크게 강조한 기록 카드
/// - [photo]: 여정 중 찍은 사진 위에 경로·기록을 얹은 카드(사진 있을 때만)
/// - [sticker]: 배경 없는 투명 PNG — 인스타 스토리에서 다른 사진 위에 붙이는 용도
enum ActivityShareTemplate {
  route,
  stats,
  photo,
  sticker;

  String get label => switch (this) {
    ActivityShareTemplate.route => Strings.current.activityShareTemplateRoute,
    ActivityShareTemplate.stats => Strings.current.activityShareTemplateStats,
    ActivityShareTemplate.photo => Strings.current.activityShareTemplatePhoto,
    ActivityShareTemplate.sticker =>
      Strings.current.activityShareTemplateSticker,
  };
}
