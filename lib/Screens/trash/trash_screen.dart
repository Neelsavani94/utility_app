import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../Constants/app_constants.dart';
import '../../Providers/home_provider.dart';
import '../../Models/document_model.dart';
import '../../Services/database_helper.dart';
import '../../Routes/navigation_service.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final List<String> _selectedItems = [];
  List<DocumentModel> _deletedDocuments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeletedDocuments();
  }

  Future<void> _loadDeletedDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load deleted documents from TrashDocuments table
      final trashDocs = await _db.getAllTrashDocuments();

      // Convert TrashDocuments to DocumentModel
      _deletedDocuments = await Future.wait(trashDocs.map((trashDoc) async {
        // Get the referenced document to get type
        final documentId = trashDoc['document_id'] as int?;
        String category = 'document';
        bool isFavorite = false;
        
        if (documentId != null) {
          final document = await _db.getDocument(documentId);
          if (document != null) {
            category = document['type']?.toString() ?? 'document';
            isFavorite = (document['favourite'] as int? ?? 0) == 1;
          }
        }
        
        // Determine file type from image path extension if type is not available
        final imagePath = trashDoc['Image_path']?.toString() ?? '';
        if (category == 'document' && imagePath.isNotEmpty) {
          final extension = imagePath.toLowerCase().split('.').last;
          if (extension == 'pdf') {
            category = 'pdf';
          } else if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
            category = 'image';
          }
        }
        
        final createdDate = trashDoc['created_date'] != null
            ? DateTime.tryParse(trashDoc['created_date'].toString())
            : null;
        
        return DocumentModel(
          id: trashDoc['id']?.toString() ?? '',
          name: trashDoc['title']?.toString() ?? 'Untitled',
          createdAt: createdDate ?? DateTime.now(),
          location: 'In this device',
          category: category,
          isFavorite: isFavorite,
          thumbnailPath: trashDoc['image_thumbnail']?.toString(),
          imagePath: imagePath,
          isDeleted: true,
          deletedAt: trashDoc['updated_date'] != null
              ? DateTime.tryParse(trashDoc['updated_date'].toString())
              : null,
        );
      }));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading deleted documents: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          'Trash',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_deletedDocuments.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _showRestoreAllDialog(context, colorScheme);
              },
              icon: Icon(
                Icons.restore_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              label: Text(
                'Restore',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_deletedDocuments.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _showDeleteAllDialog(context, colorScheme);
              },
              icon: Icon(
                Icons.delete_forever_rounded,
                size: 20,
                color: Colors.red,
              ),
              label: Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          : _deletedDocuments.isEmpty
          ? _buildEmptyState(colorScheme, isDark)
          : RefreshIndicator(
              onRefresh: _loadDeletedDocuments,
              color: colorScheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _deletedDocuments.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppConstants.spacingS),
                      itemBuilder: (context, index) {
                        final document = _deletedDocuments[index];
                        return _buildDocumentCard(
                          context,
                          document,
                          colorScheme,
                          isDark,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surface.withOpacity(0.3)
                  : colorScheme.surfaceVariant.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: AppConstants.spacingXL),
          Text(
            'Trash is Empty',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Deleted items will appear here',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    DocumentModel document,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _handleDocumentTap(context, document),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface.withOpacity(0.6) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? colorScheme.outline.withOpacity(0.12)
                : colorScheme.outline.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.15)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail or Icon with subtle gradient
            _buildDocumentThumbnail(document, colorScheme, 52),
            const SizedBox(width: 14),
            // Content - Compact Vertical
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    document.name,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      document.category,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: colorScheme.onSurface.withOpacity(0.45),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        document.deletedAt != null
                            ? _formatDeletedDate(document.deletedAt!)
                            : document.formattedDate,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Actions - Compact
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Restore
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _showRestoreDialog(context, document, colorScheme);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.restore_rounded,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Delete Permanently
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _showDeleteDialog(context, document, colorScheme);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.delete_forever_rounded,
                        size: 18,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: Colors.white,
                  size: size * 0.5,
                ),
              );
            },
          ),
        ),
      );
    }
    
    // Default icon with gradient
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.description_rounded,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }

  void _handleDocumentTap(BuildContext context, DocumentModel document) {
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

  String _formatDeletedDate(DateTime deletedAt) {
    final now = DateTime.now();
    final difference = now.difference(deletedAt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return deletedAt.toString().split(' ')[0];
    }
  }

  void _showRestoreDialog(
    BuildContext context,
    DocumentModel item,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingXL),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.98)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restore_rounded,
                  color: Colors.green.shade700,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXL),
              // Title
              Text(
                'Restore Item?',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              // Message
              Text(
                'This item will be restored to its original location.',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingXL),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _restoreItem(item);
                        if (mounted) {
                          Fluttertoast.showToast(
                            msg: '"${item.name}" restored',
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.green,
                            textColor: Colors.white,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: Text(
                        'Restore',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    DocumentModel item,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingXL),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.98)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.red.shade700,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXL),
              // Title
              Text(
                'Delete Permanently?',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              // Message
              Text(
                'This action cannot be undone. The item will be permanently deleted.',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingXL),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteItem(item);
                        if (mounted) {
                          Fluttertoast.showToast(
                            msg: '"${item.name}" deleted permanently',
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRestoreAllDialog(BuildContext context, ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingXL),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.98)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restore_rounded,
                  color: Colors.green.shade700,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXL),
              Text(
                'Restore All Items?',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                '${_deletedDocuments.length} items will be restored to their original location.',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingXL),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _restoreAllItems();
                        if (mounted) {
                          Fluttertoast.showToast(
                            msg: '${_deletedDocuments.length} items restored',
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.green,
                            textColor: Colors.white,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: Text(
                        'Restore All',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAllDialog(BuildContext context, ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingXL),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.98)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.red.shade700,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXL),
              Text(
                'Delete All Permanently?',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'This action cannot be undone. All ${_deletedDocuments.length} items will be permanently deleted.',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingXL),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final count = _deletedDocuments.length;
                        await _deleteAllItems();
                        if (mounted) {
                          Fluttertoast.showToast(
                            msg: '$count items deleted permanently',
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: Text(
                        'Delete All',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restoreItem(DocumentModel item) async {
    try {
      // Get trash document to find document_id
      final trashId = int.tryParse(item.id);
      if (trashId != null) {
        final trashDoc = await _db.getTrashDocument(trashId);
        if (trashDoc != null) {
          final documentId = trashDoc['document_id'] as int?;
          
          // First: Delete from TrashDocuments table
          await _db.deleteTrashDocument(trashId);
          
          // Then: Update Document table - set is_deleted to false (0)
          if (documentId != null) {
            await _db.updateDocument(documentId, {
              'is_deleted': 0,
              'updated_date': DateTime.now().toIso8601String(),
            });
          }
        }
      }

      // Reload deleted documents
      await _loadDeletedDocuments();

      // Reload home provider documents
      final provider = Provider.of<HomeProvider>(context, listen: false);
      await provider.loadDocuments();

      if (mounted) {
        setState(() {
          _selectedItems.remove(item.id);
        });
      }
    } catch (e) {
      print('Error restoring document: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error restoring document: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _deleteItem(DocumentModel item) async {
    try {
      // Get trash document to find document_id
      final trashId = int.tryParse(item.id);
      if (trashId != null) {
        final trashDoc = await _db.getTrashDocument(trashId);
        if (trashDoc != null) {
          final documentId = trashDoc['document_id'] as int?;
          
          // First: Delete from TrashDocuments table
          await _db.deleteTrashDocument(trashId);
          
          // Then: Permanently delete from Document table
          if (documentId != null) {
            await _db.deleteDocument(documentId);
          }
        }
      }

      // Reload deleted documents
      await _loadDeletedDocuments();

      // Reload home provider documents
      final provider = Provider.of<HomeProvider>(context, listen: false);
      await provider.loadDocuments();

      if (mounted) {
        setState(() {
          _selectedItems.remove(item.id);
        });
      }
    } catch (e) {
      print('Error deleting document: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error deleting document: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _restoreAllItems() async {
    try {
      // Get all trash documents
      final trashDocs = await _db.getAllTrashDocuments();
      
      // Restore each document and remove from trash
      for (var trashDoc in trashDocs) {
        final documentId = trashDoc['document_id'] as int?;
        final trashId = trashDoc['id'] as int?;
        
        // First: Delete from TrashDocuments table
        if (trashId != null) {
          await _db.deleteTrashDocument(trashId);
        }
        
        // Then: Update Document table - set is_deleted to false (0)
        if (documentId != null) {
          await _db.updateDocument(documentId, {
            'is_deleted': 0,
            'updated_date': DateTime.now().toIso8601String(),
          });
        }
      }

      // Reload deleted documents
      await _loadDeletedDocuments();

      // Reload home provider documents
      final provider = Provider.of<HomeProvider>(context, listen: false);
      await provider.loadDocuments();

      if (mounted) {
        setState(() {
          _selectedItems.clear();
        });
      }
    } catch (e) {
      print('Error restoring all documents: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error restoring all documents: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _deleteAllItems() async {
    try {
      // Get all trash documents
      final trashDocs = await _db.getAllTrashDocuments();

      // Delete each document permanently
      for (var trashDoc in trashDocs) {
        final documentId = trashDoc['document_id'] as int?;
        final trashId = trashDoc['id'] as int?;
        
        // First: Delete from TrashDocuments table
        if (trashId != null) {
          await _db.deleteTrashDocument(trashId);
        }
        
        // Then: Permanently delete from Document table
        if (documentId != null) {
          await _db.deleteDocument(documentId);
        }
      }

      // Reload deleted documents
      await _loadDeletedDocuments();

      // Reload home provider documents
      final provider = Provider.of<HomeProvider>(context, listen: false);
      await provider.loadDocuments();

      if (mounted) {
        setState(() {
          _selectedItems.clear();
        });
      }
    } catch (e) {
      print('Error deleting all documents: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error deleting all documents: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }
}
