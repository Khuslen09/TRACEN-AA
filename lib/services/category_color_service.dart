import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pin_category.dart';
import '../theme/app_colors.dart';

/// 카테고리별 색상/아이콘/이름을 사용자가 커스터마이즈할 수 있게
/// 저장/불러오는 서비스.
///
/// 저장 키:
///   `category_color_{key}` → ARGB int
///   `category_icon_{key}`  → [CategoryIconCatalog]의 문자열 키
///   `category_name_{key}`  → 사용자가 입력한 이름 (비우면 삭제 = 기본값)
///
/// 기본값은 각각 [PinCategory.defaultColor]/[PinCategory.icon]/
/// [PinCategory.label].
class CategoryColorService {
  CategoryColorService._();

  static const _colorPrefix = 'category_color_';
  static const _iconPrefix = 'category_icon_';
  static const _namePrefix = 'category_name_';

  static Future<Map<PinCategory, Color>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <PinCategory, Color>{};
    for (final cat in PinCategory.values) {
      final saved = prefs.getInt('$_colorPrefix${cat.key}');
      result[cat] = saved != null ? Color(saved) : cat.defaultColor;
    }
    return result;
  }

  static Future<void> saveColor(PinCategory category, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_colorPrefix${category.key}', color.toARGB32());
  }

  static Future<Map<PinCategory, IconData>> loadAllIcons() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <PinCategory, IconData>{};
    for (final cat in PinCategory.values) {
      final savedKey = prefs.getString('$_iconPrefix${cat.key}');
      result[cat] = CategoryIconCatalog.byKey(savedKey) ?? cat.icon;
    }
    return result;
  }

  static Future<void> saveIcon(PinCategory category, String iconKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_iconPrefix${category.key}', iconKey);
  }

  static Future<Map<PinCategory, String?>> loadAllNames() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <PinCategory, String?>{};
    for (final cat in PinCategory.values) {
      result[cat] = prefs.getString('$_namePrefix${cat.key}');
    }
    return result;
  }

  /// 빈 문자열이면 커스텀 이름을 지워 기본값(언어별 라벨)으로 되돌림.
  static Future<void> saveName(PinCategory category, String name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name.trim().isEmpty) {
      await prefs.remove('$_namePrefix${category.key}');
    } else {
      await prefs.setString('$_namePrefix${category.key}', name.trim());
    }
  }

  /// 모든 커스터마이즈(색상/아이콘/이름) 기본값으로 초기화.
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final cat in PinCategory.values) {
      await prefs.remove('$_colorPrefix${cat.key}');
      await prefs.remove('$_iconPrefix${cat.key}');
      await prefs.remove('$_namePrefix${cat.key}');
    }
  }
}

/// 카테고리 아이콘으로 고를 수 있는 아이콘 모음.
///
/// 코드포인트를 그대로 저장하지 않고 안정적인 문자열 키로 저장 —
/// Material 아이콘 폰트 버전이 바뀌어도 매핑이 깨지지 않게.
class CategoryIconCatalog {
  CategoryIconCatalog._();

  static const Map<String, IconData> all = {
    'place': Icons.place_rounded,
    'restaurant': Icons.restaurant_rounded,
    'camera': Icons.photo_camera_rounded,
    'cafe': Icons.local_cafe_rounded,
    'fitness': Icons.fitness_center_rounded,
    'edit_note': Icons.edit_note_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'bar': Icons.local_bar_rounded,
    'hotel': Icons.hotel_rounded,
    'hospital': Icons.local_hospital_rounded,
    'school': Icons.school_rounded,
    'nature': Icons.park_rounded,
    'pets': Icons.pets_rounded,
    'beach': Icons.beach_access_rounded,
    'gas_station': Icons.local_gas_station_rounded,
    'car': Icons.directions_car_rounded,
    'music': Icons.music_note_rounded,
    'celebration': Icons.celebration_rounded,
    'star': Icons.star_rounded,
    'favorite': Icons.favorite_rounded,
    'home': Icons.home_rounded,
    'work': Icons.work_rounded,
  };

  static IconData? byKey(String? key) => key == null ? null : all[key];

  /// 역조회 — 지금 선택된 IconData가 카탈로그의 어떤 키인지.
  /// (카탈로그 밖 아이콘이면 null — 저장 전이라 일어날 일 없음)
  static String? keyOf(IconData icon) {
    for (final entry in all.entries) {
      if (entry.value == icon) return entry.key;
    }
    return null;
  }
}

/// 앱 전체에서 카테고리 커스터마이즈(색상/아이콘/이름)를 공유하는 Notifier.
///
/// HomeScreen, SaveFilesScreen, PinPreviewSheet 등이 모두 같은 값을 참조.
class CategoryColorNotifier extends ChangeNotifier {
  Map<PinCategory, Color> _colors = {
    for (final c in PinCategory.values) c: c.defaultColor,
  };
  Map<PinCategory, IconData> _icons = {
    for (final c in PinCategory.values) c: c.icon,
  };
  Map<PinCategory, String?> _names = {};

  Map<PinCategory, Color> get colors => _colors;

  Color colorOf(PinCategory category) =>
      _colors[category] ?? category.defaultColor;

  IconData iconOf(PinCategory category) => _icons[category] ?? category.icon;

  /// 커스텀 이름이 있으면 그걸, 없으면 언어별 기본 라벨([Strings.current] 기반).
  String labelOf(PinCategory category) {
    final custom = _names[category];
    if (custom != null && custom.isNotEmpty) return custom;
    return category.label;
  }

  /// 앱 시작 시 저장된 커스터마이즈 로드.
  Future<void> init() async {
    _colors = await CategoryColorService.loadAll();
    _icons = await CategoryColorService.loadAllIcons();
    _names = await CategoryColorService.loadAllNames();
    notifyListeners();
  }

  Future<void> updateColor(PinCategory category, Color color) async {
    _colors = Map.from(_colors)..[category] = color;
    await CategoryColorService.saveColor(category, color);
    notifyListeners();
  }

  Future<void> updateIcon(PinCategory category, String iconKey) async {
    final icon = CategoryIconCatalog.byKey(iconKey);
    if (icon == null) return;
    _icons = Map.from(_icons)..[category] = icon;
    await CategoryColorService.saveIcon(category, iconKey);
    notifyListeners();
  }

  /// 빈 문자열이면 기본 라벨로 되돌림.
  Future<void> updateName(PinCategory category, String name) async {
    _names = Map.from(_names)
      ..[category] = name.trim().isEmpty ? null : name.trim();
    await CategoryColorService.saveName(category, name);
    notifyListeners();
  }

  Future<void> reset() async {
    await CategoryColorService.resetAll();
    _colors = {for (final c in PinCategory.values) c: c.defaultColor};
    _icons = {for (final c in PinCategory.values) c: c.icon};
    _names = {};
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
