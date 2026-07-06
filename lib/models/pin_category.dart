import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 핀 카테고리.
///
/// 사용자가 핀 추가 시 선택. 지도에서 색상별 마커로 시각적 구분.
/// 카테고리 변경 시 DB 마이그레이션 불필요 — 새 enum 값만 추가하면 됨.
///
/// `key`는 DB에 저장되는 문자열 식별자. enum 이름이 바뀌어도 안전하도록
/// 명시적으로 지정.
enum PinCategory {
  general('general', '일반', Icons.place_rounded),
  food('food', '음식', Icons.restaurant_rounded),
  scenery('scenery', '명소', Icons.photo_camera_rounded),
  cafe('cafe', '카페', Icons.local_cafe_rounded),
  workout('workout', '운동', Icons.fitness_center_rounded),
  memo('memo', '메모', Icons.edit_note_rounded);

  final String key;
  final String label;
  final IconData icon;

  const PinCategory(this.key, this.label, this.icon);

  /// DB에서 읽은 문자열을 enum으로 변환. 알 수 없으면 general.
  static PinCategory fromKey(String? key) {
    if (key == null || key.isEmpty) return PinCategory.general;
    for (final c in PinCategory.values) {
      if (c.key == key) return c;
    }
    return PinCategory.general;
  }

  /// 기본 색상 — 사용자가 커스터마이즈하지 않았을 때.
  /// general 포함 모든 기본은 보라 계열 또는 앱 팔레트 색.
  Color get defaultColor {
    switch (this) {
      case PinCategory.general:
        return AppColors.primary; // 보라 (기본)
      case PinCategory.food:
        return const Color(0xFFEF4444); // 빨강
      case PinCategory.scenery:
        return const Color(0xFF10B981); // 초록
      case PinCategory.cafe:
        return const Color(0xFFF59E0B); // 주황
      case PinCategory.workout:
        return const Color(0xFF06B6D4); // 청록
      case PinCategory.memo:
        return const Color(0xFF8B5CF6); // 연보라
    }
  }

  /// UI 표시용 색상 — CategoryColorService가 없을 때 fallback.
  Color get color => defaultColor;

  /// BitmapDescriptor.defaultMarkerWithHue()에 전달할 색상 hue (0–360).
  /// defaultColor의 HSV hue 값을 추출.
  double get markerHue => HSVColor.fromColor(defaultColor).hue;
}
