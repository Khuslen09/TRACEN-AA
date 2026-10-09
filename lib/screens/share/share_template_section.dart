import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/share_card_template.dart';
import '../../models/share_ink_color.dart';
import '../../models/sticker_id.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/share_card/share_card.dart';
import '../../widgets/share_card/share_card_controller.dart';
import '../../widgets/share_card/share_card_layout.dart';

/// 공유 카드 미리보기 — 가용 공간에 맞게 비율 유지하며 축소(FittedBox)하고,
/// 화면엔 안 보이지만 풀사이즈(360×640)로 페인트되는 내보내기용 인스턴스를
/// 함께 둔다. `ShareEditorScreen`(핀 공유)과 `PhotoEditScreen`(촬영 직후
/// "템플릿" 섹션)이 공유하는 위젯 — Transform.scale은 레이아웃 크기를 안
/// 줄여서 오버플로우를 일으키므로 FittedBox로 실제 크기 자체를 줄인다.
class ShareCardPreviewBox extends StatelessWidget {
  final ShareCardController controller;
  final GlobalKey exportKey;
  final void Function(StickerId id)? onStickerTap;
  final double borderRadius;

  const ShareCardPreviewBox({
    super.key,
    required this.controller,
    required this.exportKey,
    this.onStickerTap,
    this.borderRadius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final model = controller.viewModel;
    final cardSize = ShareCardLayout.cardSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        var w = maxW;
        var h = w * cardSize.height / cardSize.width;
        if (h > maxH) {
          h = maxH;
          w = h * cardSize.width / cardSize.height;
        }

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: cardSize.width,
                      height: cardSize.height,
                      child: ShareCard(
                        model: model,
                        interactive: true,
                        selectedSticker: controller.selectedSticker,
                        onStickerSelected: controller.selectSticker,
                        onStickerGestureStart: controller.beginStickerGesture,
                        onStickerGestureUpdate: controller.updateStickerGesture,
                        onStickerTap: onStickerTap,
                      ),
                    ),
                  ),
                ),
                // 화면엔 안 보이지만(0×0 ClipRect로 잘려 레이아웃·화면에
                // 기여 안 함) 실제로는 풀사이즈로 페인트되는 캡처용 인스턴스.
                // Opacity(0)으로 숨기면 Flutter가 자식 페인트를 아예 건너뛰어
                // toImage가 실패한다(사진 저장/공유 실패의 원인이었음).
                ClipRect(
                  child: SizedBox(
                    width: 0,
                    height: 0,
                    child: OverflowBox(
                      minWidth: cardSize.width,
                      maxWidth: cardSize.width,
                      minHeight: cardSize.height,
                      maxHeight: cardSize.height,
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          key: exportKey,
                          child: ShareCard(model: model, interactive: false),
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
}

/// 템플릿 칩(미니멀/필름/스탬프) + 잉크 색상 스와치 + 스티커(날짜/지도/
/// 위치명/로고/경로) 표시 토글 — `ShareEditorScreen`이 한 화면에 전부
/// 쌓아서 보여줄 때 씀. `PhotoEditScreen`은 탭마다 따로 분리해서 쓰므로
/// (필터/템플릿/표시/색상 탭이 각자 있어서 중복하면 안 됨)
/// [ShareStickerToggles]만 직접 가져다 씀.
class ShareTemplateControls extends StatelessWidget {
  final ShareCardController controller;
  final VoidCallback? onEditPlace;

  const ShareTemplateControls({super.key, required this.controller, this.onEditPlace});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTemplateChips(),
        const SizedBox(height: 10),
        _buildColorSwatches(),
        const SizedBox(height: 10),
        ShareStickerToggles(controller: controller, onEditPlace: onEditPlace),
      ],
    );
  }

  Widget _buildTemplateChips() {
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

  Widget _buildColorSwatches() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final ink in ShareInkColor.values)
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
    );
  }

}

/// 스티커(날짜/지도/위치명/로고/경로) 표시 토글만 — 템플릿 칩/색상 스와치는
/// 안 보여줌. `ShareTemplateControls`(핀 공유 화면)와 `PhotoEditScreen`의
/// "표시" 탭(필터/템플릿/색상은 각자 자기 탭이 따로 있어서 중복하면 안 됨)
/// 이 공유.
class ShareStickerToggles extends StatelessWidget {
  final ShareCardController controller;
  final VoidCallback? onEditPlace;

  const ShareStickerToggles({super.key, required this.controller, this.onEditPlace});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = [
      (StickerId.date, l10n.shareToggleDate),
      (StickerId.map, l10n.shareToggleMap),
      (StickerId.place, l10n.shareTogglePlace),
      (StickerId.logo, l10n.shareToggleLogo),
      (StickerId.route, l10n.shareToggleRoute),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          for (final (id, label) in entries)
            if (id == StickerId.place && onEditPlace != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToggleChip(
                    label: label,
                    selected: controller.isVisible(id),
                    onTap: () => controller.toggleVisibility(id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white54),
                    tooltip: l10n.shareEditPlaceName,
                    onPressed: onEditPlace,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(left: 4),
                  ),
                ],
              )
            else
              _ToggleChip(
                label: label,
                selected: controller.isVisible(id),
                onTap: () => controller.toggleVisibility(id),
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
              style: AppTextStyles.caption.copyWith(color: selected ? Colors.white : Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
