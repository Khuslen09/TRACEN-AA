import '../l10n/generated/app_localizations.dart';
import '../l10n/strings.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/pin.dart';
import '../models/pin_category.dart';
import '../services/auth_service.dart';
import '../services/category_color_service.dart';
import '../services/photo_storage.dart';
import '../services/route_db_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_extensions.dart';
import 'home/category_color_screen.dart';

/// 새 핀(메모 + 사진)을 추가하는 화면.
///
/// 와이어프레임 기반 변경:
///   - 날짜 헤더 좌측 ←, 우측 ⋯ → 좌측 닫기(X), 우측 더보기(⋯) 유지
///   - Today's memo 영역: 단순 입력 텍스트박스
///   - Today's photo 영역: 비어있을 때 → 사진 추가 버튼 4종 (공유/갤러리/카메라/삭제)
///                         있을 때 → 미리보기 + 변경/삭제
///   - 보라 Save 버튼은 그대로
///
/// 호출 측에서 `routeId`와 현재 위치(lat, lng)를 받아서, 저장 성공 시
/// 생성된 [Pin]을 pop 결과로 돌려줍니다.
/// 핀 저장 화면.
///
/// **MVP v5**: runId가 null이면 일반 핀 (러닝과 무관). 24시간 추적 도입으로
/// 모든 핀이 러닝의 자식이 아니게 됨. 호출 측에서 명시적 러닝 중일 때만
/// runId 채워서 전달.
///
/// 호출 측에서 (runId 옵션), 현재 위치(lat, lng)를 받아서, 저장 성공 시
/// 생성된 [Pin]을 pop 결과로 돌려줍니다.
class SaveFilesScreen extends StatefulWidget {
  final int? runId;
  final double lat;
  final double lng;
  final CategoryColorNotifier? colorNotifier;

  const SaveFilesScreen({
    super.key,
    this.runId,
    required this.lat,
    required this.lng,
    this.colorNotifier,
  });

  @override
  State<SaveFilesScreen> createState() => _SaveFilesScreenState();
}

class _SaveFilesScreenState extends State<SaveFilesScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  final _memoController = TextEditingController();
  final _picker = ImagePicker();

  String? _photoPath;
  PinCategory _selectedCategory = PinCategory.general;
  bool _saving = false;

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Photo
  // ─────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file != null) setState(() => _photoPath = file.path);
  }

  void _removePhoto() => setState(() => _photoPath = null);

  // ─────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────

  Future<void> _save() async {
    final memo = _memoController.text.trim();
    if (memo.isEmpty && _photoPath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addMemoOrPhoto)));
      return;
    }

    setState(() => _saving = true);

    try {
      // image_picker가 준 임시 경로는 OS가 정리할 수 있으니
      // 앱 영구 저장소로 복사한 새 경로를 DB에 저장한다.
      String? persistedPath;
      if (_photoPath != null) {
        persistedPath = await PhotoStorage.persist(_photoPath!);
      }

      final pin = Pin(
        uuid: RouteDBService.generateUuid(),
        runId: widget.runId,
        userId: AuthService.currentUser?.uid,
        lat: widget.lat,
        lng: widget.lng,
        category: _selectedCategory,
        photoPath: persistedPath,
        memo: memo.isEmpty ? null : memo,
        createdAt: DateTime.now(),
      );
      final id = await RouteDBService.insertPin(pin);
      if (mounted) Navigator.pop(context, pin.copyWith(id: id));
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.saveFailedWith('$e')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final today = DateFormat.MMMMEEEEd(Strings.current.localeName).format(DateTime.now());

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── 헤더 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: context.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      today,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded),
                    color: context.textPrimary,
                    onPressed: () {
                      // TODO: 더보기 메뉴 (위치 변경, 시간 변경 등)
                    },
                  ),
                ],
              ),
            ),

            // ── 본문 ──
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _SectionLabel(l10n.categoryLabel)),
                        if (widget.colorNotifier != null)
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CategoryColorScreen(
                                  notifier: widget.colorNotifier!,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.palette_outlined, size: 16),
                            label: Text(l10n.categoryCustomize),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _CategorySelector(
                      selected: _selectedCategory,
                      onChanged: (c) => setState(() => _selectedCategory = c),
                      colorNotifier: widget.colorNotifier,
                    ),

                    SizedBox(height: 24),

                    _SectionLabel(l10n.memoLabel),
                    SizedBox(height: 8),
                    _MemoCard(controller: _memoController),

                    SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(child: _SectionLabel(l10n.photoLabel)),
                        if (_photoPath != null)
                          TextButton(
                            onPressed: _removePhoto,
                            child: Text(l10n.commonDelete),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _PhotoCard(
                      photoPath: _photoPath,
                      onPickGallery: _pickFromGallery,
                      onPickCamera: _pickFromCamera,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── 하단 Save 버튼 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppShadows.primary,
                  ),
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(l10n.save),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sub Widgets
// ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: AppTextStyles.smallBold),
    );
  }
}

class _MemoCard extends StatelessWidget {
  final TextEditingController controller;
  const _MemoCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.sm,
      ),
      padding: EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        maxLines: 4,
        minLines: 3,
        style: AppTextStyles.body.copyWith(color: context.textPrimary),
        decoration: InputDecoration(
          hintText: l10n.memoHint,
          filled: false,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String? photoPath;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  const _PhotoCard({
    required this.photoPath,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.sm,
      ),
      padding: const EdgeInsets.all(16),
      child: photoPath == null ? _buildEmptyState(context) : _buildPreview(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // 점선 박스 — 사진 없음 표시
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: context.borderColor, width: 1.2),
          ),
          child: Center(
            child: Icon(
              Icons.add_photo_alternate_outlined,
              size: 36,
              color: context.textTertiary,
            ),
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PhotoActionButton(
                icon: Icons.photo_library_outlined,
                label: l10n.gallery,
                onPressed: onPickGallery,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _PhotoActionButton(
                icon: Icons.photo_camera_outlined,
                label: l10n.permCameraTitle,
                onPressed: onPickCamera,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.file(
            File(photoPath!),
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PhotoActionButton(
                icon: Icons.photo_library_outlined,
                label: l10n.anotherPhoto,
                onPressed: onPickGallery,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _PhotoActionButton(
                icon: Icons.photo_camera_outlined,
                label: l10n.retakePhoto,
                onPressed: onPickCamera,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _PhotoActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: context.textPrimary),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.smallBold),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카테고리 선택 — 가로 스크롤 칩 모음.
///
/// 디자인 결정:
///   - 가로 스크롤 chip — 6개 고정인데 폰 화면 폭이 좁을 수 있어
///   - 선택된 카테고리는 색상 채움 + 흰 글씨, 나머지는 회색 outline
///   - 아이콘 + 라벨 한 쌍으로 구분이 명확
class _CategorySelector extends StatelessWidget {
  final PinCategory selected;
  final ValueChanged<PinCategory> onChanged;
  final CategoryColorNotifier? colorNotifier;

  const _CategorySelector({
    required this.selected,
    required this.onChanged,
    this.colorNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: PinCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = PinCategory.values[i];
          final isSelected = c == selected;
          final color = colorNotifier?.colorOf(c) ?? c.defaultColor;
          return GestureDetector(
            onTap: () => onChanged(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? color : context.cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? color : AppColors.gray300,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    c.icon,
                    size: 18,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.label,
                    style: AppTextStyles.smallBold.copyWith(
                      color: isSelected ? Colors.white : context.textPrimary,
                    ),
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
