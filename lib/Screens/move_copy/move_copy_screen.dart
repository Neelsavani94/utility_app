import 'dart:io';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../Constants/app_constants.dart';
import '../../Models/document_model.dart';
import '../../Providers/home_provider.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/database_helper.dart';
import '../../Services/file_storage_service.dart';
import 'package:provider/provider.dart';

class MoveCopyScreen extends StatelessWidget {
  final DocumentModel document;
  final String action; // 'Move' or 'Copy'

  MoveCopyScreen({
    super.key,
    required this.document,
    required this.action,
  });

  final _db = DatabaseHelper.instance;
  final _fileStorageService = FileStorageService.instance;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<HomeProvider>(context);

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.2)
                : colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () => NavigationService.goBack(),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          '$action File',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              itemCount: provider.documents.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = provider.documents[index];
                return _buildDocumentItem(context, doc, colorScheme, isDark);
              },
            ),
          ),
          // Bottom Action Bar
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surface.withOpacity(0.5)
                  : colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '1 Item ${action == 'Move' ? 'Moved' : 'Copied'}',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.create_new_folder_rounded,
                        label: 'Create Folder',
                        colorScheme: colorScheme,
                        isDark: isDark,
                        onTap: () {
                          // Handle create folder
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Create Folder'),
                              backgroundColor: colorScheme.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.paste_rounded,
                        label: action == "Move" ? 'Move here' : 'Paste here',
                        colorScheme: colorScheme,
                        isDark: isDark,
                        onTap: () => _handleMoveCopyAction(
                          context,
                          document,
                          colorScheme,
                          provider,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(
    BuildContext context,
    DocumentModel doc,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _handleDocumentTap(context, doc),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.spacingM,
          horizontal: AppConstants.spacingS,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail or Icon
            _buildDocumentThumbnail(doc, colorScheme, 56),
            const SizedBox(width: AppConstants.spacingM),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    doc.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          doc.formattedDate,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 11,
                              ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Action Icons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                doc.category,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.3)
                : colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: colorScheme.primary, size: 24),
              const SizedBox(height: AppConstants.spacingXS),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentThumbnail(DocumentModel document, ColorScheme colorScheme, double size) {
    final thumbnailPath = document.thumbnailPath;
    
    // If thumbnail exists and is not empty, show thumbnail
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      final thumbnailFile = File(thumbnailPath);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            thumbnailFile,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to icon if thumbnail fails to load
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: colorScheme.primary,
                  size: size * 0.5,
                ),
              );
            },
          ),
        ),
      );
    }
    
    // Default icon
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.description_rounded,
        color: colorScheme.primary,
        size: size * 0.5,
      ),
    );
  }

  void _handleDocumentTap(BuildContext context, DocumentModel document) {
    // When tapping a document, perform move/copy to that folder
    _handleMoveCopyAction(context, document, Theme.of(context).colorScheme, Provider.of<HomeProvider>(context));
  }

  Future<void> _handleMoveCopyAction(
    BuildContext context,
    DocumentModel targetDocument,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) async {
    try {
      // Get source document
      final sourceDocId = int.parse(document.id);
      final sourceDoc = await _db.getDocumentById(sourceDocId);
      
      if (sourceDoc == null) {
        Fluttertoast.showToast(
          msg: 'Source document not found',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Get target folder (tagId) from target document
      final targetDocId = int.parse(targetDocument.id);
      final targetDoc = await _db.getDocumentById(targetDocId);
      final targetTagId = targetDoc?.tagId;

      if (action == 'Move') {
        // Move document to target folder
        await _db.moveDocumentToFolder(sourceDocId, targetTagId);
        
        Fluttertoast.showToast(
          msg: 'Document moved successfully',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: colorScheme.primary,
          textColor: Colors.white,
        );
      } else if (action == 'Copy') {
        // Copy document with all details
        final newDocId = await _db.copyDocumentWithDetails(sourceDocId, targetTagId);
        
        // Copy files
        final newDoc = await _db.getDocumentById(newDocId);
        if (newDoc != null) {
          // Copy main image file
          final isPDF = newDoc.type.toLowerCase() == 'pdf';
          final newImagePath = await _fileStorageService.copyFile(
            sourcePath: newDoc.imagePath,
            newFileName: '${newDoc.title}_copy',
            isPDF: isPDF,
          );

          if (newImagePath != null) {
            // Copy thumbnail if exists
            String? newThumbnailPath;
            if (newDoc.thumbnailPath != null) {
              newThumbnailPath = await _fileStorageService.copyThumbnail(
                sourceThumbnailPath: newDoc.thumbnailPath,
                newThumbnailName: '${newDoc.title}_thumb_copy',
              );
            }

            // Update document with new file paths
            final updatedDoc = newDoc.copyWith(
              imagePath: newImagePath,
              thumbnailPath: newThumbnailPath,
            );
            await _db.updateDocument(updatedDoc);

            // Copy all document detail files
            final details = await _db.getDocumentDetailsByDocumentId(newDocId);
            for (final detail in details) {
              final newDetailImagePath = await _fileStorageService.copyFile(
                sourcePath: detail.imagePath,
                newFileName: '${detail.title}_copy',
                isPDF: false,
              );

              String? newDetailThumbnailPath;
              if (detail.thumbnailPath != null) {
                newDetailThumbnailPath = await _fileStorageService.copyThumbnail(
                  sourceThumbnailPath: detail.thumbnailPath,
                  newThumbnailName: '${detail.title}_thumb_copy',
                );
              }

              if (newDetailImagePath != null) {
                final updatedDetail = detail.copyWith(
                  imagePath: newDetailImagePath,
                  thumbnailPath: newDetailThumbnailPath,
                );
                await _db.updateDocumentDetail(updatedDetail);
              }
            }
          }
        }

        Fluttertoast.showToast(
          msg: 'Document copied successfully',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: colorScheme.primary,
          textColor: Colors.white,
        );
      }

      // Refresh documents
      provider.loadDocuments();
      
      // Navigate back
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      log('Error in move/copy action: $e');
      Fluttertoast.showToast(
        msg: 'Error: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
}
