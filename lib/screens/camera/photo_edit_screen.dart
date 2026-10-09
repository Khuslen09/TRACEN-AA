import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/camera_filter.dart';
import '../../models/camera_filter_l10n.dart';
import '../../models/place_candidate.dart';
import '../../models/share_card_template.dart';
import '../../models/share_ink_color.dart';
import '../../models/sticker_id.dart';
import '../../models/sticker_transform.dart';
import '../../models/tracen_overlay_data.dart';
import '../../services/location_service.dart';
import '../../services/lut_shader_service.dart';
import '../../services/place_name_service.dart';
import '../../services/share_card_exporter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/color_matrix_fit.dart';
import '../../widgets/share_card/share_card.dart';
import '../../widgets/share_card/share_card_controller.dart';
import '../../widgets/share_card/share_card_view_model.dart';
import '../share/poi_picker_sheet.dart';
import '../share/share_template_section.dart';
import 'camera_filter_controller.dart';

enum _PhotoEditTab { filter, template, display, color }

/// 촬영 직후 화면 — TRACEN 색 필터(Golden Route 등) 선택에 이어서, 같은
/// 화면에서 공유 카드 템플릿(미니멀/필름/스탬프 + 날짜/지도/위치명/로고/
/// 경로 스티커)까지 적용한다. 미리보기는 [ShareCard] 하나뿐 — 필터는
/// `ColorFiltered`로 사진 레이어에만 실시간 근사 적용(래스터화 없음),
/// 정확한 LUT 결과는 저장/공유 직전에 한 번만 구워서 내보낸다.
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
  final _exportKey = GlobalKey();

  ui.Image? _source;
  ui.Image? _proxyImage; // 긴 변 약 300px — 썸네일 전용(필터/템플릿 탭)
  final Map<TracenFilter, ui.Image> _filterThumbnails = {};
  bool _loading = true;
  bool _busy = false;

  ShareCardController? _shareCardController;
  List<PlaceCandidate> _placeCandidates = const [];
  // ShareCardController.placeName은 생성 시 역지오코딩으로 항상 미리
  // 채워져 있어서(동/시 단위 폴백), 이것만으로는 "사용자가 직접 골랐는지"를
  // 구분할 수 없음 — 연필 아이콘으로 실제로 고른 경우에만 true가 되어,
  // 핀 저장 시 이 값이 있을 때만 placeName을 같이 넘긴다(아니면 핀 저장
  // 직후의 자동 POI 조회가 알아서 채우게 null로 둠).
  bool _placeNameManuallyEdited = false;
  _PhotoEditTab _activeTab = _PhotoEditTab.filter;

  @override
  void initState() {
    super.initState();
    widget.filterController.addListener(_onFilterControllerChanged);
    _init();
  }

  Future<void> _init() async {
    final bytes = await File(widget.sourcePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1600);
    final frame = await codec.getNextFrame();
    final proxyCodec = await ui.instantiateImageCodec(bytes, targetWidth: 300);
    final proxyFrame = await proxyCodec.getNextFrame();
    if (!mounted) return;
    setState(() {
      _source = frame.image;
      _proxyImage = proxyFrame.image;
      _loading = false;
    });

    // 썸네일은 보조 기능이라 실패해도(예: 셰이더 컴파일 실패) 화면 자체를
    // 막으면 안 됨 — 조용히 무시.
    unawaited(_rebuildFilterThumbnails().catchError((_) {}));
    unawaited(_initShareCardController());
  }

  /// 위치를 못 가져와도(권한 없음/타임아웃) 화면은 정상 작동해야 하므로,
  /// 실패하면 (0,0)으로 폴백 — 지도/위치명/경로 스티커는 어차피 매칭되는
  /// 데이터가 없으면 알아서 빈 채로 렌더(에러 아님, `ShareCard`의 기존
  /// 패턴). 오늘의 경로는 `overlayFuture`가 이미 들고 있는 걸 그대로 씀 —
  /// 새 DB 조회 없음.
  Future<void> _initShareCardController() async {
    double lat = 0, lng = 0;
    try {
      final position = await LocationService.currentPosition().timeout(
        const Duration(seconds: 6),
      );
      lat = position.latitude;
      lng = position.longitude;
    } catch (_) {
      // 폴백 (0,0) 유지 — 화면은 계속 정상 작동.
    }

    List<({double lat, double lng})> routePath = const [];
    try {
      routePath = (await widget.overlayFuture).path;
    } catch (_) {
      // 경로 없이 진행.
    }

    final controller = await ShareCardController.forCapture(
      lat: lat,
      lng: lng,
      date: DateTime.now(),
      photo: _source!,
      routePath: routePath,
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() => _shareCardController = controller);
    _applyPreviewColorMatrix();

    // 위치명 수정 바텀시트를 열 때마다 네트워크를 기다리게 하지 않도록,
    // 화면 진입 시 한 번만 미리 조회해둔다(실패해도 수동 입력은 늘 가능).
    unawaited(_loadPlaceCandidates(lat, lng));
  }

  Future<void> _loadPlaceCandidates(double lat, double lng) async {
    if (!mounted) return;
    try {
      final candidates = await PlaceNameService.poiCandidatesFor(
        lat,
        lng,
        languageCode: AppLocalizations.of(context).localeName,
      );
      if (mounted) setState(() => _placeCandidates = candidates);
    } catch (_) {
      // 조용히 빈 리스트 유지 — 수동 입력은 항상 가능.
    }
  }

  void _onFilterControllerChanged() {
    _applyPreviewColorMatrix();
  }

  void _applyPreviewColorMatrix() {
    final shareCtrl = _shareCardController;
    if (shareCtrl == null) return;
    final controller = widget.filterController;
    final matrix = lerpWithIdentity(
      fitColorMatrix(controller.selected.recipe),
      controller.strength,
    );
    shareCtrl.setPreviewColorMatrix(matrix);
  }

  Rect _cropUvForAspect(ui.Image image, double aspect) {
    final srcAspect = image.width / image.height;
    if (srcAspect > aspect) {
      final w = aspect / srcAspect;
      return Rect.fromLTWH((1 - w) / 2, 0, w, 1);
    }
    final h = srcAspect / aspect;
    return Rect.fromLTWH(0, (1 - h) / 2, 1, h);
  }

  Future<ui.Image> _renderFilterThumbnail(TracenFilter filter) async {
    final proxy = _proxyImage!;
    const outSize = Size(56, 84);
    final cropUv = _cropUvForAspect(proxy, outSize.width / outSize.height);
    final shader = await LutShaderService.configure(
      filter: filter,
      source: proxy,
      outSize: outSize,
      srcRectUv: cropUv,
      strength: widget.filterController.strengthOf(filter),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, outSize.width, outSize.height), Paint()..shader = shader);
    shader.dispose();
    final picture = recorder.endRecording();
    final image = await picture.toImage(outSize.width.round(), outSize.height.round());
    picture.dispose();
    return image;
  }

  /// 프록시(작은) 이미지 기반이라 전부 동시에 렌더해도 가벼움 — 탭 전체를
  /// 한 번만 미리 구워두고, 필터 탭에선 그냥 보여주기만 함.
  Future<void> _rebuildFilterThumbnails() async {
    final proxy = _proxyImage;
    if (proxy == null) return;
    final images = await Future.wait([
      for (final filter in TracenFilter.values) _renderFilterThumbnail(filter),
    ]);
    if (!mounted) {
      for (final image in images) {
        image.dispose();
      }
      return;
    }
    setState(() {
      for (var i = 0; i < TracenFilter.values.length; i++) {
        _filterThumbnails[TracenFilter.values[i]]?.dispose();
        _filterThumbnails[TracenFilter.values[i]] = images[i];
      }
    });
  }

  void _onFilterTap(TracenFilter filter) {
    widget.filterController.selectFilter(filter);
  }

  @override
  void dispose() {
    widget.filterController.removeListener(_onFilterControllerChanged);
    for (final image in _filterThumbnails.values) {
      image.dispose();
    }
    _source?.dispose();
    _proxyImage?.dispose();
    _shareCardController?.dispose();
    super.dispose();
  }

  /// 현재 선택된 TRACEN 필터를 원본 전체 이미지에 적용해 하나의 [ui.Image]로
  /// 굽는다(크롭 없이 원본 비율 그대로 — `ShareCard`가 `BoxFit.cover`로
  /// 알아서 채움) — 저장/공유 직전에만 호출하는 **정확한** LUT 결과.
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

  /// 분기 없이 항상 ShareCard 결과로 저장/공유 — 정확한 LUT을 굽고, 실시간
  /// 미리보기용 근사 행렬은 반드시 null로 돌린 뒤(이중 필터 방지) 내보내기
  /// 인스턴스가 새 프레임을 그릴 때까지 기다렸다가 캡처한다.
  Future<String> _renderFinal() async {
    final shareCtrl = _shareCardController!;
    final baked = await _renderFullFiltered();
    shareCtrl.setPreviewColorMatrix(null);
    shareCtrl.updatePhoto(baked);
    await WidgetsBinding.instance.endOfFrame;
    return ShareCardExporter.exportToTempFile(_exportKey);
  }

  Future<void> _save() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final path = await _renderFinal();
      await ShareCardExporter.saveToGallery(path);
      if (mounted) {
        // 표시 탭에서 사용자가 직접 고른 위치명이 있으면 핀에 반영되도록
        // 사진 경로와 함께 돌려준다(없으면 null — 호출부의 핀 저장 직후
        // 자동 POI 조회가 알아서 채움).
        Navigator.pop(
          context,
          (
            path: path,
            placeName: _placeNameManuallyEdited ? _shareCardController?.placeName : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveFailedWith('$e')), backgroundColor: Colors.red),
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
      await ShareCardExporter.shareFile(path, origin: origin);
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

    final shareCtrl = _shareCardController;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ChangeNotifierProvider.value(
        value: widget.filterController,
        child: Consumer<CameraFilterController>(
          builder: (context, filterController, _) => Scaffold(
            backgroundColor: AppColors.darkBackground,
            body: SafeArea(
              child: shareCtrl == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : ChangeNotifierProvider.value(
                      value: shareCtrl,
                      child: Consumer<ShareCardController>(
                        builder: (context, shareCtrl, _) => Column(
                          children: [
                            _buildTopBar(l10n, shareCtrl),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                                child: ShareCardPreviewBox(
                                  controller: shareCtrl,
                                  exportKey: _exportKey,
                                  borderRadius: 16,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 116,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 150),
                                child: _buildToolPanel(l10n, filterController, shareCtrl),
                              ),
                            ),
                            _buildTabBar(l10n),
                            _buildActions(l10n),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n, ShareCardController shareCtrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            tooltip: l10n.retakePhoto,
          ),
          Expanded(
            child: Text(
              l10n.photoEditTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.smallBold.copyWith(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _busy ? null : shareCtrl.resetAll,
            tooltip: l10n.photoEditReset,
          ),
        ],
      ),
    );
  }

  Widget _buildToolPanel(
    AppLocalizations l10n,
    CameraFilterController filterController,
    ShareCardController shareCtrl,
  ) {
    return KeyedSubtree(
      key: ValueKey(_activeTab),
      child: switch (_activeTab) {
        _PhotoEditTab.filter => _buildFilterTab(l10n, filterController),
        _PhotoEditTab.template => _buildTemplateTab(shareCtrl),
        _PhotoEditTab.display => _buildDisplayTab(shareCtrl),
        _PhotoEditTab.color => _buildColorTab(shareCtrl),
      },
    );
  }

  Widget _buildFilterTab(AppLocalizations l10n, CameraFilterController controller) {
    return ListView.separated(
      key: const ValueKey('filter'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      scrollDirection: Axis.horizontal,
      itemCount: TracenFilter.values.length,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, i) {
        final filter = TracenFilter.values[i];
        final isSelected = controller.selected == filter;
        final thumb = _filterThumbnails[filter];
        return GestureDetector(
          onTap: () => _onFilterTap(filter),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.white24,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: thumb == null
                      ? const ColoredBox(color: Colors.white10)
                      : RawImage(image: thumb, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 7),
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
    );
  }

  Widget _buildTemplateTab(ShareCardController shareCtrl) {
    final model = shareCtrl.viewModel;
    return ListView.separated(
      key: const ValueKey('template'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      scrollDirection: Axis.horizontal,
      itemCount: ShareCardTemplate.values.length,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, i) {
        final template = ShareCardTemplate.values[i];
        final isSelected = model.template == template;
        return GestureDetector(
          onTap: () => shareCtrl.setTemplate(template),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 92,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.white24,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 52,
                    height: 92,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: 360,
                        height: 640,
                        child: ShareCard(
                          model: ShareCardViewModel(
                            template: template,
                            inkColor: model.inkColor,
                            date: model.date,
                            pinLat: model.pinLat,
                            pinLng: model.pinLng,
                            placeName: model.placeName,
                            countryOutline: model.countryOutline,
                            photo: model.photo,
                            previewColorMatrix: model.previewColorMatrix,
                            routePath: model.routePath,
                            visibility: model.visibility,
                            transforms: {
                              for (final id in StickerId.values) id: const StickerTransform.identity(),
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                template.label,
                style: AppTextStyles.caption.copyWith(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisplayTab(ShareCardController shareCtrl) {
    return Center(
      key: const ValueKey('display'),
      child: ShareStickerToggles(
        controller: shareCtrl,
        onEditPlace: () => _onEditPlace(shareCtrl),
      ),
    );
  }

  /// 아직 DB에 저장된 Pin이 없는 단계라, 선택한 이름은 메모리(뷰모델)에만
  /// 반영한다 — 실제 저장은 이 화면을 닫고 핀이 생성될 때 자연히 반영됨.
  Future<void> _onEditPlace(ShareCardController shareCtrl) async {
    final model = shareCtrl.viewModel;
    final chosen = await showPlaceNamePickerSheet(
      context,
      lat: model.pinLat,
      lng: model.pinLng,
      candidates: _placeCandidates,
    );
    if (chosen != null) {
      shareCtrl.setPlaceName(chosen);
      _placeNameManuallyEdited = true;
    }
  }

  Widget _buildColorTab(ShareCardController shareCtrl) {
    return Center(
      key: const ValueKey('color'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final ink in ShareInkColor.values)
            GestureDetector(
              onTap: () => shareCtrl.setInkColor(ink),
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ink.color,
                  border: Border.all(
                    color: shareCtrl.inkColor == ink ? AppColors.primary : Colors.white24,
                    width: shareCtrl.inkColor == ink ? 3 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    final tabs = [
      (_PhotoEditTab.filter, l10n.photoEditTabFilter),
      (_PhotoEditTab.template, l10n.photoEditTabTemplate),
      (_PhotoEditTab.display, l10n.photoEditTabDisplay),
      (_PhotoEditTab.color, l10n.photoEditTabColor),
    ];
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        children: [
          for (final (tab, label) in tabs)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = tab),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 2,
                      width: 28,
                      margin: const EdgeInsets.only(bottom: 6),
                      color: _activeTab == tab ? AppColors.primary : Colors.transparent,
                    ),
                    Text(
                      label,
                      style: AppTextStyles.caption.copyWith(
                        color: _activeTab == tab ? Colors.white : Colors.white54,
                        fontWeight: _activeTab == tab ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 52,
            child: OutlinedButton.icon(
              key: _shareButtonKey,
              onPressed: _busy ? null : _share,
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 18),
              label: Text(l10n.sharePhoto, style: const TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.save),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
