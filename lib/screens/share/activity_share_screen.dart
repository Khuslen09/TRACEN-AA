import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/activity_share_template.dart';
import '../../models/share_ink_color.dart';
import '../../services/share_card_exporter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/share_card/activity_share_card.dart';

export '../../widgets/share_card/activity_share_card.dart' show ActivityShareData;

/// 러닝/워킹/사이클링 기록 공유 편집 화면 — 핀 공유(`ShareEditorScreen`)와
/// 같은 다크 풀스크린 구조(상단바 / 미리보기 / 템플릿·색상 / 공유 버튼).
///
/// 미리보기는 화면 크기에 맞춰 축소(FittedBox)해서 보여주고, 내보내기는
/// 화면 밖에서 360×640 원본 크기로 그린 [RepaintBoundary]를 캡처한다 —
/// `ShareCardPreviewBox`와 같은 방식.
class ActivityShareScreen extends StatefulWidget {
  final ActivityShareData data;

  const ActivityShareScreen({super.key, required this.data});

  @override
  State<ActivityShareScreen> createState() => _ActivityShareScreenState();
}

class _ActivityShareScreenState extends State<ActivityShareScreen> {
  final _exportKey = GlobalKey();
  final _shareButtonKey = GlobalKey();
  final _otherButtonKey = GlobalKey();

  late ActivityShareTemplate _template = widget.data.photoPaths.isNotEmpty
      ? ActivityShareTemplate.photo
      : ActivityShareTemplate.route;
  ShareInkColor _ink = ShareInkColor.white;
  int _photoIndex = 0;
  bool _busy = false;

  List<ActivityShareTemplate> get _templates => [
    for (final t in ActivityShareTemplate.values)
      if (t != ActivityShareTemplate.photo || widget.data.photoPaths.isNotEmpty)
        t,
  ];

  String? get _photoPath => widget.data.photoPaths.isEmpty
      ? null
      : widget.data.photoPaths[_photoIndex.clamp(
          0,
          widget.data.photoPaths.length - 1,
        )];

  Future<void> _share(GlobalKey originKey) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await ShareCardExporter.exportToTempFile(_exportKey);
      final box = originKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : (box.localToGlobal(Offset.zero) & box.size);
      await ShareCardExporter.shareFile(path, origin: origin);
    } catch (_) {
      // 공유 실패/취소는 조용히 무시 — 핀 공유 화면과 같은 정책.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final path = await ShareCardExporter.exportToTempFile(_exportKey);
      await ShareCardExporter.saveToGallery(path);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.photoSavedToGallery)));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(l10n),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildPreview(),
              ),
            ),
            if (_template == ActivityShareTemplate.sticker)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  l10n.activityShareStickerHint,
                  style: AppTextStyles.caption.copyWith(color: Colors.white54),
                ),
              ),
            const SizedBox(height: 12),
            _buildTemplateChips(),
            if (_template == ActivityShareTemplate.photo &&
                widget.data.photoPaths.length > 1)
              _buildPhotoPicker(),
            _buildInkSwatches(),
            _buildActions(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              l10n.activityShareTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.smallBold.copyWith(color: Colors.white),
            ),
          ),
          IconButton(
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _busy ? null : _saveToGallery,
            tooltip: l10n.shareSaveToGallery,
          ),
        ],
      ),
    );
  }

  Widget _card() => ActivityShareCard(
    data: widget.data,
    template: _template,
    ink: _ink,
    photoPath: _photoPath,
  );

  Widget _buildPreview() {
    const size = ActivityShareCard.cardSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        var w = constraints.maxWidth;
        var h = w * size.height / size.width;
        if (h > constraints.maxHeight) {
          h = constraints.maxHeight;
          w = h * size.width / size.height;
        }
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // 투명 스티커는 배경이 없으니 체커보드로 투명함을 표시
                      // (미리보기 전용 — 내보내기 이미지엔 안 들어감).
                      if (_template == ActivityShareTemplate.sticker)
                        const Positioned.fill(
                          child: CustomPaint(painter: _CheckerPainter()),
                        ),
                      FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: size.width,
                          height: size.height,
                          child: _card(),
                        ),
                      ),
                    ],
                  ),
                ),
                // 화면엔 안 보이지만 원본 크기로 페인트되는 캡처용 인스턴스.
                SizedBox(
                  width: 0,
                  height: 0,
                  child: OverflowBox(
                    minWidth: size.width,
                    maxWidth: size.width,
                    minHeight: size.height,
                    maxHeight: size.height,
                    alignment: Alignment.topLeft,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0,
                        child: RepaintBoundary(
                          key: _exportKey,
                          child: _card(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTemplateChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final t in _templates)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(t.label),
                selected: t == _template,
                onSelected: (_) => setState(() => _template = t),
                showCheckmark: false,
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white10,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                labelStyle: AppTextStyles.smallBold.copyWith(
                  color: t == _template ? Colors.white : Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker() {
    final photos = widget.data.photoPaths;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: photos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final selected = i == _photoIndex;
            return GestureDetector(
              onTap: () => setState(() => _photoIndex = i),
              child: Container(
                width: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(photos[i]),
                    fit: BoxFit.cover,
                    cacheWidth: 168,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInkSwatches() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final ink in ShareInkColor.values)
            GestureDetector(
              onTap: () => setState(() => _ink = ink),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: ink.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ink == _ink ? AppColors.primary : Colors.white24,
                    width: ink == _ink ? 3 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              key: _shareButtonKey,
              onPressed: _busy ? null : () => _share(_shareButtonKey),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(l10n.shareToInstagramStory),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              key: _otherButtonKey,
              onPressed: _busy ? null : () => _share(_otherButtonKey),
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
              tooltip: l10n.shareToOtherApps,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 12.0;
    final a = Paint()..color = const Color(0xFF2A2D3A);
    final b = Paint()..color = const Color(0xFF1E2130);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final even = ((x / cell).floor() + (y / cell).floor()).isEven;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), even ? a : b);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
