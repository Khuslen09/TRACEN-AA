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
import '../../services/location_service.dart';
import '../../services/lut_shader_service.dart';
import '../../services/share_card_exporter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/tracen_overlay_painter.dart';
import '../../widgets/share_card/share_card_controller.dart';
import '../share/share_template_section.dart';
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
  final _templateExportKey = GlobalKey();

  ui.Image? _source;
  TracenOverlayData? _overlay;
  ui.FragmentShader? _previewShader;
  final Map<TracenFilter, ui.Image> _thumbnails = {};
  bool _loading = true;
  bool _busy = false;
  int _shaderGeneration = 0;

  ShareCardController? _shareCardController;

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
    unawaited(_initShareCardController());

    widget.overlayFuture.then((data) {
      if (mounted) setState(() => _overlay = data);
    });
  }

  /// "템플릿" 섹션용 — 아직 저장된 Pin이 없으니 현재 위치를 직접 가져오고,
  /// 지금 선택된 TRACEN 필터를 적용한 풀해상도 이미지를 배경으로 넘긴다.
  /// 위치를 못 가져오면(권한 없음/타임아웃) 템플릿 섹션 자체를 안 보여줌 —
  /// 기존 촬영 플로우엔 전혀 영향 없음.
  Future<void> _initShareCardController() async {
    try {
      final position = await LocationService.currentPosition().timeout(
        const Duration(seconds: 6),
      );
      final photo = await _renderFullFiltered();
      final controller = await ShareCardController.forCapture(
        lat: position.latitude,
        lng: position.longitude,
        date: DateTime.now(),
        photo: photo,
      );
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _shareCardController = controller);
    } catch (_) {
      // 위치 권한 없음/타임아웃 — 템플릿 섹션 없이 기존 플로우 그대로.
    }
  }

  /// 현재 선택된 TRACEN 필터를 원본 전체 이미지에 적용해 하나의 [ui.Image]로
  /// 굽는다 — "템플릿" 섹션의 공유 카드 배경 사진용(크롭 없이 원본 비율
  /// 그대로, `ShareCard`가 `BoxFit.cover`로 알아서 채움).
  Future<ui.Image> _renderFullFiltered() async {
    final source = _source!;
    final controller = widget.filterController;
    final shader = await LutShaderService.configure(
      filter: controller.selected,
      source: source,
      outSize: Size(source.width.toDouble(), source.height.toDouble()),
      srcRectUv: const Rect.fromLTWH(0, 0, 1, 1),
      strength: controller.strength,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Paint()..shader = shader,
    );
    shader.dispose();
    final picture = recorder.endRecording();
    final image = await picture.toImage(source.width, source.height);
    picture.dispose();
    return image;
  }

  /// 필터/강도가 바뀔 때마다(탭 또는 슬라이더를 놓았을 때만 — 드래그 중
  /// 연속으로는 안 부름, `_refreshThumbnailFor`와 같은 정책) 템플릿 배경을
  /// 새로 구워 반영.
  Future<void> _refreshTemplateBackground() async {
    final shareCtrl = _shareCardController;
    if (shareCtrl == null || _source == null) return;
    final image = await _renderFullFiltered();
    if (!mounted) {
      image.dispose();
      return;
    }
    shareCtrl.updatePhoto(image);
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

  Future<ui.Image> _renderThumbnail(ui.Image source, TracenFilter filter, Rect cropUv) async {
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
    return image;
  }

  /// 4개를 동시에 렌더링 — LUT 이미지는 이미 캐시돼 있어(보통 촬영 화면에서
  /// `LutShaderService.warmUp()`으로 미리 로드됨) 순차로 하나씩 기다릴
  /// 이유가 없음. 순차 실행 대비 체감 로딩이 크게 줄어듦.
  Future<void> _rebuildAllThumbnails() async {
    final source = _source;
    if (source == null) return;
    final cropUv = _squareCropUv(source);

    final images = await Future.wait([
      for (final filter in TracenFilter.values) _renderThumbnail(source, filter, cropUv),
    ]);

    if (!mounted) {
      for (final image in images) {
        image.dispose();
      }
      return;
    }
    setState(() {
      for (var i = 0; i < TracenFilter.values.length; i++) {
        final filter = TracenFilter.values[i];
        _thumbnails[filter]?.dispose();
        _thumbnails[filter] = images[i];
      }
    });
  }

  Future<void> _refreshThumbnailFor(TracenFilter filter) async {
    final source = _source;
    if (source == null) return;
    final image = await _renderThumbnail(source, filter, _squareCropUv(source));
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
    _shareCardController?.dispose();
    super.dispose();
  }

  /// 템플릿 섹션에서 스티커를 하나라도 켰으면(= 실제로 쓰기로 함) 그 결과를
  /// 저장/공유하고, 아니면 기존 필터+오버레이 결과를 그대로 저장/공유.
  Future<String> _renderFinal() {
    final shareCtrl = _shareCardController;
    if (shareCtrl != null && shareCtrl.hasAnyStickerVisible) {
      return ShareCardExporter.exportToTempFile(_templateExportKey);
    }
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
      // 핀 저장 화면 등에서 Navigator.push<String>로 이 플로우를 열었으면
      // 그 호출자에게 바로 결과 경로를 돌려줌 — 갤러리 저장 + 반환 둘 다.
      if (mounted) Navigator.pop(context, path);
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
      final mimeType = path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: mimeType)],
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

    final hasTemplate = _shareCardController != null;

    return ChangeNotifierProvider.value(
      value: widget.filterController,
      child: Consumer<CameraFilterController>(
        builder: (context, controller, _) => Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(l10n),
                Expanded(flex: hasTemplate ? 3 : 1, child: _buildPreview(controller)),
                if (!hasTemplate) ...[
                  _buildOverlayToggles(l10n, controller),
                  _buildStrengthRow(l10n, controller),
                  _buildFilterStrip(l10n, controller),
                ] else
                  Flexible(
                    flex: 4,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildOverlayToggles(l10n, controller),
                          _buildStrengthRow(l10n, controller),
                          _buildFilterStrip(l10n, controller),
                          _buildTemplateSection(context, l10n),
                        ],
                      ),
                    ),
                  ),
                _buildActions(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "필터에 이어서" 붙는 템플릿 섹션 — 필터는 그대로 두고 그 위에 공유
  /// 카드 템플릿(미니멀/필름/스탬프 + 날짜/지도/위치명/로고 스티커)을 얹을
  /// 수 있게 한다. 스티커를 하나도 안 켜면(기본값) 저장/공유 결과는 기존과
  /// 동일 — 사용자가 실제로 켜야만 최종 결과에 반영됨([_renderFinal] 참고).
  Widget _buildTemplateSection(BuildContext context, AppLocalizations l10n) {
    final shareController = _shareCardController!;
    return ChangeNotifierProvider.value(
      value: shareController,
      child: Consumer<ShareCardController>(
        builder: (context, shareController, _) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white12, height: 1),
            ),
            Text(
              l10n.shareEditorTitle,
              style: AppTextStyles.caption.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ShareCardPreviewBox(
                controller: shareController,
                exportKey: _templateExportKey,
              ),
            ),
            const SizedBox(height: 8),
            ShareTemplateControls(controller: shareController),
          ],
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
                onChangeEnd: (_) {
                  _refreshThumbnailFor(controller.selected);
                  unawaited(_refreshTemplateBackground());
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
            onTap: () {
              controller.selectFilter(filter);
              unawaited(_refreshTemplateBackground());
            },
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
