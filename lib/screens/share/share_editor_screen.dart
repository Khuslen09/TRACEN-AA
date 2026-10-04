import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/pin.dart';
import '../../models/share_card_template.dart';
import '../../models/share_ink_color.dart';
import '../../models/sticker_id.dart';
import '../../services/share_card_exporter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/share_card/share_card.dart';
import '../../widgets/share_card/share_card_controller.dart';

/// 핀 공유 카드 편집 화면 — `photo_edit_screen.dart`와 같은 다크 풀스크린
/// 에디터 구조(상단바 / 중앙 미리보기 / 컨트롤 줄 / 하단 액션).
class ShareEditorScreen extends StatefulWidget {
  final Pin pin;
  const ShareEditorScreen({super.key, required this.pin});

  @override
  State<ShareEditorScreen> createState() => _ShareEditorScreenState();
}

class _ShareEditorScreenState extends State<ShareEditorScreen> {
  final _exportKey = GlobalKey();
  final _instaButtonKey = GlobalKey();
  final _otherButtonKey = GlobalKey();

  ShareCardController? _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ShareCardController.load(widget.pin).then((c) {
      if (mounted) setState(() => _controller = c);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _share(GlobalKey originKey) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await ShareCardExporter.exportToTempFile(_exportKey);
      final box = originKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null ? null : (box.localToGlobal(Offset.zero) & box.size);
      await ShareCardExporter.shareFile(path, origin: origin);
    } catch (_) {
      // 공유 실패/취소는 조용히 무시 — photo_edit_screen.dart의 _share와 동일한 정책.
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
          SnackBar(content: Text(l10n.saveFailedWith('$e')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<ShareCardController>(
        builder: (context, controller, _) => Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(child: _buildPreview(controller)),
                _buildTemplateChips(controller),
                const SizedBox(height: 10),
                _buildColorSwatches(controller),
                const SizedBox(height: 10),
                _buildToggleChips(context, controller),
                _buildActions(context, controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              l10n.shareEditorTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.smallBold.copyWith(color: Colors.white),
            ),
          ),
          IconButton(
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _busy ? null : _saveToGallery,
            tooltip: l10n.shareSaveToGallery,
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ShareCardController controller) {
    final model = controller.viewModel;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.75,
                child: ShareCard(
                  model: model,
                  interactive: true,
                  selectedSticker: controller.selectedSticker,
                  onStickerSelected: controller.selectSticker,
                  onStickerGestureStart: controller.beginStickerGesture,
                  onStickerGestureUpdate: controller.updateStickerGesture,
                ),
              ),
              // 화면엔 안 보이지만(opacity 0) 실제로 레이아웃/페인트는 되는
              // 캡처용 인스턴스 — RepaintBoundary.toImage는 이 레이어의
              // 페인트 결과를 그대로 읽으므로 화면 표시 여부와 무관하게 동작.
              IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: RepaintBoundary(
                    key: _exportKey,
                    child: ShareCard(model: model, interactive: false),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).shareStickerHint,
            style: AppTextStyles.caption.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateChips(ShareCardController controller) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: ShareCardTemplate.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final template = ShareCardTemplate.values[i];
          final selected = controller.template == template;
          return GestureDetector(
            onTap: () => controller.setTemplate(template),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withValues(alpha: 0.25) : Colors.white10,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? AppColors.primary : Colors.white24),
              ),
              alignment: Alignment.center,
              child: Text(
                template.label,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorSwatches(ShareCardController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final ink in ShareInkColor.values) ...[
          GestureDetector(
            onTap: () => controller.setInkColor(ink),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ink.color,
                border: Border.all(
                  color: controller.inkColor == ink ? AppColors.primary : Colors.white24,
                  width: controller.inkColor == ink ? 2.5 : 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToggleChips(BuildContext context, ShareCardController controller) {
    final l10n = AppLocalizations.of(context);
    final entries = [
      (StickerId.date, l10n.shareToggleDate),
      (StickerId.map, l10n.shareToggleMap),
      (StickerId.place, l10n.shareTogglePlace),
      (StickerId.logo, l10n.shareToggleLogo),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          for (final (id, label) in entries)
            _ToggleChip(
              label: label,
              selected: controller.isVisible(id),
              onTap: () => controller.toggleVisibility(id),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, ShareCardController controller) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              key: _instaButtonKey,
              onPressed: _busy ? null : () => _share(_instaButtonKey),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9A4D),
                foregroundColor: const Color(0xFF1A0E05),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A0E05)),
                    )
                  : Text(l10n.shareToInstagramStory),
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

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({required this.label, required this.selected, required this.onTap});

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
          border: Border.all(color: selected ? AppColors.primary : Colors.white24),
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
