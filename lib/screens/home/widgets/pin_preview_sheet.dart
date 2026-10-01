import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/strings.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../models/pin.dart';
import '../../../models/pin_category.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/theme_extensions.dart';

/// 마커 탭 시 화면 하단에서 올라오는 핀 미리보기 시트.
///
/// 사진을 탭하면 전체화면으로 크게 볼 수 있음.
class PinPreviewSheet extends StatelessWidget {
  final Pin pin;
  final VoidCallback onDelete;
  final ScrollController? scrollController;

  const PinPreviewSheet({
    super.key,
    required this.pin,
    required this.onDelete,
    this.scrollController,
  });

  static Future<void> show(
    BuildContext context, {
    required Pin pin,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // 드래그로 시트 키울 수 있게 — initialChildSize 0.5에서 시작, 0.95까지 확장
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => PinPreviewSheet(
          pin: pin,
          onDelete: onDelete,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = '${DateFormat.MMMd(Strings.current.localeName).format(pin.createdAt)} '
        '${DateFormat.jm(Strings.current.localeName).format(pin.createdAt)}';

    // 로컬 파일이 실제로 존재하는지 확인 후 판단
    final localExists =
        pin.photoPath != null &&
        pin.photoPath!.isNotEmpty &&
        File(pin.photoPath!).existsSync();
    final hasUrl = pin.photoUrl != null && pin.photoUrl!.isNotEmpty;
    final hasPhoto = localExists || hasUrl;
    final hasMemo = pin.memo != null && pin.memo!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ──
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── 카테고리 뱃지 + 시간 + 삭제 ──
            Row(
              children: [
                _CategoryBadge(category: pin.category),
                SizedBox(width: 8),
                Expanded(child: Text(time, style: AppTextStyles.smallBold)),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.gray500,
                  onPressed: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                  tooltip: l10n.pinDeleteTooltip,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── 사진 — 탭하면 전체화면 ──
            if (hasPhoto)
              GestureDetector(
                onTap: () => _openFullPhoto(
                  context,
                  localExists ? pin.photoPath! : null,
                  hasUrl ? pin.photoUrl : null,
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: _PinImage(
                        localPath: localExists ? pin.photoPath : null,
                        networkUrl: hasUrl ? pin.photoUrl : null,
                        height: 220,
                      ),
                    ),
                    // 확대 힌트 아이콘
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(
                          Icons.zoom_out_map_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── 메모 ──
            if (hasMemo) ...[
              if (hasPhoto) const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  pin.memo!,
                  style: AppTextStyles.body.copyWith(
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],

            // 사진도 메모도 없을 때
            if (!hasPhoto && !hasMemo)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.pinEmpty,
                  style: AppTextStyles.body.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 전체화면 사진 뷰어.
  void _openFullPhoto(
    BuildContext context,
    String? localPath,
    String? networkUrl,
  ) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) =>
            _FullPhotoViewer(localPath: localPath, networkUrl: networkUrl),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

/// 로컬 파일 → 네트워크 URL 순으로 fallback하는 이미지 위젯.
class _PinImage extends StatelessWidget {
  final String? localPath;
  final String? networkUrl;
  final double height;

  const _PinImage({this.localPath, this.networkUrl, required this.height});

  @override
  Widget build(BuildContext context) {
    if (localPath != null) {
      return Image.file(
        File(localPath!),
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _networkFallback(),
      );
    }
    return _networkFallback();
  }

  Widget _networkFallback() {
    if (networkUrl == null) return _brokenImage();
    return CachedNetworkImage(
      imageUrl: networkUrl!,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        height: height,
        color: AppColors.gray100,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      ),
      errorWidget: (_, __, ___) => _brokenImage(),
    );
  }

  Widget _brokenImage() {
    return Container(
      height: height,
      color: AppColors.gray100,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppColors.gray400,
        size: 32,
      ),
    );
  }
}

/// 전체화면 사진 뷰어 — 핀치줌 + 탭/뒤로가기로 닫기.
class _FullPhotoViewer extends StatelessWidget {
  final String? localPath;
  final String? networkUrl;

  const _FullPhotoViewer({this.localPath, this.networkUrl});

  Future<void> _saveToGallery(BuildContext context) async {
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        await Gal.requestAccess(toAlbum: false);
      }

      if (localPath != null && File(localPath!).existsSync()) {
        await Gal.putImage(localPath!);
      } else if (networkUrl != null) {
        // 네트워크 이미지 다운로드 후 갤러리에 저장
        final res = await http.get(Uri.parse(networkUrl!));
        final tmp = await getTemporaryDirectory();
        final file = File(
          '${tmp.path}/aa_save_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await file.writeAsBytes(res.bodyBytes);
        await Gal.putImage(file.path);
        await file.delete();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).photoSavedToGallery)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saveFailedWith('$e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            // 사진 (핀치줌 가능)
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: _buildFullImage(),
              ),
            ),
            // 상단 버튼 행: 닫기 + 저장
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 닫기
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    // 갤러리 저장
                    GestureDetector(
                      onTap: () => _saveToGallery(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 안내 텍스트
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  l10n.tapToClose,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullImage() {
    if (localPath != null) {
      return Image.file(
        File(localPath!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _networkFull(),
      );
    }
    return _networkFull();
  }

  Widget _networkFull() {
    if (networkUrl == null) {
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: networkUrl!,
      fit: BoxFit.contain,
      placeholder: (_, __) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      errorWidget: (_, __, ___) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }
}

/// 카테고리 뱃지.
class _CategoryBadge extends StatelessWidget {
  final PinCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 14, color: category.color),
          const SizedBox(width: 4),
          Text(
            category.label,
            style: AppTextStyles.caption.copyWith(
              color: category.color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
