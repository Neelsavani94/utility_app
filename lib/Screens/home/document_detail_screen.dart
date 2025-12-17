import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../Models/document_detail_model.dart';
import '../../Models/document_model.dart';
import '../../Services/database_helper.dart';
import '../../Services/document_scan_serivce.dart';
import '../../Services/photo_editor_service.dart';
import '../../Services/clipboard_service.dart';
import '../../Routes/navigation_service.dart';
import '../../Providers/home_provider.dart';
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
  final DocumentScanner _documentScanner = DocumentScanner(
    options: DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.filter,
      pageLimit: 1,
      isGalleryImport: true,
    ),
  );
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

      final details = await _dbHelper.getDocumentDetailsByDocumentId(
        widget.document.id!,
      );

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
                const SizedBox(width: 12),
                Container(
                  height: 48,
                  width: 48,
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
                  child: IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => _showOptionsMenu(context),
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
                          childAspectRatio: 0.7,
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
            final result = await _documentScanner.scanDocument();
            await _scanService.scanAndAddPagesToDocument(
              documentId: widget.document.id!,
              result: result,
            );
            // Reload details so GridView reflects new pages
            await _loadDocumentDetails();
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
    return GestureDetector(
      onTap: () => _openInPhotoEditor(detail),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image with page number badge
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: _buildImage(detail),
                  ),
                  // Page number badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Title + actions section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      detail.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.share_outlined,
                      size: 18,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showShareDialog(detail),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showDetailMoreSheet(detail),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

    // Open ProImageEditor directly
    final photoEditorService = PhotoEditorService.instance;
    await photoEditorService.openEditorAndSave(
      context: context,
      imageFile: file,
    );
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
                      onTap: () async {
                        Navigator.pop(context);
                        await _dbHelper.moveDocumentDetailToTrash(detail.id!);
                        await _loadDocumentDetails();
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

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with title and close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                    Expanded(
                      child: Text(
                        _currentDocument?.title ?? widget.document.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Actions grid (3 per row), similar to detail bottom sheet but for document
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
                      _handleSaveDocument();
                    },
                  ),
                  _buildDetailActionButton(
                    icon: Icons.email_outlined,
                    title: 'Send mail',
                    onTap: () {
                      Navigator.pop(context);
                      _handleSendMailDocument();
                    },
                  ),
                  _buildDetailActionButton(
                    icon: Icons.drive_file_rename_outline,
                    title: 'Rename',
                    onTap: () {
                      Navigator.pop(context);
                      _handleRenameDocument();
                    },
                  ),
                  _buildDetailActionButton(
                    icon: Icons.folder_open_outlined,
                    title: 'Move',
                    onTap: () {
                      Navigator.pop(context);
                      _handleMoveDocument();
                    },
                  ),
                  _buildDetailActionButton(
                    icon: Icons.copy_outlined,
                    title: 'Copy',
                    onTap: () {
                      Navigator.pop(context);
                      _handleCopyDocument();
                    },
                  ),
                  _buildDetailActionButton(
                    icon: Icons.delete_outline,
                    title: 'Move to trash',
                    color: Colors.red,
                    onTap: () async {
                      Navigator.pop(context);
                      await _dbHelper.moveToTrash(widget.document.id!);
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ==================== Document Detail Handlers ====================

  Future<void> _handleSaveDetail(DocumentDetail detail) async {
    final colorScheme = Theme.of(context).colorScheme;
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
      final isPDF = filePath.toLowerCase().endsWith('.pdf');

      if (isPDF) {
        // For PDF, save to downloads directory
        final directory = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory('${directory.path}/Download/Scanify AI');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        final fileName = detail.title.replaceAll(RegExp(r'[^\w\s-]'), '');
        final destFile = File('${downloadsDir.path}/$fileName.pdf');
        await sourceFile.copy(destFile.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved "${detail.title}" to Downloads'),
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
        // For images, save to Pictures directory
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

          final fileName = detail.title.replaceAll(RegExp(r'[^\w\s-]'), '');
          final extension = filePath.split('.').last;
          final destFile = File('${picturesDir.path}/$fileName.$extension');
          await sourceFile.copy(destFile.path);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved "${detail.title}" to Gallery'),
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

  Future<void> _handleSendMailDetail(DocumentDetail detail) async {
    final colorScheme = Theme.of(context).colorScheme;
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

    try {
      final isPDF = filePath.toLowerCase().endsWith('.pdf');
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Please find the attached ${isPDF ? 'PDF' : 'image'}: ${detail.title}',
        subject: detail.title,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing "${detail.title}" via email'),
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

  Future<void> _handleRenameDetail(DocumentDetail detail) async {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: detail.title);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? colorScheme.surface.withOpacity(0.98)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rename Page',
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
        final updatedDetail = detail.copyWith(
          title: result,
          updatedAt: DateTime.now(),
        );
        await _dbHelper.updateDocumentDetail(updatedDetail);
        await _loadDocumentDetails();

        // Refresh home provider
        if (mounted) {
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

  Future<void> _handleMoveDetail(DocumentDetail detail) async {
    // For detail, we can move it to a different document or folder
    // For now, we'll show a message that this feature is for documents
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Move feature is available for documents, not individual pages'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleCopyDetail(DocumentDetail detail) async {
    final colorScheme = Theme.of(context).colorScheme;
    
    try {
      // Get the parent document
      final document = await _dbHelper.getDocumentById(detail.documentId);
      if (document == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Store document in clipboard
      _clipboardService.copyDocument(document);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document copied: ${document.title}'),
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
        await _dbHelper.updateDocument(updatedDocument);
        
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
