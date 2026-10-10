import '../../l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../models/pin_category.dart';
import '../../services/category_color_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/marker_bitmap_util.dart';

/// 카테고리별 이름/아이콘/색상을 사용자가 직접 커스터마이즈하는 화면.
/// 새 카테고리 추가, 추가한 카테고리 삭제도 여기서.
///
/// 설정 화면 또는 핀 추가 화면의 카테고리 섹션에서 진입.
/// 변경 즉시 저장 + notifier 알림 → 지도 마커·선택 칩 등 전체 실시간 갱신.
class CategoryColorScreen extends StatefulWidget {
  final CategoryColorNotifier notifier;

  const CategoryColorScreen({super.key, required this.notifier});

  @override
  State<CategoryColorScreen> createState() => _CategoryColorScreenState();
}

class _CategoryColorScreenState extends State<CategoryColorScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  Future<void> _editCategory(PinCategory category) async {
    final result = await showModalBottomSheet<_CategoryEditResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategoryEditSheet(
        category: category,
        currentName: widget.notifier.labelOf(category),
        currentIcon: widget.notifier.iconOf(category),
        currentColor: widget.notifier.colorOf(category),
      ),
    );
    if (result == null) return;

    MarkerBitmapUtil.clearCache();
    if (result.delete) {
      await widget.notifier.deleteCategory(category);
      if (mounted) setState(() {});
      return;
    }
    await widget.notifier.updateName(category, result.name);
    await widget.notifier.updateIcon(category, result.iconKey);
    await widget.notifier.updateColor(category, result.color);
    if (mounted) setState(() {});
  }

  Future<void> _addCategory() async {
    final result = await showModalBottomSheet<_CategoryEditResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CategoryEditSheet(
        category: null,
        currentName: '',
        currentIcon: Icons.star_rounded,
        currentColor: AppColors.primary,
      ),
    );
    if (result == null || result.name.trim().isEmpty) return;
    MarkerBitmapUtil.clearCache();
    await widget.notifier.addCategory(
      name: result.name,
      iconKey: result.iconKey,
      color: result.color,
    );
    if (mounted) setState(() {});
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
    if (mounted) setState(() {});
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
      body: AnimatedBuilder(
        animation: widget.notifier,
        builder: (context, _) => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: PinCategory.values.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            if (i == PinCategory.values.length) {
              return OutlinedButton.icon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.categoryAdd),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              );
            }
            final cat = PinCategory.values[i];
            final color = widget.notifier.colorOf(cat);
            final icon = widget.notifier.iconOf(cat);
            final label = widget.notifier.labelOf(cat);
            final isDefault = !cat.isCustom &&
                color.toARGB32() == cat.defaultColor.toARGB32() &&
                icon == cat.icon &&
                label == cat.label;

            return GestureDetector(
              onTap: () => _editCategory(cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.sm,
                ),
                child: Row(
                  children: [
                    // 현재 아이콘 + 색상 미리보기
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
                      child: Icon(icon, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Text(label, style: AppTextStyles.body),
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
      ),
    );
  }
}

class _CategoryEditResult {
  final String name;
  final String iconKey;
  final Color color;

  /// 추가한 카테고리를 지우기로 했을 때 true(나머지 값은 무시).
  final bool delete;
  const _CategoryEditResult({
    required this.name,
    required this.iconKey,
    required this.color,
    this.delete = false,
  });
}

/// 카테고리 이름/아이콘/색상을 한 번에 편집하는 바텀시트.
/// [category]가 null이면 새 카테고리 만들기.
class _CategoryEditSheet extends StatefulWidget {
  final PinCategory? category;
  final String currentName;
  final IconData currentIcon;
  final Color currentColor;

  const _CategoryEditSheet({
    required this.category,
    required this.currentName,
    required this.currentIcon,
    required this.currentColor,
  });

  @override
  State<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<_CategoryEditSheet> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  late final TextEditingController _nameController;
  late Color _selectedColor;
  late String _selectedIconKey;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _selectedColor = widget.currentColor;
    _selectedIconKey =
        CategoryIconCatalog.keyOf(widget.currentIcon) ?? 'place';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isNew => widget.category == null;

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.categoryDeleteTitle(widget.currentName)),
        content: Text(l10n.categoryDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.commonDelete,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.pop(
      context,
      _CategoryEditResult(
        name: '',
        iconKey: _selectedIconKey,
        color: _selectedColor,
        delete: true,
      ),
    );
  }

  void _apply() {
    Navigator.pop(
      context,
      _CategoryEditResult(
        name: _nameController.text,
        iconKey: _selectedIconKey,
        color: _selectedColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewIcon = CategoryIconCatalog.all[_selectedIconKey]!;

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
      child: SingleChildScrollView(
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

            Text(
              _isNew
                  ? l10n.categoryNew
                  : l10n.categoryColorTitle(widget.currentName),
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 20),

            // 미리보기
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(previewIcon, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 24),

            // 이름
            Text(l10n.categoryNameLabel, style: AppTextStyles.smallBold),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(hintText: l10n.categoryNameHint),
              // 새 카테고리는 이름이 있어야 만들 수 있어서 버튼 상태 갱신용.
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // 아이콘
            Text(l10n.categoryIconLabel, style: AppTextStyles.smallBold),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: CategoryIconCatalog.all.entries.map((entry) {
                final isSelected = entry.key == _selectedIconKey;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIconKey = entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor
                          : context.bgColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _selectedColor : AppColors.gray300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      entry.value,
                      size: 20,
                      color: isSelected ? Colors.white : context.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 색상
            Text(l10n.presetColors, style: AppTextStyles.smallBold),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ColorPalette.presets.map((c) {
                final isSelected = c.toARGB32() == _selectedColor.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
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

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isNew && _nameController.text.trim().isEmpty
                    ? null
                    : _apply,
                child: Text(_isNew ? l10n.categoryAdd : l10n.apply),
              ),
            ),
            if (widget.category?.isCustom ?? false) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _confirmDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: Text(l10n.commonDelete),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
