import '../../l10n/generated/app_localizations.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_photo_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';

/// 프로필 편집 화면.
///
/// 동작:
///   - 사진 카드 탭 → 카메라/갤러리 선택 시트
///   - 닉네임 필드 — 2자 이상 검사
///   - 저장 버튼 → AuthService.updateProfile + Storage 업로드
///
/// 사진은 사용자가 선택만 하고 아직 업로드 전이면 [_pendingPhotoPath]에
/// 로컬 경로 보관. 저장 버튼 누를 때 한 번에 업로드 → URL 받아서 프로필 갱신.
/// 저장 안 누르고 뒤로 가면 업로드 안 됨 (트래픽 절약).
class ProfileEditScreen extends StatefulWidget {
  final AppUser user;

  const ProfileEditScreen({super.key, required this.user});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  late final TextEditingController _nameController = TextEditingController(
    text: widget.user.name ?? '',
  );

  /// 새로 선택한 로컬 사진 경로 (업로드 대기).
  String? _pendingPhotoPath;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Photo
  // ─────────────────────────────────────────────

  Future<void> _showPhotoSheet() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoSourceSheet(),
    );
    if (source == null) return;

    final file = await picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1024, // 프로필 사진은 큰 해상도 불필요
    );
    if (file != null && mounted) {
      setState(() => _pendingPhotoPath = file.path);
    }
  }

  // ─────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _showSnack(l10n.nameTooShort);
      return;
    }

    setState(() => _saving = true);
    try {
      // 사진이 새로 선택됐으면 먼저 업로드
      String? photoUrl;
      if (_pendingPhotoPath != null) {
        photoUrl = await CloudPhotoService.uploadProfilePhoto(
          uid: widget.user.uid,
          localFile: File(_pendingPhotoPath!),
        );
      }

      // 변경된 필드만 갱신 — 닉네임은 이전 값과 다를 때만, 사진은 새로 골랐을 때만
      final nameChanged = name != (widget.user.name ?? '');
      await AuthService.updateProfile(
        name: nameChanged ? name : null,
        photoUrl: photoUrl,
      );

      if (!mounted) return;
      Navigator.pop(context, true); // true = 변경 있음
    } on AuthException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (e) {
      if (mounted) _showSnack(l10n.saveError, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.gray900,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(l10n.profileEdit),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // 사진
                    GestureDetector(
                      onTap: _showPhotoSheet,
                      child: _AvatarEditor(
                        currentUrl: widget.user.photoUrl,
                        pendingPath: _pendingPhotoPath,
                      ),
                    ),
                    SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _showPhotoSheet,
                      icon: Icon(Icons.camera_alt_outlined, size: 18),
                      label: Text(l10n.changePhoto),
                    ),

                    SizedBox(height: 32),

                    // 닉네임
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(l10n.nameLabel, style: AppTextStyles.smallBold),
                      ),
                    ),
                    TextField(
                      controller: _nameController,
                      maxLength: 20,
                      decoration: InputDecoration(
                        hintText: l10n.nameHint,
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.gray400,
                          size: 20,
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // 이메일 (읽기 전용)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(l10n.commonEmail, style: AppTextStyles.smallBold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mail_outline_rounded,
                            color: context.textTertiary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.user.email,
                              style: AppTextStyles.body.copyWith(
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: AppColors.gray400,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 6),
                    Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        l10n.emailReadOnly,
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 저장 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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

class _AvatarEditor extends StatelessWidget {
  final String? currentUrl;
  final String? pendingPath;

  const _AvatarEditor({required this.currentUrl, required this.pendingPath});

  @override
  Widget build(BuildContext context) {
    // 우선순위: 새로 선택한 로컬 파일 > 기존 URL > 기본
    final hasPending = pendingPath != null && pendingPath!.isNotEmpty;
    final hasUrl = currentUrl != null && currentUrl!.isNotEmpty;

    return Stack(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: (!hasPending && !hasUrl)
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  )
                : null,
            boxShadow: AppShadows.md,
          ),
          child: ClipOval(
            child: hasPending
                ? Image.file(File(pendingPath!), fit: BoxFit.cover)
                : hasUrl
                ? Image.network(
                    currentUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(),
                  )
                : _fallback(),
          ),
        ),
        // 우하단 카메라 아이콘 — 편집 가능하다는 시각 단서
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: context.cardColor, width: 3),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback() =>
      Center(child: Icon(Icons.person_rounded, color: Colors.white, size: 56));
}

/// 카메라/갤러리 선택 바텀시트.
class _PhotoSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.gray300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.camera_alt_outlined,
              color: context.textPrimary,
            ),
            title: Text(l10n.takePhoto, style: AppTextStyles.body),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(
              Icons.photo_library_outlined,
              color: context.textPrimary,
            ),
            title: Text(l10n.chooseFromGallery, style: AppTextStyles.body),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
  }
}
