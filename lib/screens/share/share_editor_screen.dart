import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/pin.dart';
import '../../services/share_card_exporter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/share_card/share_card_controller.dart';
import 'share_template_section.dart';

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
    ShareCardController.forPin(widget.pin).then((c) {
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
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ShareCardPreviewBox(controller: controller, exportKey: _exportKey),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context).shareStickerHint,
                        style: AppTextStyles.caption.copyWith(color: Colors.white54),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                ShareTemplateControls(controller: controller),
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
