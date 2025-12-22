import 'dart:io';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../Constants/app_constants.dart';
import '../../Models/document_model.dart';
import '../../Providers/home_provider.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/database_helper.dart';
import 'package:provider/provider.dart';

class MoveCopyScreen extends StatefulWidget {
  final DocumentModel document;
  final String action; // 'Move' or 'Copy'
  final List<Map<String, dynamic>> documentDetails; // List of DocumentDetail entries

  MoveCopyScreen({
    super.key,
    required this.document,
    required this.action,
    this.documentDetails = const [],
  });

  @override
  State<MoveCopyScreen> createState() => _MoveCopyScreenState();
}

class _MoveCopyScreenState extends State<MoveCopyScreen> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _documents = [];
  List<int> _selectedDetailIds = []; // Selected DocumentDetail IDs
  int? _selectedTargetDocId; // Selected target document ID
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize selectedDetailIds with all documentDetails if provided
    if (widget.documentDetails.isNotEmpty) {
      _selectedDetailIds = widget.documentDetails
          .map((d) => d['id'] as int?)
          .where((id) => id != null)
          .cast<int>()
          .toList();
    }
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Get documents directly from Document table
      final documents = await _db.getDocumentsNotDeleted();
      
      // Filter out the source document from the list
      final sourceDocId = int.tryParse(widget.document.id);
      _documents = documents.where((doc) {
        final docId = doc['id'] as int?;
        return docId != null && docId != sourceDocId;
      }).toList();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      log('Error loading documents: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

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
          '${widget.action} File',
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
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                : _documents.isEmpty
                    ? Center(
                        child: Text(
                          'No documents available',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppConstants.spacingM),
                        itemCount: _documents.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final docMap = _documents[index];
                          final doc = _mapToDocumentModel(docMap);
                          final docId = int.tryParse(doc.id);
                          final isSelected = docId != null && _selectedTargetDocId == docId;
                          return _buildDocumentItem(context, doc, colorScheme, isDark, isSelected: isSelected);
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
                  '${_selectedDetailIds.isEmpty ? widget.documentDetails.length : _selectedDetailIds.length} Item${(_selectedDetailIds.isEmpty ? widget.documentDetails.length : _selectedDetailIds.length) > 1 ? 's' : ''} ${_selectedTargetDocId != null ? 'Selected' : 'to ${widget.action == 'Move' ? 'Move' : 'Copy'}'}',
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
                        label: widget.action == "Move" ? 'Move here' : 'Paste here',
                        colorScheme: colorScheme,
                        isDark: isDark,
                        onTap: () {
                          // Check if items are selected
                          final detailIdsToProcess = _selectedDetailIds.isEmpty
                              ? widget.documentDetails
                                  .map((d) => d['id'] as int?)
                                  .where((id) => id != null)
                                  .cast<int>()
                                  .toList()
                              : _selectedDetailIds;

                          if (detailIdsToProcess.isEmpty) {
                            Fluttertoast.showToast(
                              msg: 'Please select items to ${widget.action.toLowerCase()}',
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.orange,
                              textColor: Colors.white,
                            );
                            return;
                          }

                          if (_selectedTargetDocId == null) {
                            Fluttertoast.showToast(
                              msg: 'Please select a target document',
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.orange,
                              textColor: Colors.white,
                            );
                            return;
                          }

                          _handleMoveCopyAction(context, _selectedTargetDocId!, detailIdsToProcess, colorScheme, provider);
                        },
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
    bool isDark, {
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: () => _handleDocumentTap(context, doc),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.spacingM,
          horizontal: AppConstants.spacingS,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.08),
            width: isSelected ? 2 : 1,
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
            // Selection indicator or Category
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(left: AppConstants.spacingS),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else
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

  void _handleDocumentTap(BuildContext context, DocumentModel targetDocument) {
    // When tapping a document, select it as target
    final docId = int.tryParse(targetDocument.id);
    if (docId != null) {
      setState(() {
        _selectedTargetDocId = docId;
      });
    }
  }

  DocumentModel _mapToDocumentModel(Map<String, dynamic> docMap) {
    final docId = docMap['id'] as int?;
    final title = docMap['title']?.toString() ?? '';
    final type = docMap['type']?.toString() ?? '';
    final favourite = (docMap['favourite'] as int? ?? 0) == 1;
    final imagePath = docMap['Image_path']?.toString() ?? '';
    final thumbnailPath = docMap['image_thumbnail']?.toString();
    final isDeleted = (docMap['is_deleted'] as int? ?? 0) == 1;
    
    DateTime createdAt;
    try {
      final createdDateStr = docMap['created_date']?.toString();
      if (createdDateStr != null && createdDateStr.isNotEmpty) {
        createdAt = DateTime.parse(createdDateStr);
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      createdAt = DateTime.now();
    }

    return DocumentModel(
      id: docId?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: title,
      createdAt: createdAt,
      location: 'In this device',
      category: type.isNotEmpty ? type : 'All Docs',
      isFavorite: favourite,
      thumbnailPath: thumbnailPath,
      imagePath: imagePath.isNotEmpty ? imagePath : thumbnailPath,
      isDeleted: isDeleted,
      deletedAt: null,
    );
  }

  Future<void> _handleMoveCopyAction(
    BuildContext context,
    int targetDocId,
    List<int> detailIdsToProcess,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) async {
    try {
      // Get source document ID
      final sourceDocId = int.tryParse(widget.document.id);
      if (sourceDocId == null) {
        Fluttertoast.showToast(
          msg: 'Invalid source document',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      if (sourceDocId == targetDocId) {
        Fluttertoast.showToast(
          msg: 'Cannot ${widget.action.toLowerCase()} to the same document',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      int processedCount = 0;

      if (widget.action == 'Move') {
        // Move: Update document_id in DocumentDetail table for selected items
        for (final detailId in detailIdsToProcess) {
          try {
            await _db.updateDocumentDetail(detailId, {
              'document_id': targetDocId,
              'updated_date': DateTime.now().toIso8601String(),
            });
            processedCount++;
          } catch (e) {
            log('Error moving DocumentDetail $detailId: $e');
          }
        }

        Fluttertoast.showToast(
          msg: '$processedCount item(s) moved successfully',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else if (widget.action == 'Copy') {
        // Copy: Create duplicate entries in DocumentDetail table with new document_id
        for (final detailId in detailIdsToProcess) {
          try {
            // Get the original DocumentDetail entry
            final originalDetail = await _db.getDocumentDetail(detailId);
            if (originalDetail == null) continue;

            // Create duplicate entry with new document_id
            final detailMap = {
              'document_id': targetDocId,
              'title': '${originalDetail['title']} (Copy)',
              'type': originalDetail['type']?.toString() ?? 'image',
              'Image_path': originalDetail['Image_path']?.toString() ?? '',
              'image_thumbnail': originalDetail['image_thumbnail']?.toString(),
              'created_date': DateTime.now().toIso8601String(),
              'updated_date': DateTime.now().toIso8601String(),
              'favourite': 0,
              'is_deleted': 0,
            };
            await _db.createDocumentDetail(detailMap);
            processedCount++;
          } catch (e) {
            log('Error copying DocumentDetail $detailId: $e');
          }
        }

        Fluttertoast.showToast(
          msg: '$processedCount item(s) copied successfully',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }

      // Refresh documents
      await provider.loadDocuments();
      
      // Navigate back
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      log('Error in move/copy action: $e');
      Fluttertoast.showToast(
        msg: 'Error: ${e.toString()}',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
}
