import 'dart:ui' as ui;

import '../../models/country_outline.dart';
import '../../models/share_card_template.dart';
import '../../models/share_ink_color.dart';
import '../../models/sticker_id.dart';
import '../../models/sticker_transform.dart';

/// [ShareCard]가 그리는 데 필요한 모든 데이터의 불변 스냅샷 —
/// [ShareCardController]가 조립해서 돌려준다. 미리보기와 내보내기 인스턴스가
/// 완전히 같은 스냅샷을 씀.
class ShareCardViewModel {
  final ShareCardTemplate template;
  final ShareInkColor inkColor;
  final DateTime date;
  final double pinLat;
  final double pinLng;
  final String? placeName;
  final CountryOutline? countryOutline;

  /// 미리 디코드된 핀 사진 — 미리보기/내보내기가 디코드를 공유해 중복 작업 없음.
  /// null이면 사진 없는 핀(단색 배경으로 렌더).
  final ui.Image? photo;

  final Map<StickerId, bool> visibility;
  final Map<StickerId, StickerTransform> transforms;

  const ShareCardViewModel({
    required this.template,
    required this.inkColor,
    required this.date,
    required this.pinLat,
    required this.pinLng,
    required this.placeName,
    required this.countryOutline,
    required this.photo,
    required this.visibility,
    required this.transforms,
  });

  bool isVisible(StickerId id) => visibility[id] ?? true;

  StickerTransform transformOf(StickerId id) => transforms[id] ?? const StickerTransform.identity();
}
