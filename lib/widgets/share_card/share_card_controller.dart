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
///
/// 두 가지 경로로 만들어짐: 저장된 핀에서([forPin], `PinPreviewSheet`의 공유
/// 버튼) 또는 방금 찍은 사진에서([forCapture], `PhotoEditScreen`의 "템플릿"
/// 섹션 — 아직 DB에 저장된 Pin이 없으므로 위치/사진을 직접 받음).
class ShareCardController extends ChangeNotifier {
  ShareCardController._({
    required this.lat,
    required this.lng,
    required this.date,
    required ui.Image? photo,
    required CountryOutline? countryOutline,
    required String? placeName,
    bool defaultVisible = true,
  }) : _photo = photo,
       _countryOutline = countryOutline,
       _placeName = placeName,
       _visibility = {for (final id in StickerId.values) id: defaultVisible};

  final double lat;
  final double lng;
  final DateTime date;

  ShareCardTemplate _template = ShareCardTemplate.minimal;
  ShareInkColor _inkColor = ShareInkColor.white;
  final Map<StickerId, bool> _visibility;
  final Map<StickerId, StickerTransform> _overrides = {};
  StickerId? _selectedSticker;

  ui.Image? _photo;
  final CountryOutline? _countryOutline;
  final String? _placeName;

  /// 핀치 제스처의 누적 배율(`ScaleUpdateDetails.scale`)을 제스처 시작 시의
  /// 배율에 곱해야 올바르므로, 제스처가 시작될 때 스냅샷을 떠 둔다.
  final Map<StickerId, StickerTransform> _gestureStartTransforms = {};

  /// 저장된 핀에서 — 모든 스티커가 기본으로 보임(이 화면 자체가 "공유 카드
  /// 만들기"라서).
  static Future<ShareCardController> forPin(Pin pin) async {
    final results = await Future.wait([
      _decodePhoto(pin.photoPath),
      CountryOutlineService.findCountryAt(pin.lat, pin.lng),
      PlaceNameService.placeNameFor(pin.lat, pin.lng),
    ]);
    return ShareCardController._(
      lat: pin.lat,
      lng: pin.lng,
      date: pin.createdAt,
      photo: results[0] as ui.Image?,
      countryOutline: results[1] as CountryOutline?,
      placeName: results[2] as String?,
    );
  }

  /// 방금 촬영한 사진에서 — 아직 저장된 Pin이 없어 위치/사진을 직접 받고,
  /// [photo]는 호출부(`PhotoEditScreen`)가 이미 디코드해서 넘겨준다(보통
  /// TRACEN 필터가 적용된 결과물). 스티커는 기존 촬영 플로우를 방해하지
  /// 않도록 기본으로 전부 꺼져 있음 — 사용자가 "템플릿" 섹션을 실제로
  /// 건드려야(스티커를 켜야) 최종 저장/공유에 반영됨.
  static Future<ShareCardController> forCapture({
    required double lat,
    required double lng,
    required DateTime date,
    required ui.Image photo,
  }) async {
    final results = await Future.wait([
      CountryOutlineService.findCountryAt(lat, lng),
      PlaceNameService.placeNameFor(lat, lng),
    ]);
    return ShareCardController._(
      lat: lat,
      lng: lng,
      date: date,
      photo: photo,
      countryOutline: results[0] as CountryOutline?,
      placeName: results[1] as String?,
      defaultVisible: false,
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

  /// 스티커 중 하나라도 켜져 있으면(= 사용자가 템플릿을 실제로 쓰기로 함).
  bool get hasAnyStickerVisible => StickerId.values.any(isVisible);

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

  /// TRACEN 필터가 다시 적용된 새 배경 사진으로 갱신([PhotoEditScreen]에서
  /// 필터/강도를 바꿀 때마다) — 템플릿/스티커 상태는 그대로 유지.
  void updatePhoto(ui.Image newPhoto) {
    final old = _photo;
    _photo = newPhoto;
    notifyListeners();
    old?.dispose();
  }

  ShareCardViewModel get viewModel => ShareCardViewModel(
    template: _template,
    inkColor: _inkColor,
    date: date,
    pinLat: lat,
    pinLng: lng,
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
