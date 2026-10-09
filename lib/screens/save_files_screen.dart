import '../l10n/generated/app_localizations.dart';
import '../l10n/strings.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/pin.dart';
import '../models/pin_category.dart';
import '../services/auth_service.dart';
import '../services/category_color_service.dart';
import '../services/photo_storage.dart';
import '../services/pin_service.dart';
import '../services/route_db_service.dart';
import '../services/tracen_overlay_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_extensions.dart';
import 'camera/camera_capture_screen.dart';
import 'camera/camera_filter_controller.dart';
import 'camera/photo_edit_screen.dart';
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

  /// 미리 채워 둘 값 — AI 추천 결과에서 "핀으로 저장"할 때 사용.
  final String? initialPlaceName;
  final PinCategory? initialCategory;
  final String? initialMemo;

  /// 이미 저장된 핀을 수정할 때 — 카테고리/메모/사진/위치명을 채워서 열고,
  /// 저장하면 새 핀을 만드는 대신 이 핀을 갱신해 돌려준다.
  final Pin? editingPin;

  const SaveFilesScreen({
    super.key,
    this.runId,
    required this.lat,
    required this.lng,
    this.colorNotifier,
    this.initialPlaceName,
    this.initialCategory,
    this.initialMemo,
    this.editingPin,
  });

  bool get isEditing => editingPin != null;

  @override
  State<SaveFilesScreen> createState() => _SaveFilesScreenState();
}

class _SaveFilesScreenState extends State<SaveFilesScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  final _memoController = TextEditingController();
  final _picker = ImagePicker();

  String? _photoPath;
  String? _pickedPlaceName;

  /// 수정 모드에서 로컬 파일 없이 클라우드에만 있는 기존 사진
  String? _existingPhotoUrl;

  /// 수정 모드에서 사진을 바꾸거나 지웠는지
  bool _photoChanged = false;
  PinCategory _selectedCategory = PinCategory.general;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final editing = widget.editingPin;
    if (editing != null) {
      _selectedCategory = editing.category;
      _memoController.text = editing.memo ?? '';
      _pickedPlaceName = editing.placeName;
      _photoPath = PhotoStorage.existingPath(editing.photoPath);
      if (_photoPath == null &&
          editing.photoUrl != null &&
          editing.photoUrl!.isNotEmpty) {
        _existingPhotoUrl = editing.photoUrl;
      }
      return;
    }
    _pickedPlaceName = widget.initialPlaceName;
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialMemo != null) {
      _memoController.text = widget.initialMemo!;
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Photo
  // ─────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    // 85로 재압축하면 갤러리 원본보다 화질이 떨어져서 최고 화질로 받는다
    // (HEIC 등도 JPEG로 받아 항상 디코드 가능하게 품질 값은 지정).
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (file == null) return;
    // 카메라 촬영 사진과 동일하게 필터/템플릿 적용 화면을 거치게 한다.
    // 갤러리 원본을 바이트 그대로 복사만 하면 디코드 실패 시 썸네일이 빈
    // 화면으로 뜨는 버그가 있었고, 공유 기능도 못 썼음 — PhotoEditScreen을
    // 통과시키면 항상 디코드 가능한 PNG로 다시 구워주므로 둘 다 해결된다.
    final filterController = await CameraFilterController.load();
    final overlayFuture = TracenOverlayService.loadToday();
    if (!mounted) return;
    final result = await Navigator.push<({String path, String? placeName})>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoEditScreen(
          sourcePath: file.path,
          filterController: filterController,
          overlayFuture: overlayFuture,
          fromGallery: true, // 기본 "원본" — 갤러리 사진 그대로
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _photoPath = result.path;
        _existingPhotoUrl = null;
        _photoChanged = true;
        _pickedPlaceName = result.placeName ?? _defaultPlaceName;
      });
    }
  }

  /// TRACEN 시그니처 카메라로 촬영 — 필터/오버레이까지 적용한 최종 사진
  /// 경로를 돌려받음. image_picker의 OS 기본 카메라 대신 이 플로우로 교체.
  Future<void> _pickFromCamera() async {
    final result = await Navigator.push<({String path, String? placeName})>(
      context,
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
    if (result != null) {
      setState(() {
        _photoPath = result.path;
        _existingPhotoUrl = null;
        _photoChanged = true;
        _pickedPlaceName = result.placeName ?? _defaultPlaceName;
      });
    }
  }

  /// 사진 없이도 남길 위치명 — 수정 중이면 원래 핀의 위치명, 새 핀이면
  /// 처음 받은 장소명(AI 추천 등).
  String? get _defaultPlaceName =>
      widget.editingPin?.placeName ?? widget.initialPlaceName;

  void _removePhoto() => setState(() {
    _photoPath = null;
    _existingPhotoUrl = null;
    _photoChanged = true;
    _pickedPlaceName = _defaultPlaceName;
  });

  // ─────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────

  Future<void> _save() async {
    final memo = _memoController.text.trim();
    if (memo.isEmpty && _photoPath == null && _existingPhotoUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addMemoOrPhoto)));
      return;
    }

    setState(() => _saving = true);

    final editing = widget.editingPin;
    if (editing != null) {
      try {
        final updated = await PinService.update(
          editing,
          category: _selectedCategory,
          memo: memo,
          placeName: _pickedPlaceName,
          newPhotoPath: _photoChanged ? _photoPath : null,
          removePhoto: _photoChanged && _photoPath == null,
        );
        if (mounted) Navigator.pop(context, updated);
      } catch (e) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.saveFailedWith('$e')),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
      return;
    }

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
        placeName: _pickedPlaceName,
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
                      widget.isEditing ? l10n.pinEditTitle : today,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h3,
                    ),
                  ),
                  // 제목 가운데 정렬용 자리 (왼쪽 닫기 버튼과 같은 폭).
                  // 동작 없는 "더보기" 버튼은 심사에서 미완성으로 보일 수 있어 제거.
                  const SizedBox(width: 48),
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
                        if (_photoPath != null || _existingPhotoUrl != null)
                          TextButton(
                            onPressed: _removePhoto,
                            child: Text(l10n.commonDelete),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _PhotoCard(
                      photoPath: _photoPath,
                      networkUrl: _existingPhotoUrl,
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
  final String? networkUrl;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  const _PhotoCard({
    required this.photoPath,
    this.networkUrl,
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
      child: (photoPath == null && networkUrl == null)
          ? _buildEmptyState(context)
          : _buildPreview(context),
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
          child: photoPath != null
              ? Image.file(
                  File(photoPath!),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _brokenPhoto(context),
                )
              : CachedNetworkImage(
                  imageUrl: networkUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _brokenPhoto(context),
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

Widget _brokenPhoto(BuildContext context) => Container(
  height: 200,
  color: context.bgColor,
  alignment: Alignment.center,
  child: Icon(Icons.broken_image_outlined, color: context.textTertiary),
);

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
          final icon = colorNotifier?.iconOf(c) ?? c.icon;
          final label = colorNotifier?.labelOf(c) ?? c.label;
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
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
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
