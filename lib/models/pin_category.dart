import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_colors.dart';

/// 핀 카테고리.
///
/// 사용자가 핀 추가 시 선택. 지도에서 색상별 마커로 시각적 구분.
///
/// 기본 6종([builtIns])에 더해 사용자가 직접 추가한 카테고리([isCustom])도
/// 있다 — 그래서 enum이 아니라 클래스. 추가 카테고리의 이름/아이콘/색상은
/// `CategoryColorService`에 저장되고, 앱 시작 시 `CategoryColorNotifier`가
/// [setCustom]으로 등록한다.
///
/// `key`는 DB에 저장되는 문자열 식별자. 같은 key면 같은 카테고리(== 비교).
@immutable
class PinCategory {
  final String key;
  final IconData icon;

  /// 기본 색상 — 사용자가 커스터마이즈하지 않았을 때.
  final Color defaultColor;

  const PinCategory._(this.key, this.icon, this.defaultColor);

  static const general = PinCategory._(
    'general',
    Icons.place_rounded,
    AppColors.primary, // 보라 (기본)
  );
  static const food = PinCategory._(
    'food',
    Icons.restaurant_rounded,
    Color(0xFFEF4444), // 빨강
  );
  static const scenery = PinCategory._(
    'scenery',
    Icons.photo_camera_rounded,
    Color(0xFF10B981), // 초록
  );
  static const cafe = PinCategory._(
    'cafe',
    Icons.local_cafe_rounded,
    Color(0xFFF59E0B), // 주황
  );
  static const workout = PinCategory._(
    'workout',
    Icons.fitness_center_rounded,
    Color(0xFF06B6D4), // 청록
  );
  static const memo = PinCategory._(
    'memo',
    Icons.edit_note_rounded,
    Color(0xFF8B5CF6), // 연보라
  );

  static const List<PinCategory> builtIns = [
    general,
    food,
    scenery,
    cafe,
    workout,
    memo,
  ];

  /// 사용자가 추가한 카테고리 key의 접두사.
  static const customKeyPrefix = 'custom_';

  /// 사용자 추가 카테고리 — 실제 이름/아이콘/색상은 CategoryColorNotifier가
  /// 들고 있고, 여기 값은 그게 없을 때의 대체값.
  const PinCategory.custom(String key)
    : this._(key, Icons.place_rounded, AppColors.primary);

  static List<PinCategory> _custom = const [];

  /// 선택 칩·편집 화면에 보여줄 전체 목록 — 기본 6종 뒤에 추가한 것들.
  static List<PinCategory> get values => [...builtIns, ..._custom];

  /// CategoryColorNotifier가 저장된 추가 카테고리를 등록할 때 호출.
  static void setCustom(Iterable<String> keys) {
    _custom = List.unmodifiable([for (final k in keys) PinCategory.custom(k)]);
  }

  bool get isCustom => !builtIns.contains(this);

  /// 현재 앱 언어의 기본 이름. 추가 카테고리의 실제 이름은
  /// CategoryColorNotifier.labelOf가 돌려준다 — 여기선 대체값으로 "일반".
  String get label => switch (key) {
    'food' => Strings.current.catFood,
    'scenery' => Strings.current.catScenery,
    'cafe' => Strings.current.catCafe,
    'workout' => Strings.current.catWorkout,
    'memo' => Strings.current.catMemo,
    _ => Strings.current.catGeneral,
  };

  /// DB에서 읽은 문자열을 카테고리로 변환. 비어있으면 general.
  ///
  /// 모르는 key(삭제했거나 아직 등록 전인 추가 카테고리)도 general로 바꾸지
  /// 않고 key를 살려둔다 — 핀을 다시 저장해도 원래 카테고리가 지워지지 않게.
  /// 화면에선 대체값(일반 아이콘·보라)으로 보인다.
  static PinCategory fromKey(String? key) {
    if (key == null || key.isEmpty) return general;
    for (final c in values) {
      if (c.key == key) return c;
    }
    return PinCategory.custom(key);
  }

  /// UI 표시용 색상 — CategoryColorService가 없을 때 fallback.
  Color get color => defaultColor;

  /// BitmapDescriptor.defaultMarkerWithHue()에 전달할 색상 hue (0–360).
  /// defaultColor의 HSV hue 값을 추출.
  double get markerHue => HSVColor.fromColor(defaultColor).hue;

  @override
  bool operator ==(Object other) => other is PinCategory && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'PinCategory($key)';
}
