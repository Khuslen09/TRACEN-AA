import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../models/country_outline.dart';
import '../../models/pin.dart';
import '../../models/share_card_template.dart';
import '../../models/share_ink_color.dart';
import '../../models/sticker_id.dart';
import '../../models/sticker_transform.dart';
import '../../services/country_outline_service.dart';
import '../../services/place_name_service.dart';
import 'share_card_layout.dart';
import 'share_card_view_model.dart';

/// 공유 카드 편집 화면 전용 [ChangeNotifier] — `CameraFilterController`와
/// 같은 화면 전용 상태 패턴. SharedPreferences 영속화는 안 함(세션 한정).
class ShareCardController extends ChangeNotifier {
  ShareCardController._({
    required this.pin,
    required ui.Image? photo,
    required CountryOutline? countryOutline,
    required String? placeName,
  }) : _photo = photo,
       _countryOutline = countryOutline,
       _placeName = placeName;

  final Pin pin;

  ShareCardTemplate _template = ShareCardTemplate.minimal;
  ShareInkColor _inkColor = ShareInkColor.white;
  final Map<StickerId, bool> _visibility = {for (final id in StickerId.values) id: true};
  final Map<StickerId, StickerTransform> _overrides = {};
  StickerId? _selectedSticker;

  final ui.Image? _photo;
  final CountryOutline? _countryOutline;
  final String? _placeName;

  /// 핀치 제스처의 누적 배율(`ScaleUpdateDetails.scale`)을 제스처 시작 시의
  /// 배율에 곱해야 올바르므로, 제스처가 시작될 때 스냅샷을 떠 둔다.
  final Map<StickerId, StickerTransform> _gestureStartTransforms = {};

  static Future<ShareCardController> load(Pin pin) async {
    final results = await Future.wait([
      _decodePhoto(pin.photoPath),
      CountryOutlineService.findCountryAt(pin.lat, pin.lng),
      PlaceNameService.placeNameFor(pin.lat, pin.lng),
    ]);
    return ShareCardController._(
      pin: pin,
      photo: results[0] as ui.Image?,
      countryOutline: results[1] as CountryOutline?,
      placeName: results[2] as String?,
    );
  }

  static Future<ui.Image?> _decodePhoto(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1200);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  ShareCardTemplate get template => _template;
  ShareInkColor get inkColor => _inkColor;
  StickerId? get selectedSticker => _selectedSticker;

  void setTemplate(ShareCardTemplate value) {
    if (_template == value) return;
    _template = value;
    _overrides.clear();
    _selectedSticker = null;
    notifyListeners();
  }

  void setInkColor(ShareInkColor value) {
    _inkColor = value;
    notifyListeners();
  }

  bool isVisible(StickerId id) => _visibility[id] ?? true;

  void toggleVisibility(StickerId id) {
    _visibility[id] = !(isVisible(id));
    notifyListeners();
  }

  void selectSticker(StickerId? id) {
    _selectedSticker = id;
    notifyListeners();
  }

  StickerTransform transformFor(StickerId id) =>
      _overrides[id] ?? ShareCardLayout.defaultsFor(_template)[id]!;

  void beginStickerGesture(StickerId id) {
    _gestureStartTransforms[id] = transformFor(id);
  }

  void updateStickerGesture(StickerId id, ui.Offset focalPointDelta, double cumulativeScale) {
    final start = _gestureStartTransforms[id] ?? transformFor(id);
    final current = transformFor(id);
    final newScale = (start.scale * cumulativeScale).clamp(0.4, 3.0);
    _overrides[id] = current.copyWith(
      offset: current.offset + focalPointDelta,
      scale: newScale,
    );
    notifyListeners();
  }

  ShareCardViewModel get viewModel => ShareCardViewModel(
    template: _template,
    inkColor: _inkColor,
    date: pin.createdAt,
    pinLat: pin.lat,
    pinLng: pin.lng,
    placeName: _placeName,
    countryOutline: _countryOutline,
    photo: _photo,
    visibility: Map.unmodifiable(_visibility),
    transforms: {for (final id in StickerId.values) id: transformFor(id)},
  );

  @override
  void dispose() {
    _photo?.dispose();
    super.dispose();
  }
}
