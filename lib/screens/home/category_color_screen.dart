import '../../l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../models/pin_category.dart';
import '../../services/category_color_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/marker_bitmap_util.dart';

/// 카테고리별 색상을 사용자가 직접 고르는 설정 화면.
///
/// 설정 화면 또는 핀 추가 화면 설정 아이콘에서 진입.
/// 변경 즉시 저장 + notifier 알림 → 지도 마커 색상 실시간 갱신.
class CategoryColorScreen extends StatefulWidget {
  final CategoryColorNotifier notifier;

  const CategoryColorScreen({super.key, required this.notifier});

  @override
  State<CategoryColorScreen> createState() => _CategoryColorScreenState();
}

class _CategoryColorScreenState extends State<CategoryColorScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  late Map<PinCategory, Color> _colors;

  @override
  void initState() {
    super.initState();
    _colors = Map.from(widget.notifier.colors);
  }

  Future<void> _pickColor(PinCategory category) async {
    final picked = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ColorPickerSheet(
        current: _colors[category] ?? category.defaultColor,
        category: category,
      ),
    );
    if (picked == null) return;

    // 캐시 무효화 후 색상 업데이트
    MarkerBitmapUtil.clearCache();
    await widget.notifier.update(category, picked);
    setState(() => _colors[category] = picked);
  }

  Future<void> _resetAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.resetColorsTitle),
        content: Text(l10n.resetColorsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.reset, style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    MarkerBitmapUtil.clearCache();
    await widget.notifier.reset();
    setState(() {
      for (final c in PinCategory.values) {
        _colors[c] = c.defaultColor;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        title: Text(l10n.categoryColors, style: AppTextStyles.h3),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded),
          color: context.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _resetAll,
            child: Text(
              l10n.reset,
              style: AppTextStyles.smallBold.copyWith(color: AppColors.gray400),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: PinCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final cat = PinCategory.values[i];
          final color = _colors[cat] ?? cat.defaultColor;
          final isDefault = color.toARGB32() == cat.defaultColor.toARGB32();

          return GestureDetector(
            onTap: () => _pickColor(cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.sm,
              ),
              child: Row(
                children: [
                  // 현재 색상 dot 미리보기
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // 카테고리 아이콘 + 이름
                  Icon(cat.icon, size: 18, color: context.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(cat.label, style: AppTextStyles.body),
                  ),

                  // 기본값 배지
                  if (isDefault)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        l10n.colorDefault,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.gray400,
                        ),
                      ),
                    ),

                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.gray400,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 색상 선택 바텀시트.
class _ColorPickerSheet extends StatefulWidget {
  final Color current;
  final PinCategory category;

  const _ColorPickerSheet({required this.current, required this.category});

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  late Color _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 제목
          Row(
            children: [
              Icon(widget.category.icon, size: 18, color: _selected),
              SizedBox(width: 8),
              Text(
                l10n.categoryColorTitle(widget.category.label),
                style: AppTextStyles.h3,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 미리보기 dot (선택 중인 색)
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _selected,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: _selected.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 색상 팔레트 그리드
          Text(l10n.presetColors, style: AppTextStyles.smallBold),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ColorPalette.presets.map((c) {
              final isSelected = c.toARGB32() == _selected.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _selected = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.white,
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          color: c == Colors.white
                              ? AppColors.primary
                              : Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),

          SizedBox(height: 28),

          // 확인 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: Text(l10n.apply),
            ),
          ),
        ],
      ),
    );
  }
}
