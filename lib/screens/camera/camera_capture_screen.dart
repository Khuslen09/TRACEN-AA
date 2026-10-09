import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/camera_filter.dart';
import '../../models/camera_filter_l10n.dart';
import '../../models/capture_ratio.dart';
import '../../services/camera_lens_channel.dart';
import '../../services/lut_shader_service.dart';
import '../../services/permission_service.dart';
import '../../services/tracen_overlay_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/color_matrix_fit.dart';
import 'camera_filter_controller.dart';
import 'photo_edit_screen.dart';

/// TRACEN 시그니처 카메라 — 실시간 미리보기(가벼운 ColorMatrix 근사) +
/// 비율/그리드/노출/초점/전후면/플래시 제어 + 필터 선택.
///
/// 촬영 즉시 [PhotoEditScreen]으로 넘어가 실제 LUT 셰이더로 정확한 결과를
/// 보여준다 — 이 화면의 미리보기는 "비슷한 느낌"만 내는 근사치.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraFilterController? _filterController;
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  FlashMode _flash = FlashMode.off;
  bool _initializing = true;
  // 카메라를 한 번이라도 성공적으로 띄운 적 있는지 — 렌즈/전후면 전환 중엔
  // _camera가 잠깐 null이 되는데, 그때마다 화면 전체를 로딩 스피너로 갈아
  // 치우면 탭 바/필터 스트립까지 다 사라져서 너무 느리게/끊기게 느껴짐.
  // 한 번 띄운 뒤로는 전체 화면 대신 미리보기 영역에만 로딩 상태를 보여줌.
  bool _everOpened = false;
  bool _unavailable = false;
  bool _permissionDenied = false;
  bool _capturing = false;

  Offset? _focusPoint;
  Timer? _focusHideTimer;

  bool _showStrengthSlider = false;
  Timer? _strengthHideTimer;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _pinchBaseZoom = 1.0;
  Map<CameraLensType, double> _androidLensRatios = {};

  bool _showZoomDial = false;
  Timer? _zoomDialHideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 셰이더 프로그램 + 4개 LUT 이미지를 지금부터 디코드해두면, 촬영 후
    // 결과 화면(PhotoEditScreen)에 들어갈 때 이미 캐시돼 있어 체감 로딩이
    // 크게 줄어듦 — 권한/카메라 초기화와 동시에 진행.
    LutShaderService.warmUp();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _filterController = await CameraFilterController.load();
    if (Platform.isAndroid) {
      // 안드로이드는 물리 렌즈 구분이 기기 속성이라 세션과 무관하게 한 번만
      // 조회하면 됨 — 권한/카메라 초기화와 동시에 진행.
      CameraLensChannel.getBackLensZoomRatios().then((ratios) {
        if (mounted) setState(() => _androidLensRatios = ratios);
      });
    }

    var status = await PermissionService.cameraStatus();
    if (status != AppPermissionStatus.granted) {
      status = await PermissionService.requestCamera();
    }
    if (status != AppPermissionStatus.granted) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _initializing = false;
        });
      }
      return;
    }

    try {
      _cameras = await availableCameras();
    } catch (_) {
      _cameras = [];
    }
    if (_cameras.isEmpty) {
      if (mounted) {
        setState(() {
          _unavailable = true;
          _initializing = false;
        });
      }
      return;
    }

    await _openCamera(0);
  }

  Future<void> _openCamera(int index, {double? initialZoom}) async {
    final old = _camera;
    if (old != null) {
      // 새 세션을 열기 전에 기존 세션을 완전히 정리 — iOS에서
      // CameraController 두 개(특히 전/후면이 다르거나 물리 렌즈가 다른
      // 경우)가 동시에 살아있으면 새 세션 초기화가 멎거나 기존 프리뷰가
      // 까맣게 멈추는 문제가 있어서, 화면에서 먼저 떼어내고(_camera = null
      // → build()가 로딩 화면 표시) 완전히 dispose한 다음에 새로 연다.
      if (mounted) setState(() => _camera = null);
      await old.dispose();
    }

    final description = _cameras[index];
    final controller = CameraController(
      description,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    double minZoom = 1.0, maxZoom = 1.0;
    try {
      await controller.initialize();

      // 독립적인 조회는 한꺼번에 — 순차로 하나씩 기다리면 플랫폼 채널
      // 왕복이 쌓여서 전환이 느리게 느껴짐.
      final results = await Future.wait([
        controller.getMinExposureOffset(),
        controller.getExposureOffsetStepSize(),
        controller.getMinZoomLevel(),
        controller.getMaxZoomLevel(),
      ]);
      final minOffset = results[0];
      final step = results[1];
      minZoom = results[2];
      maxZoom = results[3];

      // 기본 노출 보정 -0.3EV — 기기가 지원하는 범위/스텝에 맞춰 보정.
      var target = -0.3;
      if (target < minOffset) target = minOffset;
      if (step > 0) target = (target / step).round() * step;

      final setupFutures = <Future<void>>[
        controller.setExposureOffset(target),
        // 전면 카메라 등 플래시 미지원 렌즈 — 이것 때문에 세션 전체가
        // 실패 처리되면 안 되므로 따로 무시.
        controller.setFlashMode(_flash).catchError((_) {}),
      ];
      if (initialZoom != null) {
        final clamped = initialZoom.clamp(minZoom, maxZoom);
        setupFutures.add(controller.setZoomLevel(clamped));
      }
      await Future.wait(setupFutures);
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _unavailable = true;
          _initializing = false;
        });
      }
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _camera = controller;
      _cameraIndex = index;
      _initializing = false;
      _everOpened = true;
      _minZoom = minZoom;
      _maxZoom = maxZoom;
      _currentZoom = initialZoom?.clamp(minZoom, maxZoom) ??
          (minZoom <= 1.0 && maxZoom >= 1.0 ? 1.0 : minZoom);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _camera;
    if (cam == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _camera = null;
      cam.dispose();
    } else if (state == AppLifecycleState.resumed && _cameras.isNotEmpty) {
      _openCamera(_cameraIndex);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusHideTimer?.cancel();
    _strengthHideTimer?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _onTapFocus(Offset localPosition, Size previewSize) async {
    final cam = _camera;
    if (cam == null || previewSize.width <= 0 || previewSize.height <= 0) {
      return;
    }
    final point = Offset(
      (localPosition.dx / previewSize.width).clamp(0.0, 1.0),
      (localPosition.dy / previewSize.height).clamp(0.0, 1.0),
    );
    setState(() => _focusPoint = localPosition);
    _focusHideTimer?.cancel();
    _focusHideTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _focusPoint = null);
    });
    try {
      if (cam.value.focusPointSupported) await cam.setFocusPoint(point);
      if (cam.value.exposurePointSupported) await cam.setExposurePoint(point);
    } catch (_) {
      // 일부 기기/렌즈는 지원 안 함 — 조용히 무시.
    }
  }

  Future<void> _cycleFlash() async {
    final cam = _camera;
    if (cam == null) return;
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await cam.setFlashMode(next);
      if (mounted) setState(() => _flash = next);
    } catch (_) {}
  }

  /// 전/후면 전환 — `_cameras`엔 후면 렌즈가 여러 개(초광각/표준/망원) 들어
  /// 있을 수 있어서, 그냥 다음 인덱스로 가면 같은 방향의 다른 렌즈로 가버릴
  /// 수 있음. 반대 방향에서 "표준(wide)" 렌즈를 찾아서 그쪽으로 전환.
  /// 미러링은 안 함 — 미리보기도 찍히는 그대로(좌우 반전 없이) 보여줌.
  Future<void> _switchCamera() async {
    final current = _cameras[_cameraIndex];
    final targetDirection = current.lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final candidates = [
      for (var i = 0; i < _cameras.length; i++)
        if (_cameras[i].lensDirection == targetDirection) i,
    ];
    if (candidates.isEmpty) return;
    final wideIndex = candidates.firstWhere(
      (i) => _cameras[i].lensType == CameraLensType.wide,
      orElse: () => candidates.first,
    );
    await _openCamera(wideIndex, initialZoom: 1.0);
  }

  void _onPinchStart() {
    _pinchBaseZoom = _currentZoom;
  }

  Future<void> _onPinchUpdate(double scale) async {
    final cam = _camera;
    if (cam == null) return;
    final target = (_pinchBaseZoom * scale).clamp(_minZoom, _maxZoom);
    if ((target - _currentZoom).abs() < 0.01) return;
    setState(() => _currentZoom = target);
    try {
      await cam.setZoomLevel(target);
    } catch (_) {}
  }

  Future<void> _setZoom(double zoom) async {
    final cam = _camera;
    if (cam == null) return;
    final target = zoom.clamp(_minZoom, _maxZoom);
    setState(() => _currentZoom = target);
    try {
      await cam.setZoomLevel(target);
    } catch (_) {}
  }

  void _toggleZoomDial() {
    setState(() => _showZoomDial = !_showZoomDial);
    _armZoomDialHideTimer();
  }

  void _armZoomDialHideTimer() {
    _zoomDialHideTimer?.cancel();
    if (!_showZoomDial) return;
    _zoomDialHideTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showZoomDial = false);
    });
  }

  /// iOS는 패키지가 이미 후면 렌즈별로 별도 CameraDescription(lensType 포함)을
  /// 주므로 버튼 = 그 렌즈로 카메라 재생성. Android는 CameraX 논리 카메라가
  /// 줌 배율만으로 내부적으로 렌즈를 바꿔주므로(camera_android_camerax가
  /// lensType을 안 채워서 _androidLensRatios로 직접 분류, 버튼 = 그 배율로
  /// setZoomLevel.
  List<_LensOption> _lensOptions() {
    if (_cameras.isEmpty) return const [];
    final current = _cameras[_cameraIndex];
    if (current.lensDirection != CameraLensDirection.back) return const [];

    if (Platform.isIOS) {
      final byType = <CameraLensType, int>{};
      for (var i = 0; i < _cameras.length; i++) {
        final c = _cameras[i];
        if (c.lensDirection != CameraLensDirection.back) continue;
        byType.putIfAbsent(c.lensType, () => i);
      }
      if (byType.length < 2) return const [];
      return [
        for (final type in const [
          CameraLensType.ultraWide,
          CameraLensType.wide,
          CameraLensType.telephoto,
        ])
          if (byType.containsKey(type))
            _LensOption(
              label: _lensLabel(type),
              isSelected: current.lensType == type,
              onSelect: () => _openCamera(byType[type]!, initialZoom: 1.0),
            ),
      ];
    }

    if (Platform.isAndroid && _androidLensRatios.length > 1) {
      return [
        for (final type in const [
          CameraLensType.ultraWide,
          CameraLensType.wide,
          CameraLensType.telephoto,
        ])
          if (_androidLensRatios.containsKey(type))
            _LensOption(
              label: _lensLabel(type, androidRatio: _androidLensRatios[type]),
              isSelected: (_currentZoom - _androidLensRatios[type]!).abs() < 0.05,
              onSelect: () => _setZoom(_androidLensRatios[type]!),
            ),
      ];
    }

    return const [];
  }

  String _lensLabel(CameraLensType type, {double? androidRatio}) {
    if (androidRatio != null) {
      return androidRatio == androidRatio.roundToDouble()
          ? '${androidRatio.toStringAsFixed(0)}x'
          : '${androidRatio.toStringAsFixed(1)}x';
    }
    return switch (type) {
      CameraLensType.ultraWide => '0.5x',
      CameraLensType.telephoto => '3x',
      _ => '1x',
    };
  }

  void _onFilterTap(CameraFilterController controller, TracenFilter filter) {
    if (controller.selected == filter) {
      _toggleStrengthSlider();
    } else {
      controller.selectFilter(filter);
    }
  }

  void _onFilterLongPress(CameraFilterController controller, TracenFilter filter) {
    if (controller.selected != filter) controller.selectFilter(filter);
    _toggleStrengthSlider(forceShow: true);
  }

  void _toggleStrengthSlider({bool forceShow = false}) {
    setState(() => _showStrengthSlider = forceShow || !_showStrengthSlider);
    _armStrengthHideTimer();
  }

  void _armStrengthHideTimer() {
    _strengthHideTimer?.cancel();
    if (!_showStrengthSlider) return;
    _strengthHideTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showStrengthSlider = false);
    });
  }

  Future<void> _capture() async {
    final cam = _camera;
    final filterController = _filterController;
    if (cam == null || filterController == null || _capturing) return;

    setState(() => _capturing = true);
    try {
      final file = await cam.takePicture();
      final overlayFuture = TracenOverlayService.loadToday();
      if (!mounted) return;
      final result = await Navigator.push<({String path, String? placeName})>(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoEditScreen(
            sourcePath: file.path,
            filterController: filterController,
            overlayFuture: overlayFuture,
          ),
        ),
      );
      // 핀 저장 화면 등 결과를 기다리는 호출자가 있으면(이 화면이
      // Navigator.push로 열렸으면) 경로/위치명을 그대로 위로 전달.
      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    } catch (_) {
      // 촬영 실패 — 다시 시도할 수 있게 그냥 화면에 머무름.
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_permissionDenied) return _PermissionNeeded(l10n: l10n);
    if (_unavailable) return _Unavailable(l10n: l10n);

    final cam = _camera;
    final filterController = _filterController;
    // 최초 부팅 중이거나 아직 한 번도 못 띄웠으면(또는 권한/필터 컨트롤러가
    // 아직 준비 안 됐으면) 전체 화면 스피너 — 그 이후엔 cam이 잠깐
    // null이어도(렌즈 전환 중) 전체 UI를 유지하고 미리보기 영역만 로딩
    // 상태를 보여줌(_buildPreviewArea가 처리).
    if (_initializing || filterController == null || (cam == null && !_everOpened)) {
      return const Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return ChangeNotifierProvider.value(
      value: filterController,
      child: Consumer<CameraFilterController>(
        builder: (context, controller, _) => Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(l10n, controller),
                Expanded(child: _buildPreviewArea(cam, controller)),
                _buildLensRow(),
                if (_showZoomDial) _buildZoomDial(),
                if (_showStrengthSlider) _buildStrengthSlider(l10n, controller),
                _buildFilterStrip(cam, controller),
                _buildShutterRow(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n, CameraFilterController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Row(
            children: [
              _TopBarIcon(
                icon: Icons.grid_3x3_rounded,
                active: controller.grid,
                onTap: controller.toggleGrid,
                tooltip: l10n.cameraGrid,
              ),
              const SizedBox(width: 4),
              _RatioButton(controller: controller, label: l10n.cameraRatio),
              const SizedBox(width: 4),
              _TopBarIcon(
                icon: switch (_flash) {
                  FlashMode.off => Icons.flash_off_rounded,
                  FlashMode.auto => Icons.flash_auto_rounded,
                  _ => Icons.flash_on_rounded,
                },
                active: _flash != FlashMode.off,
                onTap: _cycleFlash,
                tooltip: switch (_flash) {
                  FlashMode.off => l10n.cameraFlashOff,
                  FlashMode.auto => l10n.cameraFlashAuto,
                  _ => l10n.cameraFlashOn,
                },
              ),
              const SizedBox(width: 4),
              _TopBarIcon(
                icon: Icons.cameraswitch_rounded,
                active: false,
                onTap: _cameras.length > 1 ? _switchCamera : null,
                tooltip: l10n.cameraSwitch,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(CameraController? cam, CameraFilterController controller) {
    if (cam == null) {
      // 렌즈/전후면 전환 중 — 미리보기 영역에만 로딩 상태, 나머지 UI는 유지.
      return Center(
        child: AspectRatio(
          aspectRatio: controller.ratio.aspect,
          child: const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.ratio.aspect,
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final previewSize = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onTapFocus(d.localPosition, previewSize),
                onDoubleTap: _switchCamera,
                onScaleStart: (_) => _onPinchStart(),
                onScaleUpdate: (d) => _onPinchUpdate(d.scale),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CroppedCameraPreview(controller: cam),
                    ColorFiltered(
                      colorFilter: ColorFilter.matrix(
                        lerpWithIdentity(
                          fitColorMatrix(controller.selected.recipe),
                          controller.strength,
                        ),
                      ),
                      child: _CroppedCameraPreview(controller: cam),
                    ),
                    if (controller.grid) const _GridOverlay(),
                    if (_focusPoint != null) _FocusIndicator(center: _focusPoint!),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLensRow() {
    final options = _lensOptions();
    if (options.isEmpty) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final option in options) ...[
            GestureDetector(
              onTap: option.onSelect,
              onLongPress: _toggleZoomDial,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: option.isSelected
                      ? Colors.white24
                      : Colors.black.withValues(alpha: 0.3),
                  border: Border.all(
                    color: option.isSelected ? Colors.white : Colors.white38,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  option.label,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: option.isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildZoomDial() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Text(
            '${_currentZoom.toStringAsFixed(1)}x',
            style: AppTextStyles.caption.copyWith(color: Colors.white70),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _currentZoom,
                min: _minZoom,
                max: _maxZoom,
                onChanged: (v) {
                  _setZoom(v);
                  _armZoomDialHideTimer();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthSlider(AppLocalizations l10n, CameraFilterController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Text(
            l10n.filterStrength,
            style: AppTextStyles.caption.copyWith(color: Colors.white70),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: controller.strength,
                onChanged: (v) {
                  controller.setStrength(v);
                  _armStrengthHideTimer();
                },
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${(controller.strength * 100).round()}%',
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterStrip(CameraController? cam, CameraFilterController controller) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: TracenFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final filter = TracenFilter.values[i];
          final isSelected = controller.selected == filter;
          return GestureDetector(
            onTap: () => _onFilterTap(controller, filter),
            onLongPress: () => _onFilterLongPress(controller, filter),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.white24,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: ClipOval(
                    child: cam == null
                        ? const ColoredBox(color: Colors.white10)
                        : ColorFiltered(
                            colorFilter: ColorFilter.matrix(
                              lerpWithIdentity(
                                fitColorMatrix(filter.recipe),
                                controller.strengthOf(filter),
                              ),
                            ),
                            child: _CroppedCameraPreview(controller: cam),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  filter.label(l10n),
                  style: AppTextStyles.caption.copyWith(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShutterRow(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: GestureDetector(
          onTap: _capturing ? null : _capture,
          child: Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _capturing ? Colors.white38 : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [CameraPreview]는 센서의 네이티브 비율로 자기 자신을 AspectRatio로
/// 감싸버려서, 우리가 원하는 비율(4:5/1:1/9:16)로 보여주려면 그 위에
/// FittedBox(cover)로 한 번 더 감싸 크롭해야 함.
class _CroppedCameraPreview extends StatelessWidget {
  final CameraController controller;
  const _CroppedCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return const SizedBox.expand();
    // previewSize는 기기 방향과 무관하게 센서의 가로 기준으로 오는 경우가
    // 많아서(가로/세로가 실제 화면과 반대) 세로 모드 기준으로 맞바꿔 씀.
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FocusIndicator extends StatelessWidget {
  final Offset center;
  const _FocusIndicator({required this.center});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - 32,
      top: center.dy - 32,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.3, end: 1.0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _LensOption {
  final String label;
  final bool isSelected;
  final Future<void> Function() onSelect;

  const _LensOption({
    required this.label,
    required this.isSelected,
    required this.onSelect,
  });
}

class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  final String tooltip;

  const _TopBarIcon({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: active ? AppColors.primary : Colors.white),
        onPressed: onTap,
      ),
    );
  }
}

class _RatioButton extends StatelessWidget {
  final CameraFilterController controller;
  final String label;
  const _RatioButton({required this.controller, required this.label});

  String _labelFor(CaptureRatio r) => switch (r) {
    CaptureRatio.r4x5 => '4:5',
    CaptureRatio.r1x1 => '1:1',
    CaptureRatio.r9x16 => '9:16',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CaptureRatio>(
      tooltip: label,
      initialValue: controller.ratio,
      onSelected: controller.setRatio,
      color: AppColors.darkSurface,
      itemBuilder: (context) => [
        for (final r in CaptureRatio.values)
          PopupMenuItem(
            value: r,
            child: Text(
              _labelFor(r),
              style: TextStyle(
                color: r == controller.ratio ? AppColors.primary : Colors.white,
              ),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(
          _labelFor(controller.ratio),
          style: AppTextStyles.smallBold.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _PermissionNeeded extends StatelessWidget {
  final AppLocalizations l10n;
  const _PermissionNeeded({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              Text(
                l10n.cameraPermissionNeeded,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: PermissionService.openSettings,
                child: Text(l10n.permOpenSettings),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel, style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  final AppLocalizations l10n;
  const _Unavailable({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              l10n.cameraUnavailable,
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
