import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../localization/localization.dart';
import '../../theme/app_colors.dart';
import 'app_buttons.dart';
import 'app_toast.dart';

/// خيارات مصدر التقاط أو اختيار الصورة
enum PhotoAttachmentSource {
  camera,
  gallery,
}

/// مكوّن إدارة وإرفاق الصور الموحد بتصميم آبل (AMTR Unified Photo Attachment System)
/// يدعم الاختيار من الكاميرا أو المعرض، معاينة فورية، حذف الصور، وتنسيقات مصغرة
class AppPhotoAttachmentSection extends StatelessWidget {
  final List<String> photos;
  final ValueChanged<List<String>> onPhotosChanged;
  final int maxPhotos;
  final bool readOnly;
  final bool compact;
  final String? title;
  final String? hint;

  const AppPhotoAttachmentSection({
    super.key,
    required this.photos,
    required this.onPhotosChanged,
    this.maxPhotos = 10,
    this.readOnly = false,
    this.compact = false,
    this.title,
    this.hint,
  });

  Future<String> _persistPhoto(String sourcePath) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(docsDir.path, 'amtr_photos'));
      if (!photosDir.existsSync()) {
        await photosDir.create(recursive: true);
      }
      final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
      final newFileName = 'amtr_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}$ext';
      final targetPath = p.join(photosDir.path, newFileName);
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.copy(targetPath);
        return targetPath;
      }
      return sourcePath;
    } catch (_) {
      return sourcePath;
    }
  }

  Future<void> _handlePickPhotos(BuildContext context) async {
    if (photos.length >= maxPhotos) {
      AppToast.showWarning(
        context,
        'validation_photos_max_reached'.trParams({'max': maxPhotos.toString()}),
      );
      return;
    }

    final source = await showModalBottomSheet<PhotoAttachmentSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AppPhotoSourceBottomSheet(),
    );

    if (source == null || !context.mounted) return;

    final picker = ImagePicker();
    final List<String> newPaths = [];

    if (source == PhotoAttachmentSource.camera) {
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        newPaths.add(photo.path);
      }
    } else {
      final pickedList = await picker.pickMultiImage(imageQuality: 85);
      if (pickedList.isNotEmpty) {
        final remainingSlots = maxPhotos - photos.length;
        final accepted = pickedList.take(remainingSlots).map((x) => x.path);
        newPaths.addAll(accepted);
      }
    }

    if (newPaths.isNotEmpty) {
      final persisted = <String>[];
      for (final rawPath in newPaths) {
        final saved = await _persistPhoto(rawPath);
        persisted.add(saved);
      }
      final updated = List<String>.from(photos)..addAll(persisted);
      onPhotosChanged(updated);
    }
  }

  void _handleRemovePhoto(BuildContext context, int index) {
    final updated = List<String>.from(photos)..removeAt(index);
    onPhotosChanged(updated);
  }

  void _handlePreviewPhoto(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AppPhotoLightboxDialog(
        photos: photos,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (compact) {
      return _buildCompactLayout(context, isDark);
    }

    return _buildStandardLayout(context, isDark);
  }

  Widget _buildCompactLayout(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppPhotoAttachButton(
              onPressed: readOnly || photos.length >= maxPhotos
                  ? null
                  : () => _handlePickPhotos(context),
              photosCount: photos.length,
              isCompact: true,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                photos.isEmpty
                    ? (hint ?? 'item_photos_attached'.trParams({'count': '0'}))
                    : 'item_photos_attached'.trParams({'count': photos.length.toString()}),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length + (!readOnly && photos.length < maxPhotos ? 1 : 0),
              separatorBuilder: (ctx, i) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                if (idx == photos.length) {
                  return _buildAddMoreThumbnail(context, isDark, size: 64);
                }
                return AppPhotoThumbnail(
                  filePath: photos[idx],
                  size: 64,
                  showDelete: !readOnly,
                  onTap: () => _handlePreviewPhoto(context, idx),
                  onDelete: () => _handleRemovePhoto(context, idx),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStandardLayout(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceCard.withValues(alpha: 0.5)
            : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title ?? 'photo_attach_title'.i18n(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (photos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${photos.length} / $maxPhotos',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (photos.isEmpty && !readOnly) ...[
            _buildEmptyStatePlaceholder(context, isDark),
          ] else if (photos.isNotEmpty) ...[
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length + (!readOnly && photos.length < maxPhotos ? 1 : 0),
                separatorBuilder: (ctx, i) => const SizedBox(width: 10),
                itemBuilder: (context, idx) {
                  if (idx == photos.length) {
                    return _buildAddMoreThumbnail(context, isDark, size: 76);
                  }
                  return AppPhotoThumbnail(
                    filePath: photos[idx],
                    size: 76,
                    showDelete: !readOnly,
                    onTap: () => _handlePreviewPhoto(context, idx),
                    onDelete: () => _handleRemovePhoto(context, idx),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyStatePlaceholder(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () => _handlePickPhotos(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
          color: isDark
              ? AppColors.primaryBlue.withValues(alpha: 0.05)
              : AppColors.primaryBlue.withValues(alpha: 0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo_rounded,
                size: 20,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'photo_attach_button'.i18n(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint ?? 'photo_source_sheet_subtitle'.i18n(),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMoreThumbnail(BuildContext context, bool isDark, {required double size}) {
    return InkWell(
      onTap: () => _handlePickPhotos(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: 0.4),
            width: 1.2,
          ),
          color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.12 : 0.06),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 22, color: AppColors.primaryBlue),
            const SizedBox(height: 2),
            Text(
              'photo_add_more'.i18n(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر مخصص لإرفاق الصور بمظهر أبل
class AppPhotoAttachButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final int photosCount;
  final bool isCompact;
  final String? label;

  const AppPhotoAttachButton({
    super.key,
    required this.onPressed,
    this.photosCount = 0,
    this.isCompact = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 14,
            vertical: isCompact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primaryBlue.withValues(alpha: 0.15)
                : AppColors.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_a_photo_outlined,
                size: 16,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 6),
              Text(
                label ?? 'photo_attach_button'.i18n(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              if (photosCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    photosCount.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ودجت عرض الصورة المصغرة الفردية مع زر الحذف وإمكانية المعاينة
class AppPhotoThumbnail extends StatelessWidget {
  final String filePath;
  final double size;
  final bool showDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const AppPhotoThumbnail({
    super.key,
    required this.filePath,
    required this.size,
    required this.showDelete,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    final exists = file.existsSync();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.borderSubtle.withValues(alpha: 0.8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: exists
                  ? Image.file(
                      file,
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),
        ),
        if (showDelete)
          Positioned(
            top: -5,
            right: -5,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.statusDanger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade300,
      child: const Icon(
        Icons.broken_image_rounded,
        size: 24,
        color: Colors.grey,
      ),
    );
  }
}

/// شيت سفلي لاختيار مصدر الصورة (كاميرا أو معرض) بنمط أبل الفاخر
class _AppPhotoSourceBottomSheet extends StatelessWidget {
  const _AppPhotoSourceBottomSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'photo_source_sheet_title'.i18n(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'photo_source_sheet_subtitle'.i18n(),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _buildSourceTile(
              context,
              icon: Icons.camera_alt_rounded,
              title: 'photo_source_camera'.i18n(),
              color: AppColors.primaryBlue,
              onTap: () => Navigator.pop(context, PhotoAttachmentSource.camera),
            ),
            const SizedBox(height: 10),
            _buildSourceTile(
              context,
              icon: Icons.photo_library_rounded,
              title: 'photo_source_gallery'.i18n(),
              color: AppColors.primaryGreen,
              onTap: () => Navigator.pop(context, PhotoAttachmentSource.gallery),
            ),
            const SizedBox(height: 14),
            AppOutlinedButton(
              label: 'common_cancel'.i18n(),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

/// عارض صور عالي الدقة بملء الشاشة مع تكبير وتمرير
class AppPhotoLightboxDialog extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const AppPhotoLightboxDialog({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<AppPhotoLightboxDialog> createState() => _AppPhotoLightboxDialogState();
}

class _AppPhotoLightboxDialogState extends State<AppPhotoLightboxDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: SafeArea(
        child: Stack(
          children: [
            // مستعرض الصور القابل للتكبير
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (context, idx) {
                final file = File(widget.photos[idx]);
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: file.existsSync()
                        ? Image.file(
                            file,
                            fit: BoxFit.contain,
                          )
                        : const Icon(
                            Icons.broken_image_rounded,
                            size: 64,
                            color: Colors.white54,
                          ),
                  ),
                );
              },
            ),

            // شريط علوي أنيق يحتوي على العنوان ورقم الصورة وزر الإغلاق
            Positioned(
              top: 10,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.photos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // لموازنة زر الإغلاق
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
