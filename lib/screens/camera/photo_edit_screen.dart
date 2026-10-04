import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/camera_filter.dart';
import '../../models/camera_filter_l10n.dart';
import '../../models/tracen_overlay_data.dart';
import '../../services/filtered_photo_renderer.dart';
import '../../services/lut_shader_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/tracen_overlay_painter.dart';
import 'camera_filter_controller.dart';

/// 촬영 후 미리보기 — 실제 LUT 셰이더로 정확한 결과를 보여주고, 필터/강도/
/// 오버레이 토글을 조정한 뒤 저장(갤러리)하거나 공유한다.
class PhotoEditScreen extends StatefulWidget {
  final String sourcePath;
  final CameraFilterController filterController;
  final Future<TracenOverlayData> overlayFuture;

  const PhotoEditScreen({
    super.key,
    required this.sourcePath,
    required this.filterController,
    required this.overlayFuture,
  });

  @override
  State<PhotoEditScreen> createState() => _PhotoEditScreenState();
}

class _PhotoEditScreenState extends State<PhotoEditScreen> {
  final _shareButtonKey = GlobalKey();

  ui.Image? _source;
  TracenOverlayData? _overlay;
  ui.FragmentShader? _previewShader;
  final Map<TracenFilter, ui.Image> _thumbnails = {};
  bool _loading = true;
  bool _busy = false;
  int _shaderGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.filterController.addListener(_onControllerChanged);
    _init();
  }

  Future<void> _init() async {
    final bytes = await File(widget.sourcePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1600);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() {
      _source = frame.image;
      _loading = false;
    });

    unawaited(_updatePreviewShader());
    unawaited(_rebuildAllThumbnails());

    widget.overlayFuture.then((data) {
      if (mounted) setState(() => _overlay = data);
    });
  }

  void _onControllerChanged() {
    unawaited(_updatePreviewShader());
  }

  Rect _squareCropUv(ui.Image image) {
    if (image.width > image.height) {
      final side = image.height / image.width;
      return Rect.fromLTWH((1 - side) / 2, 0, side, 1);
    }
    final side = image.width / image.height;
    return Rect.fromLTWH(0, (1 - side) / 2, 1, side);
  }

  Future<void> _updatePreviewShader() async {
    final source = _source;
    if (source == null) return;
    final generation = ++_shaderGeneration;
    final controller = widget.filterController;

    final cropUv = _fullCropUvFor(source, controller);
    final outW = (source.width * cropUv.width).round().clamp(1, source.width);
    final outH = (source.height * cropUv.height).round().clamp(1, source.height);

    final shader = await LutShaderService.configure(
      filter: controller.selected,
      source: source,
      outSize: Size(outW.toDouble(), outH.toDouble()),
      srcRectUv: cropUv,
      strength: controller.strength,
    );
    if (generation != _shaderGeneration || !mounted) {
      shader.dispose();
      return;
    }
    final old = _previewShader;
    setState(() => _previewShader = shader);
    old?.dispose();
  }

  Rect _fullCropUvFor(ui.Image image, CameraFilterController controller) {
    final targetAspect = controller.ratio.aspect;
    final srcAspect = image.width / image.height;
    double w, h, x, y;
    if (srcAspect > targetAspect) {
      h = 1.0;
      w = targetAspect / srcAspect;
      x = (1.0 - w) / 2;
      y = 0.0;
    } else {
      w = 1.0;
      h = srcAspect / targetAspect;
      y = (1.0 - h) / 2;
      x = 0.0;
    }
    return Rect.fromLTWH(x, y, w, h);
  }

  Future<void> _rebuildAllThumbnails() async {
    final source = _source;
    if (source == null) return;
    final cropUv = _squareCropUv(source);
    for (final filter in TracenFilter.values) {
      final shader = await LutShaderService.configure(
        filter: filter,
        source: source,
        outSize: const Size(90, 90),
        srcRectUv: cropUv,
        strength: widget.filterController.strengthOf(filter),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 90, 90), Paint()..shader = shader);
      shader.dispose();
      final picture = recorder.endRecording();
      final image = await picture.toImage(90, 90);
      picture.dispose();
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _thumbnails[filter]?.dispose();
        _thumbnails[filter] = image;
      });
    }
  }

  Future<void> _refreshThumbnailFor(TracenFilter filter) async {
    final source = _source;
    if (source == null) return;
    final shader = await LutShaderService.configure(
      filter: filter,
      source: source,
      outSize: const Size(90, 90),
      srcRectUv: _squareCropUv(source),
      strength: widget.filterController.strengthOf(filter),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 90, 90), Paint()..shader = shader);
    shader.dispose();
    final picture = recorder.endRecording();
    final image = await picture.toImage(90, 90);
    picture.dispose();
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() {
      _thumbnails[filter]?.dispose();
      _thumbnails[filter] = image;
    });
  }

  @override
  void dispose() {
    widget.filterController.removeListener(_onControllerChanged);
    _previewShader?.dispose();
    for (final image in _thumbnails.values) {
      image.dispose();
    }
    _source?.dispose();
    super.dispose();
  }

  Future<String> _renderFinal() {
    final controller = widget.filterController;
    return FilteredPhotoRenderer.render(
      sourcePath: widget.sourcePath,
      filter: controller.selected,
      strength: controller.strength,
      ratio: controller.ratio,
      overlay: _overlay,
      toggles: OverlayToggles(
        stamp: controller.showStamp,
        route: controller.showRoute,
        watermark: controller.showWatermark,
      ),
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final path = await _renderFinal();
      if (!await Gal.hasAccess(toAlbum: false)) {
        await Gal.requestAccess(toAlbum: false);
      }
      await Gal.putImage(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.photoSavedToGallery)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.saveFailedWith('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _renderFinal();
      final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null ? null : (box.localToGlobal(Offset.zero) & box.size);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'image/jpeg')],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      // 공유 실패/취소는 조용히 무시.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading || _source == null) {
      return const Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return ChangeNotifierProvider.value(
      value: widget.filterController,
      child: Consumer<CameraFilterController>(
        builder: (context, controller, _) => Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(l10n),
                Expanded(child: _buildPreview(controller)),
                _buildOverlayToggles(l10n, controller),
                _buildStrengthRow(l10n, controller),
                _buildFilterStrip(l10n, controller),
                _buildActions(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            tooltip: l10n.retakePhoto,
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(CameraFilterController controller) {
    final source = _source!;
    return Center(
      child: AspectRatio(
        aspectRatio: controller.ratio.aspect,
        child: ClipRect(
          child: CustomPaint(
            painter: _PreviewPainter(
              shader: _previewShader,
              fallback: source,
              overlay: _overlay,
              showStamp: controller.showStamp,
              showRoute: controller.showRoute,
              showWatermark: controller.showWatermark,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayToggles(AppLocalizations l10n, CameraFilterController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        children: [
          _OverlayChip(
            label: l10n.overlayDateStamp,
            selected: controller.showStamp,
            onTap: controller.toggleStamp,
          ),
          _OverlayChip(
            label: l10n.overlayRoute,
            selected: controller.showRoute,
            onTap: controller.toggleRoute,
          ),
          _OverlayChip(
            label: l10n.overlayWatermark,
            selected: controller.showWatermark,
            onTap: controller.toggleWatermark,
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthRow(AppLocalizations l10n, CameraFilterController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(l10n.filterStrength, style: AppTextStyles.caption.copyWith(color: Colors.white70)),
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
                },
                onChangeEnd: (_) => _refreshThumbnailFor(controller.selected),
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

  Widget _buildFilterStrip(AppLocalizations l10n, CameraFilterController controller) {
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
          final thumb = _thumbnails[filter];
          return GestureDetector(
            onTap: () => controller.selectFilter(filter),
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
                    child: thumb == null
                        ? const ColoredBox(color: Colors.white10)
                        : RawImage(image: thumb, fit: BoxFit.cover),
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

  Widget _buildActions(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: _shareButtonKey,
              onPressed: _busy ? null : _share,
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
              label: Text(l10n.sharePhoto, style: const TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final ui.FragmentShader? shader;
  final ui.Image fallback;
  final TracenOverlayData? overlay;
  final bool showStamp;
  final bool showRoute;
  final bool showWatermark;

  _PreviewPainter({
    required this.shader,
    required this.fallback,
    required this.overlay,
    required this.showStamp,
    required this.showRoute,
    required this.showWatermark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final s = shader;
    if (s != null) {
      canvas.drawRect(rect, Paint()..shader = s);
    } else {
      canvas.drawImageRect(
        fallback,
        Rect.fromLTWH(0, 0, fallback.width.toDouble(), fallback.height.toDouble()),
        rect,
        Paint(),
      );
    }

    final data = overlay;
    if (data != null) {
      TracenOverlayPainter.paint(
        canvas,
        size,
        data,
        stamp: showStamp,
        route: showRoute,
        watermark: showWatermark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) {
    return oldDelegate.shader != shader ||
        oldDelegate.overlay != overlay ||
        oldDelegate.showStamp != showStamp ||
        oldDelegate.showRoute != showRoute ||
        oldDelegate.showWatermark != showWatermark;
  }
}

class _OverlayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OverlayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.25) : Colors.white10,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 14,
              color: selected ? AppColors.primary : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
