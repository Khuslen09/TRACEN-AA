import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pin_category.dart';
import '../theme/app_colors.dart';

/// 카테고리별 색상을 사용자가 커스터마이즈할 수 있게 저장/불러오는 서비스.
///
/// 저장 키: `category_color_{key}` → ARGB int 값
/// 기본값은 PinCategory.defaultColor (보라 기반 팔레트)
class CategoryColorService {
  CategoryColorService._();

  static const _prefix = 'category_color_';

  /// 모든 카테고리의 현재 색상 맵 반환.
  static Future<Map<PinCategory, Color>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <PinCategory, Color>{};
    for (final cat in PinCategory.values) {
      final saved = prefs.getInt('$_prefix${cat.key}');
      result[cat] = saved != null ? Color(saved) : cat.defaultColor;
    }
    return result;
  }

  /// 특정 카테고리 색상 저장.
  static Future<void> save(PinCategory category, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix${category.key}', color.toARGB32());
  }

  /// 특정 카테고리 색상 불러오기 (단건).
  static Future<Color> load(PinCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('$_prefix${category.key}');
    return saved != null ? Color(saved) : category.defaultColor;
  }

  /// 모든 색상 기본값으로 초기화.
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final cat in PinCategory.values) {
      await prefs.remove('$_prefix${cat.key}');
    }
  }
}

/// 앱 전체에서 카테고리 색상을 공유하는 InheritedNotifier.
///
/// HomeScreen, SaveFilesScreen, PinPreviewSheet 등이 모두 같은 색상 맵을 참조.
class CategoryColorNotifier extends ChangeNotifier {
  Map<PinCategory, Color> _colors = {
    for (final c in PinCategory.values) c: c.defaultColor,
  };

  Map<PinCategory, Color> get colors => _colors;

  Color colorOf(PinCategory category) =>
      _colors[category] ?? category.defaultColor;

  /// 앱 시작 시 저장된 색상 로드.
  Future<void> init() async {
    _colors = await CategoryColorService.loadAll();
    notifyListeners();
  }

  /// 특정 카테고리 색상 변경 + 저장.
  Future<void> update(PinCategory category, Color color) async {
    _colors = Map.from(_colors)..[category] = color;
    await CategoryColorService.save(category, color);
    notifyListeners();
  }

  /// 전체 초기화.
  Future<void> reset() async {
    await CategoryColorService.resetAll();
    _colors = {for (final c in PinCategory.values) c: c.defaultColor};
    notifyListeners();
  }
}

/// 색상 팔레트 — 색상 선택기에 보여줄 프리셋.
class ColorPalette {
  static const List<Color> presets = [
    AppColors.primary, // 보라 (기본)
    Color(0xFFEF4444), // 빨강
    Color(0xFFF97316), // 주황
    Color(0xFFF59E0B), // 노랑
    Color(0xFF10B981), // 초록
    Color(0xFF06B6D4), // 청록
    Color(0xFF3B82F6), // 파랑
    Color(0xFF8B5CF6), // 연보라
    Color(0xFFEC4899), // 핑크
    Color(0xFF6B7280), // 회색
    Color(0xFF1F2937), // 진회색
    Colors.white, // 흰색
  ];
}
