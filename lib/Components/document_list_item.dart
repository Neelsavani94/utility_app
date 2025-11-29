import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import '../Constants/app_constants.dart';
import '../Models/document_model.dart';
import '../Widget/glassmorphic_card.dart';
import '../Routes/navigation_service.dart';

class DocumentListItem extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;
  final VoidCallback? onMore;

  const DocumentListItem({
    super.key,
    required this.document,
    this.onTap,
    this.onShare,
    this.onFavorite,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      opacity: isDark ? 0.2 : 0.8,
      child: InkWell(
        onTap: onTap ?? () => _handleDocumentTap(context),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        child: Row(
          children: [
            // Thumbnail or Icon
            _buildThumbnail(colorScheme, 56, 76),
            const SizedBox(width: AppConstants.spacingM),

            // Document Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppConstants.spacingXS),
                  Text(
                    document.formattedDate,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 12,
                        ),
                  ),
                  const SizedBox(height: AppConstants.spacingXS),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_android_rounded,
                        size: AppConstants.iconXS,
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                      const SizedBox(width: AppConstants.spacingXS),
                      Text(
                        document.location,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.4),
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action Buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.share_rounded,
                    size: AppConstants.iconM,
                  ),
                  onPressed: onShare ?? () => _handleShareDocument(context),
                  color: colorScheme.onSurface.withOpacity(0.6),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: AppConstants.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  ),
                  child: Text(
                    document.category,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingS),
                IconButton(
                  icon: Icon(
                    document.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: AppConstants.iconM,
                  ),
                  onPressed: onFavorite,
                  color: document.isFavorite
                      ? Colors.amber.shade600
                      : colorScheme.onSurface.withOpacity(0.6),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: AppConstants.spacingS),
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: AppConstants.iconM,
                  ),
                  onPressed: onMore,
                  color: colorScheme.onSurface.withOpacity(0.6),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(ColorScheme colorScheme, double width, double height) {
    final thumbnailPath = document.thumbnailPath;
    
    // If thumbnail exists and is not empty, show thumbnail
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      final thumbnailFile = File(thumbnailPath);
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          child: Image.file(
            thumbnailFile,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to icon if thumbnail fails to load
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  size: AppConstants.iconL,
                ),
              );
            },
          ),
        ),
      );
    }
    
    // Default icon
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.description_rounded,
        color: colorScheme.onSurfaceVariant.withOpacity(0.4),
        size: AppConstants.iconL,
      ),
    );
  }

  void _handleDocumentTap(BuildContext context) {
    final filePath = document.imagePath ?? document.thumbnailPath;
    if (filePath == null || filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('File path not available'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final category = document.category.toLowerCase();
    final isPDF = category == 'pdf' || 
                  filePath.toLowerCase().endsWith('.pdf') ||
                  document.name.toLowerCase().endsWith('.pdf');

    if (isPDF) {
      // Navigate to PDF viewer
      NavigationService.toScanPDFViewer(pdfPath: filePath);
    } else {
      // Navigate to image viewer
      NavigationService.toImageViewer(
        imagePath: filePath,
        imageName: document.name,
      );
    }
  }

  Future<void> _handleShareDocument(BuildContext context) async {
    // Check if it's a folder
    final category = document.category.toLowerCase();
    if (category == 'folder') {
      Fluttertoast.showToast(
        msg: 'Cannot share folder',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final filePath = document.imagePath ?? document.thumbnailPath;
    if (filePath == null || filePath.isEmpty) {
      Fluttertoast.showToast(
        msg: 'File path not available',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      Fluttertoast.showToast(
        msg: 'File not found',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final isPDF = category == 'pdf' || 
                    filePath.toLowerCase().endsWith('.pdf') ||
                    document.name.toLowerCase().endsWith('.pdf');

      await Share.shareXFiles(
        [XFile(filePath)],
        text: isPDF ? 'PDF Document' : 'Image',
      );
    } catch (e) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error sharing file: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }
}
