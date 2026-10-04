import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/camera_filter.dart';
import '../../models/camera_filter_l10n.dart';
import '../../models/capture_ratio.dart';
import '../../services/lut_shader_service.dart';
import '../../services/permission_service.dart';
import '../../services/tracen_overlay_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/color_matrix_fit.dart';
import '../../utils/tracen_overlay_painter.dart';
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
  bool _unavailable = false;
  bool _permissionDenied = false;
  bool _capturing = false;

  Offset? _focusPoint;
  Timer? _focusHideTimer;

  bool _showStrengthSlider = false;
  Timer? _strengthHideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TracenOverlayPainter.ensureAssets();
    // 셰이더 프로그램 + 4개 LUT 이미지를 지금부터 디코드해두면, 촬영 후
    // 결과 화면(PhotoEditScreen)에 들어갈 때 이미 캐시돼 있어 체감 로딩이
    // 크게 줄어듦 — 권한/카메라 초기화와 동시에 진행.
    LutShaderService.warmUp();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _filterController = await CameraFilterController.load();

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

  Future<void> _openCamera(int index) async {
    final old = _camera;
    final description = _cameras[index];
    final controller = CameraController(
      description,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();

      // 기본 노출 보정 -0.3EV — 기기가 지원하는 범위/스텝에 맞춰 보정.
      final minOffset = await controller.getMinExposureOffset();
      final step = await controller.getExposureOffsetStepSize();
      var target = -0.3;
      if (target < minOffset) target = minOffset;
      if (step > 0) target = (target / step).round() * step;
      await controller.setExposureOffset(target);
      await controller.setFlashMode(_flash);
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

    await old?.dispose();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _camera = controller;
      _cameraIndex = index;
      _initializing = false;
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

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    setState(() => _initializing = true);
    await _openCamera(next);
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
      final resultPath = await Navigator.push<String>(
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
      // Navigator.push<String>로 열렸으면) 그 경로를 그대로 위로 전달.
      if (resultPath != null && mounted) {
        Navigator.pop(context, resultPath);
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
    if (_initializing || cam == null || filterController == null) {
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

  Widget _buildPreviewArea(CameraController cam, CameraFilterController controller) {
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

  Widget _buildFilterStrip(CameraController cam, CameraFilterController controller) {
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
                    child: ColorFiltered(
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
