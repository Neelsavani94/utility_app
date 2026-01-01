import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../Models/document_detail_model.dart';
import '../../Models/document_model.dart';
import '../../Services/database_helper.dart';
import '../../Services/document_scan_serivce.dart';
import '../../Services/photo_editor_service.dart';
import '../../Services/clipboard_service.dart';
import '../../Services/tag_service.dart';
import '../../Routes/navigation_service.dart';
import '../../Providers/home_provider.dart';
import '../../Constants/app_constants.dart';
import '../manual_scanner/custom_scanner_screen.dart';
import 'package:provider/provider.dart';

class DocumentDetailScreen extends StatefulWidget {
  final Document document;

  const DocumentDetailScreen({Key? key, required this.document})
    : super(key: key);

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final DocumentScanService _scanService = DocumentScanService();
  final ClipboardService _clipboardService = ClipboardService.instance;
  List<DocumentDetail> _documentDetails = [];
  List<DocumentDetail> _filteredDetails = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Document? _currentDocument; // Store current document for updates

  @override
  void initState() {
    super.initState();
    _currentDocument = widget.document;
    _loadDocumentDetails();
  }

  void _filterDocuments(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredDetails = _documentDetails;
      } else {
        _filteredDetails = _documentDetails
            .where(
              (detail) => detail.title.toLowerCase().contains(_searchQuery),
            )
            .toList();
      }
    });
  }

  Future<void> _loadDocumentDetails() async {
    try {
      setState(() => _isLoading = true);

      // Get all documents from the group
      // Use document title (group name) to get all files from group table
      final groupName = widget.document.title;
      
      // Try to get by document ID first (if it exists in Documents table)
      List<DocumentDetail> details = [];
      if (widget.document.id != null && widget.document.id! > 0) {
        final detailsMaps = await _dbHelper.getDocumentDetailsByDocumentId(
        widget.document.id!,
      );
        // Convert Map to DocumentDetail - map database fields to model fields
        details = detailsMaps.map((map) {
          return DocumentDetail(
            id: map['id'] as int?,
            documentId: map['document_id'] as int,
            title: map['title'] as String,
            type: map['type'] as String,
            isFavourite: (map['favourite'] as int? ?? 0) == 1,
            imagePath: map['Image_path'] as String? ?? '',
            thumbnailPath: map['image_thumbnail'] as String?,
            createdAt: map['created_date'] != null 
                ? DateTime.parse(map['created_date'] as String)
                : DateTime.now(),
            updatedAt: map['updated_date'] != null
                ? DateTime.parse(map['updated_date'] as String)
                : DateTime.now(),
            isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
          );
        }).toList();
      }
      
      // If no details found or document ID is 0, get directly from group table
      if (details.isEmpty && groupName.isNotEmpty) {
        try {
          // final groupDocs = await _dbHelper.getGroupDocs(groupName);
          final groupDocs = <Map<String, dynamic>>[]; // TODO: Implement getGroupDocs method
          
          // Convert group docs to DocumentDetail
          for (int i = 0; i < groupDocs.length; i++) {
            final doc = groupDocs[i];
            final imgPath = doc['imgpath']?.toString() ?? '';
            final imgName = doc['imgname']?.toString() ?? '';
            final imgNote = doc['imgnote']?.toString() ?? '';
            
            // Only show entries where imgnote is not empty and is a valid number (0, 1, 2, etc.)
            if (imgNote.isEmpty) {
              developer.log('Skipping entry with empty imgnote: $imgPath');
              continue;
            }
            
            // Check if imgnote is a valid number
            final parsedOrder = int.tryParse(imgNote);
            if (parsedOrder == null) {
              developer.log('Skipping entry with non-numeric imgnote: $imgNote for $imgPath');
              continue;
            }
            
            // Only add if path is not empty AND file exists
            if (imgPath.isNotEmpty) {
              // Check if file actually exists on disk
              final file = File(imgPath);
              final fileExists = await file.exists();
              
              // Skip if file doesn't exist or is empty
              if (!fileExists) {
                developer.log('Skipping entry with non-existent file: $imgPath');
                continue;
              }
              
              // Check if file is not empty (has content)
              try {
                final fileSize = await file.length();
                if (fileSize == 0) {
                  developer.log('Skipping entry with empty file: $imgPath');
                  continue;
                }
              } catch (e) {
                developer.log('Error checking file size for $imgPath: $e');
                // If we can't check size, skip to be safe
                continue;
              }
              
              // Use parsed order from imgNote
              final order = parsedOrder;

              details.add(
                DocumentDetail(
                  id: doc['id'] as int?,
                  documentId: widget.document.id ?? 0,
                  title: imgName,
                  type: imgPath.toLowerCase().endsWith('.pdf') ? 'pdf' : 'image',
                  imagePath: imgPath,
                  createdAt: widget.document.createdAt.add(Duration(milliseconds: order)),
                  updatedAt: widget.document.createdAt.add(Duration(milliseconds: order)),
                ),
              );
            }
          }
          
          // Sort by order (from note field or by index)
          details.sort((a, b) {
            final aOrder = int.tryParse(a.title.split('_').last) ?? 0;
            final bOrder = int.tryParse(b.title.split('_').last) ?? 0;
            return aOrder.compareTo(bOrder);
          });
        } catch (e) {
          developer.log('Error loading from group table: $e');
        }
      }

      setState(() {
        _documentDetails = details;
        _filteredDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: Text(_currentDocument?.title ?? widget.document.title),
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        elevation: 0,
      ),
      floatingActionButton: _buildFloatingActionButton(
        context,
        colorScheme,
        isDark,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          // Search and More button row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: _filterDocuments,
                      decoration: InputDecoration(
                        hintText: 'Search pages...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                : _filteredDetails.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: _filteredDetails.length,
                    itemBuilder: (context, index) {
                      final detail = _filteredDetails[index];
                      return _buildGridItem(detail, index, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.secondary],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await _requestCameraPermissionAndShowDialog(
              context,
              colorScheme,
              isDark,
            );
          },
          borderRadius: BorderRadius.circular(32),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Future<void> _requestCameraPermissionAndShowDialog(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) async {
    // Request camera permission
    final status = await Permission.camera.request();

    if (status.isGranted) {
      // Permission granted, navigate to custom scanner screen
      if (context.mounted) {
        // Pass documentId to CustomScannerScreen so images are saved to DocumentDetail table
        final documentId = widget.document.id;
        final scannerResult = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => CustomScannerScreen(
              documentId: documentId,
            ),
          ),
        );

        // If AI scanner was selected, open it and add pages to document
        if (scannerResult == 'ai' && context.mounted) {
          await _scanWithAIScannerForDocumentDetail();
        }
        
        // Reload document details after returning from scanner
        if (context.mounted) {
          await _loadDocumentDetails();
          final provider = Provider.of<HomeProvider>(context, listen: false);
          provider.loadDocuments();
        }
      }
    } else if (status.isDenied) {
      // Permission denied, show message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Camera permission is required to use this feature',
            ),
            backgroundColor: colorScheme.error,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
      }
    } else if (status.isPermanentlyDenied) {
      // Permission permanently denied, open app settings
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Camera Permission Required'),
            content: const Text(
              'Camera permission is required to use this feature. Please enable it in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _scanWithAIScannerForDocumentDetail() async {
    try {
      if (widget.document.id == null) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Invalid document ID',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      // AI Document Scanner with filter mode
      final aiScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.jpeg,
          mode: ScannerMode.filter,
          pageLimit: 1,
          isGalleryImport: true,
        ),
      );

      DocumentScanningResult result = await aiScanner.scanDocument();
      developer.log(result.images.toString());
      
      // Add pages to existing document
      await _scanService.scanAndAddPagesToDocument(
        documentId: widget.document.id!,
        result: result,
      );

      // Reload document details after adding pages
      if (mounted) {
        await _loadDocumentDetails();
        Fluttertoast.showToast(
          msg: 'Pages added successfully',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      developer.log('Error in AI Scanner for Document Detail: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error scanning document: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isEmpty
                    ? Icons.photo_library_outlined
                    : Icons.search_off,
                size: 80,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isEmpty ? 'No Pages Found' : 'No Results',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'This document doesn\'t contain any pages yet'
                  : 'No pages match "$_searchQuery"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(DocumentDetail detail, int index, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: () => _openInPhotoEditor(detail),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? colorScheme.outline.withOpacity(0.1)
                : colorScheme.outline.withOpacity(0.08),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail - takes most of the space
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: _buildDetailThumbnail(detail, colorScheme, isDark),
                  ),
                  // Page number badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Text(
                      detail.title,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Date
                    Text(
                      _formatDate(detail.createdAt),
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    // Action icons row (without favorite icon)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Phone icon
                        Icon(
                          Icons.phone_android_rounded,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        // Share icon
                        GestureDetector(
                          onTap: () => _showShareDialog(detail),
                          child: Icon(
                            Icons.share_rounded,
                            size: 14,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        // More icon
                        GestureDetector(
                          onTap: () => _showDetailMoreSheet(detail),
                          child: Icon(
                            Icons.more_vert_rounded,
                            size: 14,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailThumbnail(
    DocumentDetail detail,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final imagePath = detail.thumbnailPath ?? detail.imagePath;
    final file = File(imagePath);

    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              border: Border.all(
                color: isDark
                    ? colorScheme.outline.withOpacity(0.1)
                    : colorScheme.outline.withOpacity(0.08),
                width: 0.5,
              ),
            ),
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  child: Icon(
                    detail.type == 'pdf'
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_rounded,
                    color: colorScheme.onSurface.withOpacity(0.4),
                    size: 40,
                  ),
                );
              },
            ),
          );
        }

        // Default icon
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            border: Border.all(
              color: isDark
                  ? colorScheme.outline.withOpacity(0.1)
                  : colorScheme.outline.withOpacity(0.08),
              width: 0.5,
            ),
          ),
          child: Icon(
            detail.type == 'pdf'
                ? Icons.picture_as_pdf_rounded
                : Icons.image_rounded,
            color: colorScheme.onSurface.withOpacity(0.4),
            size: 40,
          ),
        );
      },
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _openInPhotoEditor(DocumentDetail detail) async {
    final filePath = detail.imagePath;
    if (filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File path not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if this is an existing document detail (has an ID) to update it
    // Otherwise, create a new entry
    final photoEditorService = PhotoEditorService.instance;
    if (detail.id != null && detail.id! > 0) {
      // Update existing document detail
      await photoEditorService.openEditorAndUpdateDocumentDetail(
        context: context,
        imageFile: file,
        documentDetailId: detail.id!,
      );
      
      // Reload document details after update
      await _loadDocumentDetails();
    } else {
      // Create new entry (fallback for cases where detail doesn't have an ID)
      await photoEditorService.openEditorAndSave(
        context: context,
        imageFile: file,
      );
    }
  }

  Widget _buildImage(DocumentDetail detail) {
    final imagePath = detail.thumbnailPath ?? detail.imagePath;
    final file = File(imagePath);

    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorImage();
            },
          );
        }

        return _buildErrorImage();
      },
    );
  }

  Future<void> _showShareDialog(DocumentDetail detail) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Share as'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF'),
                onTap: () async {
                  Navigator.pop(context);
                  await _shareDetailAsPdf(detail);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  await _shareDetailAsPhoto(detail);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareDetailAsPhoto(DocumentDetail detail) async {
    final filePath = detail.imagePath;
    if (filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image path not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image file not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await Share.shareXFiles([XFile(filePath)], text: detail.title);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareDetailAsPdf(DocumentDetail detail) async {
    // If this detail is already a PDF page, just share the file.
    final pathLower = detail.imagePath.toLowerCase();
    if (pathLower.endsWith('.pdf')) {
      try {
        await Share.shareXFiles([XFile(detail.imagePath)], text: detail.title);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Otherwise, you can implement image-to-PDF conversion here.
    // For now we fall back to sharing the image directly.
    await _shareDetailAsPhoto(detail);
  }

  void _showDetailMoreSheet(DocumentDetail detail) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close icon
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: _buildImage(detail),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        detail.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(),
              const SizedBox(height: 8),
              // Actions grid (3 per row)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 16,
                  children: [
                    _buildDetailActionButton(
                      icon: Icons.save_alt_outlined,
                      title: 'Save',
                      onTap: () {
                        Navigator.pop(context);
                        _handleSaveDetail(detail);
                      },
                    ),
                    _buildDetailActionButton(
                      icon: Icons.email_outlined,
                      title: 'Send mail',
                      onTap: () {
                        Navigator.pop(context);
                        _handleSendMailDetail(detail);
                      },
                    ),
                    _buildDetailActionButton(
                      icon: Icons.drive_file_rename_outline,
                      title: 'Rename',
                      onTap: () {
                        Navigator.pop(context);
                        _handleRenameDetail(detail);
                      },
                    ),
                    _buildDetailActionButton(
                      icon: Icons.folder_open_outlined,
                      title: 'Move',
                      onTap: () {
                        Navigator.pop(context);
                        _handleMoveDetail(detail);
                      },
                    ),
                    _buildDetailActionButton(
                      icon: Icons.copy_outlined,
                      title: 'Copy',
                      onTap: () {
                        Navigator.pop(context);
                        _handleCopyDetail(detail);
                      },
                    ),
                    _buildDetailActionButton(
                      icon: Icons.delete_outline,
                      title: 'Trash',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _handleTrashDetail(detail);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = color ?? (isDark ? Colors.white : Colors.black87);
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 32) / 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: textColor),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorImage() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Image not\navailable',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    final options = <Map<String, dynamic>>[
      {
        'icon': Icons.drive_file_move_rounded,
        'title': 'Move Tools',
        'color': colorScheme.primary,
      },
      if (_clipboardService.hasCopiedDocument() ||
          _clipboardService.hasCopiedGroup())
        {
          'icon': Icons.paste_rounded,
          'title': 'Paste',
          'color': colorScheme.secondary,
        },
      {
        'icon': Icons.save_rounded,
        'title': 'Save',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.email_rounded,
        'title': 'Send Mail',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.document_scanner_rounded,
        'title': 'OCR',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.lock_rounded,
        'title': 'Lock',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.copy_rounded,
        'title': 'Copy Tools',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.drive_file_rename_outline_rounded,
        'title': 'Rename',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.label_rounded,
        'title': 'Tags',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.delete_outline_rounded,
        'title': 'Move to Trash',
        'color': Colors.red,
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    colorScheme.surface.withOpacity(0.98),
                    colorScheme.surface.withOpacity(0.95),
                  ]
                : [Colors.white, Colors.white.withOpacity(0.98)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Document Info Header with Premium Design
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withOpacity(0.1),
                      colorScheme.secondary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              child: Row(
                children: [
                    // Document Icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.description_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Document Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                        _currentDocument?.title ?? widget.document.title,
                        style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(widget.document.createdAt),
                                style: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                  ),
                ],
              ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surface.withOpacity(0.3)
                            : colorScheme.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Icon(
                            Icons.close_rounded,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Options Grid with Premium Design
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 200 + (index * 30)),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.scale(
                            scale: 0.9 + (value * 0.1),
                            child: child,
                  ),
                        );
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                            _handleDocumentOption(
                              context,
                              option['title'] as String,
                              colorScheme,
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? [colorScheme.surface, colorScheme.surface]
                                    : [
                                        Colors.white,
                                        colorScheme.surface.withOpacity(0.5),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (option['color'] as Color).withOpacity(
                                  0.15,
                                ),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        (option['color'] as Color),
                                        (option['color'] as Color).withOpacity(
                                          0.7,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    option['icon'] as IconData,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    option['title'] as String,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.1,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                            ),
                          ),
                        );
                    },
                  ),
              ),
              SizedBox(
                height: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _handleDocumentOption(
    BuildContext context,
    String option,
    ColorScheme colorScheme,
  ) {
    switch (option) {
      case 'Move':
      case 'Move Tools':
        _handleMoveDocument();
        break;
      case 'Save':
        _handleSaveDocument();
        break;
      case 'Send Mail':
        _handleSendMailDocument();
        break;
      case 'OCR':
        _handleOCRDocument();
        break;
      case 'Lock':
        _handleLockDocument(colorScheme);
        break;
      case 'Copy':
      case 'Copy Tools':
        _handleCopyDocument();
        break;
      case 'Paste':
        _handlePasteDocument(colorScheme);
        break;
      case 'Rename':
        _handleRenameDocument();
        break;
      case 'Tags':
        _handleChangeTagsDocument(colorScheme);
        break;
      case 'Move to Trash':
        _handleMoveToTrashDocument(colorScheme);
        break;
    }
  }

  // ==================== Document Detail Handlers ====================

  Future<void> _handleSaveDetail(DocumentDetail detail) async {
    final colorScheme = Theme.of(context).colorScheme;
    final filePath = detail.imagePath;
    
    if (filePath.isEmpty) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'File path not available',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
      return;
    }

    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'File not found',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
      return;
    }

    try {
      final isPDF = filePath.toLowerCase().endsWith('.pdf');

      if (isPDF) {
        // For PDF, save to device Download folder (public Downloads folder)
        Directory? pdfDir;
        if (Platform.isAndroid) {
          // For Android, use the public Downloads directory
          final List<String> possiblePaths = [
            '/storage/emulated/0/Download',
            '/sdcard/Download',
            '/storage/sdcard0/Download',
            '/mnt/sdcard/Download',
          ];
          
          bool pathFound = false;
          Directory? tempDir;
          for (final pathStr in possiblePaths) {
            try {
              tempDir = Directory(pathStr);
              if (await tempDir.exists()) {
                pathFound = true;
                break;
              } else {
                try {
                  await tempDir.create(recursive: true);
                  if (await tempDir.exists()) {
                    pathFound = true;
                    break;
                  }
                } catch (e) {
                  continue;
                }
              }
            } catch (e) {
              continue;
            }
          }
          
          if (!pathFound || tempDir == null) {
            throw Exception('Cannot access device Download folder. Please check storage permissions.');
          } else {
            pdfDir = tempDir;
          }
        } else if (Platform.isIOS) {
          final directory = await getApplicationDocumentsDirectory();
          pdfDir = Directory('${directory.path}/Download');
          if (!await pdfDir.exists()) {
            await pdfDir.create(recursive: true);
          }
        }

        if (pdfDir == null) {
          throw Exception('Could not determine PDF save location');
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final sanitizedName = detail.title.replaceAll(RegExp(r'[^\w\s-]'), '_');
        final pdfFileName = '${sanitizedName}_$timestamp.pdf';
        final pdfPath = '${pdfDir.path}/$pdfFileName';
        await sourceFile.copy(pdfPath);

        if (mounted) {
          Fluttertoast.showToast(
            msg: 'PDF saved: $pdfFileName\nLocation: Downloads folder',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: colorScheme.primary,
            textColor: Colors.white,
          );
        }
      } else {
        // For images, use SaverGallery to save to gallery
        try {
          // Request permission
          PermissionStatus? status;
          if (Platform.isAndroid) {
            status = await Permission.photos.request();
            if (!status.isGranted) {
              status = await Permission.storage.request();
            }
          } else if (Platform.isIOS) {
            status = await Permission.photos.request();
          }

          if (status != null && !status.isGranted && !status.isLimited) {
            if (status.isPermanentlyDenied && mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Permission Required'),
                  content: const Text(
                    'Photo library permission is required to save images to gallery. '
                    'Please enable it in app settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        openAppSettings();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              );
              return;
            }
          }

          final imageBytes = await sourceFile.readAsBytes();
          final sanitizedName = detail.title.replaceAll(RegExp(r'[^\w\s-]'), '_');
          final extension = filePath.split('.').last;
          final fileName = '${sanitizedName}.$extension';

          final result = await SaverGallery.saveImage(
            imageBytes,
            fileName: fileName,
            skipIfExists: false,
          );

          if (mounted) {
            if (result.isSuccess) {
              Fluttertoast.showToast(
                msg: 'Saved "$fileName" to gallery',
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                backgroundColor: colorScheme.primary,
                textColor: Colors.white,
              );
            } else {
              Fluttertoast.showToast(
                msg: 'Failed to save image: ${result.errorMessage ?? "Unknown error"}',
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                backgroundColor: Colors.red,
                textColor: Colors.white,
              );
            }
          }
        } catch (e) {
          if (mounted) {
            Fluttertoast.showToast(
              msg: 'Error saving to gallery: $e',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error saving file: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _handleSendMailDetail(DocumentDetail detail) async {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emailController = TextEditingController();

    final result = await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.98)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.email_rounded,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          'Send Mail',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Icon(
                            Icons.close_rounded,
                            color: colorScheme.primary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingXL),
                // Email Input
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter E-mail Id',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? colorScheme.surface.withOpacity(0.3)
                        : colorScheme.surface.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingM,
                      vertical: AppConstants.spacingM,
                    ),
                  ),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                const SizedBox(height: AppConstants.spacingXL),
                // OK Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final email = emailController.text.trim();
                      if (email.isNotEmpty) {
                        Navigator.pop(context, email);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null && result is String) {
      final email = result.trim();
      if (email.isEmpty) {
        return;
      }

      final filePath = detail.imagePath;
      if (filePath.isEmpty) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'File path not available',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'File not found',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      try {
        final isPDF = filePath.toLowerCase().endsWith('.pdf');
        await Share.shareXFiles(
          [XFile(filePath)],
          text:
              'Please find the attached ${isPDF ? 'PDF' : 'image'}: ${detail.title}\n\nTo: $email',
          subject: detail.title,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sharing "${detail.title}" - Select email to send to $email',
              ),
              backgroundColor: colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Error sending email: $e',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      }
    }
  }

  Future<void> _handleRenameDetail(DocumentDetail detail) async {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: detail.title);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface.withOpacity(0.98) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          'Set Page Name',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Icon(
                            Icons.close_rounded,
                            color: colorScheme.primary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingXL),
                // Name Input
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Page name',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? colorScheme.surface.withOpacity(0.3)
                        : colorScheme.surface.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingM,
                      vertical: AppConstants.spacingM,
                    ),
                  ),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                const SizedBox(height: AppConstants.spacingL),
                // Rename Button
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final newName = nameController.text.trim();
                          if (newName.isNotEmpty) {
                            Navigator.pop(context);
                            try {
                              final updatedDetail = detail.copyWith(
                                title: newName,
                                updatedAt: DateTime.now(),
                              );
                              await _dbHelper.updateDocumentDetail(
                                updatedDetail.id!,
                                updatedDetail.toMap(),
                              );
                              await _loadDocumentDetails();

                              // Refresh home provider
                              if (mounted) {
                                final provider =
                                    Provider.of<HomeProvider>(context, listen: false);
                                provider.loadDocuments();

                                Fluttertoast.showToast(
                                  msg: 'Renamed to "$newName"',
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: colorScheme.primary,
                                  textColor: Colors.white,
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                Fluttertoast.showToast(
                                  msg: 'Error renaming: $e',
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text(
                          'Rename',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleMoveDetail(DocumentDetail detail) async {
    final provider = Provider.of<HomeProvider>(context, listen: false);
    
    try {
      // Get the parent document
      final documentMap = await _dbHelper.getDocument(detail.documentId);
      if (documentMap == null) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Document not found',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      // Convert Map to Document object
      final document = Document(
        id: documentMap['id'] as int?,
        title: documentMap['title'] as String,
        type: documentMap['type'] as String,
        isFavourite: (documentMap['favourite'] as int? ?? 0) == 1,
        imagePath: documentMap['Image_path'] as String? ?? '',
        thumbnailPath: documentMap['image_thumbnail'] as String?,
        createdAt: documentMap['created_date'] != null
            ? DateTime.parse(documentMap['created_date'] as String)
            : DateTime.now(),
        updatedAt: documentMap['updated_date'] != null
            ? DateTime.parse(documentMap['updated_date'] as String)
            : DateTime.now(),
        isDeleted: (documentMap['is_deleted'] as int? ?? 0) == 1,
      );

      // Get document ID
      final documentId = document.id;
      if (documentId == null) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Invalid document ID',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      // Get all DocumentDetail entries for this document
      final documentDetails = await _dbHelper
          .getDocumentDetailsByDocumentIdNotDeleted(documentId);

      if (documentDetails.isEmpty) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'No items found in this document',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
        }
        return;
      }

      // Convert Document to DocumentModel
      final documentModel = DocumentModel.fromDocument(document);

      // Navigate to MoveCopyScreen
      await NavigationService.toMoveCopy(
        arguments: {
          'document': documentModel,
          'action': 'Move',
          'documentDetails': documentDetails,
        },
      );

      // Reload after move
      if (mounted) {
        await _loadDocumentDetails();
        provider.loadDocuments();
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error moving document: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _handleCopyDetail(DocumentDetail detail) async {
    final provider = Provider.of<HomeProvider>(context, listen: false);
    
    try {
      // Get the parent document
      final documentMap = await _dbHelper.getDocument(detail.documentId);
      if (documentMap == null) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Document not found',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      // Convert Map to Document object
      final document = Document(
        id: documentMap['id'] as int?,
        title: documentMap['title'] as String,
        type: documentMap['type'] as String,
        isFavourite: (documentMap['favourite'] as int? ?? 0) == 1,
        imagePath: documentMap['Image_path'] as String? ?? '',
        thumbnailPath: documentMap['image_thumbnail'] as String?,
        createdAt: documentMap['created_date'] != null
            ? DateTime.parse(documentMap['created_date'] as String)
            : DateTime.now(),
        updatedAt: documentMap['updated_date'] != null
            ? DateTime.parse(documentMap['updated_date'] as String)
            : DateTime.now(),
        isDeleted: (documentMap['is_deleted'] as int? ?? 0) == 1,
      );

      // Get document ID
      final documentId = document.id;
      if (documentId == null) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Invalid document ID',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      // Get all DocumentDetail entries for this document
      final documentDetails = await _dbHelper
          .getDocumentDetailsByDocumentIdNotDeleted(documentId);

      if (documentDetails.isEmpty) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'No items found in this document',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
        }
        return;
      }

      // Convert Document to DocumentModel
      final documentModel = DocumentModel.fromDocument(document);

      // Navigate to MoveCopyScreen
      await NavigationService.toMoveCopy(
        arguments: {
          'document': documentModel,
          'action': 'Copy',
          'documentDetails': documentDetails,
        },
      );

      // Reload after copy
      if (mounted) {
        await _loadDocumentDetails();
        provider.loadDocuments();
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error copying document: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _handleTrashDetail(DocumentDetail detail) async {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface.withOpacity(0.98) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingXL),
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXL),
                // Title
                Text(
                  'Are you Sure ?',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                // Message
                Text(
                  'You want to move to Trash ?',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
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
                            fontSize: 16,
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
                          try {
                            await _dbHelper.softDeleteDocumentDetail(detail.id!);
                            await _loadDocumentDetails();

                            // Refresh home provider
                            if (mounted) {
                              final provider =
                                  Provider.of<HomeProvider>(context, listen: false);
                              provider.loadDocuments();

                              Fluttertoast.showToast(
                                msg: '"${detail.title}" moved to trash',
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Fluttertoast.showToast(
                                msg: 'Error moving to trash: $e',
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text(
                          'Trash',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== Document Handlers ====================

  Future<void> _handleSaveDocument() async {
    final colorScheme = Theme.of(context).colorScheme;
    final filePath = widget.document.imagePath;
    
    if (filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File path not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final isPDF = filePath.toLowerCase().endsWith('.pdf') ||
          widget.document.type.toLowerCase() == 'pdf';

      if (isPDF) {
        final directory = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory('${directory.path}/Download/Scanify AI');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        final fileName = widget.document.title.replaceAll(RegExp(r'[^\w\s-]'), '');
        final destFile = File('${downloadsDir.path}/$fileName.pdf');
        await sourceFile.copy(destFile.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved "${widget.document.title}" to Downloads'),
              backgroundColor: colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        try {
          Directory? picturesDir;
          if (Platform.isAndroid) {
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              picturesDir = Directory(
                '${externalDir.path.split('/Android')[0]}/Pictures/Scanify AI',
              );
            }
          } else if (Platform.isIOS) {
            final appDir = await getApplicationDocumentsDirectory();
            picturesDir = Directory('${appDir.path}/Pictures/Scanify AI');
          }

          if (picturesDir == null) {
            final directory = await getApplicationDocumentsDirectory();
            picturesDir = Directory(
              '${directory.path}/Download/Scanify AI/Pictures',
            );
          }

          if (!await picturesDir.exists()) {
            await picturesDir.create(recursive: true);
          }

          final fileName = widget.document.title.replaceAll(RegExp(r'[^\w\s-]'), '');
          final extension = filePath.split('.').last;
          final destFile = File('${picturesDir.path}/$fileName.$extension');
          await sourceFile.copy(destFile.path);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved "${widget.document.title}" to Gallery'),
                backgroundColor: colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            Fluttertoast.showToast(
              msg: 'Error saving to gallery: $e',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error saving file: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _handleSendMailDocument() async {
    final colorScheme = Theme.of(context).colorScheme;
    final filePath = widget.document.imagePath;
    
    if (filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File path not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final isPDF = filePath.toLowerCase().endsWith('.pdf') ||
          widget.document.type.toLowerCase() == 'pdf';

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Please find the attached ${isPDF ? 'PDF' : 'image'}: ${widget.document.title}',
        subject: widget.document.title,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing "${widget.document.title}" via email'),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

  Future<void> _handleRenameDocument() async {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: widget.document.title);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? colorScheme.surface.withOpacity(0.98)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rename Document',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
          style: TextStyle(color: colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(context, newName);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final updatedDocument = widget.document.copyWith(
          title: result,
          updatedAt: DateTime.now(),
        );
        // await _dbHelper.updateDocument(updatedDocument); // TODO: Fix updateDocument signature
        await _dbHelper.updateDocument(updatedDocument.id!, updatedDocument.toMap());
        
        // Update current document and refresh
        if (mounted) {
          setState(() {
            _currentDocument = updatedDocument;
          });
          
          final provider = Provider.of<HomeProvider>(context, listen: false);
          provider.loadDocuments();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Renamed to "$result"'),
              backgroundColor: colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Error renaming: $e',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      }
    }
  }

  Future<void> _handleMoveDocument() async {
    // Navigate to move/copy screen
    final documentModel = DocumentModel.fromDocument(widget.document);
    await NavigationService.toMoveCopy(
      arguments: {
        'document': documentModel,
        'action': 'Move',
      },
    );
    // Reload after move
    if (mounted) {
      await _loadDocumentDetails();
    }
  }

  Future<void> _handleCopyDocument() async {
    final colorScheme = Theme.of(context).colorScheme;
    
    try {
      // Store document in clipboard
      _clipboardService.copyDocument(widget.document);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document copied: ${widget.document.title}'),
            backgroundColor: colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error copying: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _handleOCRDocument() async {
    try {
      final filePath = widget.document.imagePath;
      
      if (filePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image path not available'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image file not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if it's a PDF (OCR works with images, not PDFs)
      final isPDF = filePath.toLowerCase().endsWith('.pdf') ||
          widget.document.type.toLowerCase() == 'pdf';

      if (isPDF) {
        Fluttertoast.showToast(
          msg: 'OCR is available for images only. PDFs are not supported.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      // Navigate to ExtractTextScreen with the image path
      if (mounted) {
        NavigationService.toExtractText(imagePath: filePath);
      }
    } catch (e) {
      developer.log('Error opening OCR screen: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error opening OCR: ${e.toString()}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  void _handleLockDocument(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pinControllers = List.generate(4, (_) => TextEditingController());
    int currentPinIndex = 0;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surface.withOpacity(0.98)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lock File',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Icon(
                              Icons.close_rounded,
                              color: colorScheme.primary,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Choose Pin',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark
                              ? colorScheme.surface.withOpacity(0.3)
                              : colorScheme.surface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: currentPinIndex == index
                                ? colorScheme.primary
                                : colorScheme.outline.withOpacity(0.2),
                            width: currentPinIndex == index ? 2 : 1,
                          ),
                        ),
                        child: TextField(
                          controller: pinControllers[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 3) {
                              setState(() {
                                currentPinIndex = index + 1;
                              });
                              FocusScope.of(context).nextFocus();
                            } else if (value.isEmpty && index > 0) {
                              setState(() {
                                currentPinIndex = index - 1;
                              });
                              FocusScope.of(context).previousFocus();
                            }
                          },
                          onTap: () {
                            setState(() {
                              currentPinIndex = index;
                            });
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final pin = pinControllers.map((c) => c.text).join();
                        if (pin.length == 4) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Document "${widget.document.title}" locked with PIN'),
                              backgroundColor: colorScheme.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        } else {
                          Fluttertoast.showToast(
                            msg: 'Please enter a 4-digit PIN',
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.orange,
                            textColor: Colors.white,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Create Lock',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePasteDocument(ColorScheme colorScheme) async {
    if (!_clipboardService.hasCopiedDocument() && !_clipboardService.hasCopiedGroup()) {
      Fluttertoast.showToast(
        msg: 'No document or group copied',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    try {
      if (_clipboardService.hasCopiedGroup()) {
        // Handle group paste - similar to home screen
        final sourceGroupName = _clipboardService.getCopiedGroupName()!;
        final targetGroupName = widget.document.title;

        if (sourceGroupName == targetGroupName) {
          Fluttertoast.showToast(
            msg: 'Cannot paste group into itself',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
          return;
        }

        Fluttertoast.showToast(
          msg: 'Group paste functionality coming soon',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: colorScheme.primary,
          textColor: Colors.white,
        );
      } else if (_clipboardService.hasCopiedDocument()) {
        // Handle document paste
        Fluttertoast.showToast(
          msg: 'Document paste functionality coming soon',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: colorScheme.primary,
          textColor: Colors.white,
        );
      }

      // Clear clipboard after paste
      _clipboardService.clearClipboard();

      // Reload details
      if (mounted) {
        await _loadDocumentDetails();
      }
    } catch (e) {
      developer.log('Error pasting: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error pasting: ${e.toString()}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  void _handleChangeTagsDocument(ColorScheme colorScheme) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tagService = TagService.instance;
    
    try {
      final tags = await tagService.getAllTags();
      if (tags.isEmpty) {
        Fluttertoast.showToast(
          msg: 'No tags available',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      String? selectedTag;
      int? selectedTagId;
      
      // Get current document tag
      final currentDocMap = await _dbHelper.getDocument(widget.document.id!);
      if (currentDocMap != null) {
        final currentType = currentDocMap['type'] as String? ?? '';
        selectedTag = currentType;
        // Find tag ID by title
        final tag = await tagService.findTagByTitle(currentType);
        selectedTagId = tag?.id;
      }

      if (!mounted) return;

      final result = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.98)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Change Tag',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: tags.length,
                      itemBuilder: (context, index) {
                        final tag = tags[index];
                        
                        return RadioListTile<String>(
                          title: Text(tag.title),
                          value: tag.title,
                          groupValue: selectedTag,
                          onChanged: (value) {
                            setState(() {
                              selectedTag = value;
                              selectedTagId = tag.id;
                            });
                          },
                          activeColor: colorScheme.primary,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (selectedTag != null && selectedTagId != null) {
                          Navigator.pop(context, selectedTag);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            ),
          ),
        ),
      );

      if (result != null && selectedTagId != null) {
        await _updateDocumentTag(selectedTagId!, result, colorScheme);
      }
    } catch (e) {
      developer.log('Error loading tags: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error loading tags: ${e.toString()}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _updateDocumentTag(
    int tagId,
    String tagTitle,
    ColorScheme colorScheme,
  ) async {
    try {
      await _dbHelper.updateDocument(widget.document.id!, {
        'type': tagTitle,
        'updated_date': DateTime.now().toIso8601String(),
      });

      // Update current document
      if (mounted) {
        setState(() {
          _currentDocument = widget.document.copyWith(
            type: tagTitle,
            updatedAt: DateTime.now(),
          );
        });

        // Refresh home provider
        final provider = Provider.of<HomeProvider>(context, listen: false);
        provider.loadDocuments();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag changed to "$tagTitle"'),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error updating tag: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  void _handleMoveToTrashDocument(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface.withOpacity(0.98) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Are you Sure ?',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You want to move to Trash ?',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colorScheme.outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _dbHelper.softDeleteDocument(widget.document.id!);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('Document moved to trash'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Move to Trash',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Image Viewer Screen
class ImageViewerScreen extends StatelessWidget {
  final String imagePath;
  final String imageName;

  const ImageViewerScreen({
    Key? key,
    required this.imagePath,
    required this.imageName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(imageName, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }
}

// PDF Viewer Screen
class PDFViewerScreen extends StatelessWidget {
  final String pdfPath;

  const PDFViewerScreen({Key? key, required this.pdfPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Viewer')),
      body: const Center(
        child: Text('PDF Viewer - Implement with pdf_viewer package'),
      ),
    );
  }
}
