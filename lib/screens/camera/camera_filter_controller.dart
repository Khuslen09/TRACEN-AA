import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/camera_filter.dart';
import '../../models/capture_ratio.dart';

/// 촬영 화면의 선택 상태(필터/강도/오버레이 토글/비율/그리드) — 화면 scope로만
/// provide(`main.dart`는 안 건드림). [ThemeProvider]와 같은 패턴으로
/// SharedPreferences에 즉시 저장해 다음 촬영에도 마지막 선택이 남는다.
class CameraFilterController extends ChangeNotifier {
  CameraFilterController._(this._selected, this._strengths);

  static const _selectedKey = 'camera_filter_selected';
  static const _strengthPrefix = 'camera_filter_strength_';
  static const _stampKey = 'camera_overlay_stamp';
  static const _routeKey = 'camera_overlay_route';
  static const _watermarkKey = 'camera_overlay_watermark';
  static const _ratioKey = 'camera_ratio';
  static const _gridKey = 'camera_grid';
  static const _mirrorFrontKey = 'camera_mirror_front';

  TracenFilter _selected;
  final Map<TracenFilter, double> _strengths;
  bool _showStamp = true;
  bool _showRoute = true;
  bool _showWatermark = true;
  CaptureRatio _ratio = CaptureRatio.r4x5;
  bool _grid = false;
  bool _mirrorFrontCamera = true;

  static Future<CameraFilterController> load() async {
    final prefs = await SharedPreferences.getInstance();

    final savedId = prefs.getString(_selectedKey);
    final selected = TracenFilter.values.firstWhere(
      (f) => f.id == savedId,
      orElse: () => TracenFilter.defaultFilter,
    );

    final strengths = <TracenFilter, double>{
      for (final f in TracenFilter.values)
        f: prefs.getDouble('$_strengthPrefix${f.id}') ?? TracenFilter.defaultStrength,
    };

    final controller = CameraFilterController._(selected, strengths);
    controller._showStamp = prefs.getBool(_stampKey) ?? true;
    controller._showRoute = prefs.getBool(_routeKey) ?? true;
    controller._showWatermark = prefs.getBool(_watermarkKey) ?? true;
    controller._grid = prefs.getBool(_gridKey) ?? false;
    controller._mirrorFrontCamera = prefs.getBool(_mirrorFrontKey) ?? true;

    final savedRatio = prefs.getString(_ratioKey);
    controller._ratio = CaptureRatio.values.firstWhere(
      (r) => r.name == savedRatio,
      orElse: () => CaptureRatio.r4x5,
    );

    return controller;
  }

  TracenFilter get selected => _selected;
  double get strength => _strengths[_selected] ?? TracenFilter.defaultStrength;
  double strengthOf(TracenFilter f) =>
      _strengths[f] ?? TracenFilter.defaultStrength;
  bool get showStamp => _showStamp;
  bool get showRoute => _showRoute;
  bool get showWatermark => _showWatermark;
  CaptureRatio get ratio => _ratio;
  bool get grid => _grid;
  bool get mirrorFrontCamera => _mirrorFrontCamera;

  Future<void> selectFilter(TracenFilter filter) async {
    _selected = filter;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, filter.id);
  }

  Future<void> setStrength(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    _strengths[_selected] = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_strengthPrefix${_selected.id}', clamped);
  }

  Future<void> toggleStamp() async {
    _showStamp = !_showStamp;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_stampKey, _showStamp);
  }

  Future<void> toggleRoute() async {
    _showRoute = !_showRoute;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_routeKey, _showRoute);
  }

  Future<void> toggleWatermark() async {
    _showWatermark = !_showWatermark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_watermarkKey, _showWatermark);
  }

  Future<void> setRatio(CaptureRatio value) async {
    _ratio = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ratioKey, value.name);
  }

  Future<void> toggleGrid() async {
    _grid = !_grid;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gridKey, _grid);
  }

  Future<void> toggleMirrorFrontCamera() async {
    _mirrorFrontCamera = !_mirrorFrontCamera;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mirrorFrontKey, _mirrorFrontCamera);
  }
}
