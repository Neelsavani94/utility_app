import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../Routes/navigation_service.dart';
import '../import_files/import_files_screen.dart';
import '../../Services/database_helper.dart';
import '../../Services/file_storage_service.dart';
import '../../Providers/home_provider.dart';
import 'package:provider/provider.dart';
import '../../Models/document_model.dart';
import '../../Models/document_detail_model.dart';

class ArrangeFilesScreen extends StatefulWidget {
  final List<File> files;
  final DocumentModel? document;

  const ArrangeFilesScreen({
    super.key,
    required this.files,
    this.document,
  });

  @override
  State<ArrangeFilesScreen> createState() => _ArrangeFilesScreenState();
}

class _ArrangeFilesScreenState extends State<ArrangeFilesScreen> {
  late List<FileItem> _fileItems;
  Set<int> _selectedIndices = {};
  bool _isSaving = false;
  List<FileItem>? _tempOldFileList;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FileStorageService _fileStorageService = FileStorageService.instance;

  @override
  void initState() {
    super.initState();
    _fileItems = widget.files.asMap().entries.map((entry) {
      return FileItem(
        file: entry.value,
        orderIndex: entry.key,
      );
    }).toList();
    // Initialize all files as selected
    _selectedIndices = Set.from(List.generate(_fileItems.length, (index) => index));
    _loadPageCounts();
  }

  Future<void> _loadPageCounts() async {
    for (int i = 0; i < _fileItems.length; i++) {
      final filePath = _fileItems[i].file.path;
      if (filePath.toLowerCase().endsWith('.pdf')) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            final pdfBytes = await file.readAsBytes();
            final pdfDocument = PdfDocument(inputBytes: pdfBytes);
            final pageCount = pdfDocument.pages.count;
            pdfDocument.dispose();

            setState(() {
              _fileItems[i] = _fileItems[i].copyWith(pageCount: pageCount);
            });
          }
        } catch (e) {
          setState(() {
            _fileItems[i] = _fileItems[i].copyWith(pageCount: 1);
          });
        }
      } else {
        setState(() {
          _fileItems[i] = _fileItems[i].copyWith(pageCount: 1);
        });
      }
    }
  }

  Future<void> _addMoreFiles() async {
    // Store old file list temporarily when add button is clicked
    _tempOldFileList = List.from(_fileItems);
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ImportFilesScreen(forArrange: true),
      ),
    );
    
    // Handle result if files are returned
    if (result != null && result is List<File>) {
      await _addFilesToList(result);
    }
  }

  Future<void> _addFilesToList(List<File> newFiles) async {
    if (newFiles.isEmpty) {
      return;
    }

    // If temp old file list exists, restore old files first
    if (_tempOldFileList != null && _tempOldFileList!.isNotEmpty) {
      setState(() {
        // Clear current list and restore old files first
        _fileItems = List.from(_tempOldFileList!);
        // Rebuild selected indices for old files
        _selectedIndices = Set.from(List.generate(_fileItems.length, (index) => index));
        // Update order indices for old files
        for (int i = 0; i < _fileItems.length; i++) {
          _fileItems[i] = _fileItems[i].copyWith(orderIndex: i);
        }
      });
      // Clear temp list after using it
      _tempOldFileList = null;
    }

    // Load page counts for new PDF files and add them after old files
    for (final file in newFiles) {
      int pageCount = 1;
      if (file.path.toLowerCase().endsWith('.pdf')) {
        try {
          if (await file.exists()) {
            final pdfBytes = await file.readAsBytes();
            final pdfDocument = PdfDocument(inputBytes: pdfBytes);
            pageCount = pdfDocument.pages.count;
            pdfDocument.dispose();
          }
        } catch (e) {
          pageCount = 1;
        }
      }

      setState(() {
        final startIndex = _fileItems.length;
        _fileItems.add(FileItem(
          file: file,
          orderIndex: startIndex,
          pageCount: pageCount,
        ));
        _selectedIndices.add(startIndex);
      });
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _removeFile(int index) {
    setState(() {
      _fileItems.removeAt(index);
      _selectedIndices.remove(index);
      // Rebuild indices
      final newIndices = <int>{};
      for (int i = 0; i < _fileItems.length; i++) {
        if (_selectedIndices.contains(i)) {
          newIndices.add(i);
        }
      }
      _selectedIndices = newIndices;
      // Update order indices
      for (int i = 0; i < _fileItems.length; i++) {
        _fileItems[i] = _fileItems[i].copyWith(orderIndex: i);
      }
    });
  }

  Future<void> _saveFiles() async {
    if (_selectedIndices.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one file'),
          backgroundColor: colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Get selected files in order
      final selectedFiles = _selectedIndices.toList()..sort();
      if (selectedFiles.isEmpty) {
        throw Exception('No files selected');
      }

      // ========== STEP 1: Save first file as Document ==========
      final firstFileItem = _fileItems[selectedFiles[0]];
      final firstFile = firstFileItem.file;
      final isFirstPDF = firstFile.path.toLowerCase().endsWith('.pdf');
      
      int? documentId;
      Document? document;
      
      if (isFirstPDF) {
        final pdfBytes = await firstFile.readAsBytes();
        final fileName = _getFileName(firstFile);
        documentId = await _fileStorageService.savePDFFile(
          pdfBytes: pdfBytes,
          fileName: fileName,
          title: _getFileNameWithoutExtension(fileName),
        );
      } else {
        final fileName = _getFileName(firstFile);
        documentId = await _fileStorageService.saveImageFileFromFile(
          imageFile: firstFile,
          title: _getFileNameWithoutExtension(fileName),
        );
      }

      if (documentId == null) {
        throw Exception('Failed to save first file');
      }

      // Get the created document
      document = await _dbHelper.getDocumentById(documentId);
      if (document == null) {
        throw Exception('Document not found after creation');
      }

      // ========== STEP 2: Create group for backward compatibility ==========
      // This maintains compatibility with existing group-based structure
      final groupName = document.title;
      final groupDate = DateTime.now().toIso8601String();
      
      try {
        await _dbHelper.createGroup(
          groupName: groupName,
          groupDate: groupDate,
          groupFirstImg: document.imagePath,
        );
      } catch (e) {
        // Group might already exist, that's okay - just update it
        print('Group might already exist, continuing...');
      }

      // Create group table if it doesn't exist
      try {
        await _dbHelper.createDocTable(groupName);
      } catch (e) {
        print('Table creation note: $e');
      }

      // Add first file to group table for backward compatibility
      try {
        await _dbHelper.addGroupDoc(
          groupName: groupName,
          imgPath: document.imagePath,
          imgName: _getFileNameWithoutExtension(_getFileName(firstFile)),
          imgNote: '',
        );
      } catch (e) {
        print('Error adding first file to group table: $e');
      }

      // ========== STEP 3: Save remaining files as DocumentDetails ==========
      int successCount = 1; // First file already saved
      
      for (int i = 1; i < selectedFiles.length; i++) {
        try {
          final fileItem = _fileItems[selectedFiles[i]];
          final file = fileItem.file;
          final fileName = _getFileName(file);
          final isPDF = file.path.toLowerCase().endsWith('.pdf');

          String savedFilePath;
          String? savedThumbnailPath;

          // Save file to appropriate directory
          if (isPDF) {
            final pdfBytes = await file.readAsBytes();
            final pdfDir = await _fileStorageService.getPDFDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final fileExtension = fileName.contains('.') 
                ? fileName.substring(fileName.lastIndexOf('.')) 
                : '.pdf';
            savedFilePath = '${pdfDir.path}/pdf_${timestamp}_$i$fileExtension';
            final savedFile = File(savedFilePath);
            await savedFile.writeAsBytes(pdfBytes);
            
            // Generate thumbnail
            try {
              final thumbnailBytes = await _fileStorageService.generatePDFThumbnail(pdfBytes);
              if (thumbnailBytes != null) {
                savedThumbnailPath = '${pdfDir.path}/thumb_${timestamp}_$i.jpg';
                final thumbFile = File(savedThumbnailPath);
                await thumbFile.writeAsBytes(thumbnailBytes);
              }
            } catch (e) {
              print('Error generating PDF thumbnail: $e');
            }
          } else {
            final imageBytes = await file.readAsBytes();
            final imagesDir = await _fileStorageService.getImagesDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final fileExtension = fileName.contains('.') 
                ? fileName.substring(fileName.lastIndexOf('.')) 
                : '.jpg';
            savedFilePath = '${imagesDir.path}/img_${timestamp}_$i$fileExtension';
            final savedFile = File(savedFilePath);
            await savedFile.writeAsBytes(imageBytes);
            
            // Generate thumbnail
            try {
              final thumbnailBytes = await _fileStorageService.generateImageThumbnail(imageBytes);
              if (thumbnailBytes != null) {
                savedThumbnailPath = '${imagesDir.path}/thumb_${timestamp}_$i.jpg';
                final thumbFile = File(savedThumbnailPath);
                await thumbFile.writeAsBytes(thumbnailBytes);
              }
            } catch (e) {
              print('Error generating image thumbnail: $e');
            }
          }

          // Create DocumentDetail entry
          final documentDetail = DocumentDetail(
            documentId: documentId,
            title: _getFileNameWithoutExtension(fileName),
            type: isPDF ? 'pdf' : 'image',
            imagePath: savedFilePath,
            thumbnailPath: savedThumbnailPath,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _dbHelper.createDocumentDetail(documentDetail);
          successCount++;

          // Also add to group table for backward compatibility
          try {
            await _dbHelper.addGroupDoc(
              groupName: groupName,
              imgPath: savedFilePath,
              imgName: _getFileNameWithoutExtension(fileName),
              imgNote: '',
            );
          } catch (e) {
            print('Error adding file to group table: $e');
          }
        } catch (e) {
          print('Error saving file ${i + 1}: $e');
          // Continue with next file even if one fails
        }
      }

      // Refresh home provider to show new document
      if (mounted) {
        final provider = Provider.of<HomeProvider>(context, listen: false);
        provider.loadDocuments();
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount of ${selectedFiles.length} file(s) saved successfully'),
            backgroundColor: colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving files: $e'),
            backgroundColor: colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      print('Error in _saveFiles: $e');
    }
  }

  String _getFileNameWithoutExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return fileName;
    return fileName.substring(0, lastDot);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getFileName(File file) {
    return file.path.split('/').last;
  }

  DateTime _getFileDate(File file) {
    try {
      return file.lastModifiedSync();
    } catch (e) {
      return DateTime.now();
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colorScheme.onSurface,
          ),
          onPressed: () => NavigationService.goBack(),
        ),
        title: Text(
          'Arrange Files',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_rounded,
              color: colorScheme.onSurface,
            ),
            onPressed: _addMoreFiles,
          ),
          IconButton(
            icon: Icon(
              Icons.save_rounded,
              color: colorScheme.onSurface,
            ),
            onPressed: _isSaving ? null : _saveFiles,
          ),
        ],
      ),
      body: _fileItems.isEmpty
          ? _buildEmptyState(colorScheme, isDark)
          : _buildFilesList(colorScheme, isDark),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No files selected',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList(ColorScheme colorScheme, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _fileItems.length,
      itemBuilder: (context, index) {
        return _buildFileCard(index, colorScheme, isDark);
      },
    );
  }

  Widget _buildFileCard(int index, ColorScheme colorScheme, bool isDark) {
    final fileItem = _fileItems[index];
    final isSelected = _selectedIndices.contains(index);
    final fileName = _getFileName(fileItem.file);
    final fileDate = _getFileDate(fileItem.file);
    final pageCount = fileItem.pageCount ?? 1;

    return GestureDetector(
      onTap: () => _toggleSelection(index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview card
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline.withOpacity(0.1),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: File(fileItem.file.path).existsSync()
                        ? Image.file(
                            File(fileItem.file.path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.white,
                                child: Center(
                                  child: Icon(
                                    Icons.description_rounded,
                                    color: colorScheme.onSurface.withOpacity(0.3),
                                    size: 48,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.white,
                            child: Center(
                              child: Icon(
                                Icons.description_rounded,
                                color: colorScheme.onSurface.withOpacity(0.3),
                                size: 48,
                              ),
                            ),
                          ),
                  ),
                ),
                // Selection checkmark
                if (isSelected)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                // Page count badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pageCount ${pageCount == 1 ? 'Page' : 'Pages'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                // Delete button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _removeFile(index),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // File info - simple text below preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(fileDate),
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class FileItem {
  final File file;
  final int orderIndex;
  final int? pageCount;

  FileItem({
    required this.file,
    required this.orderIndex,
    this.pageCount,
  });

  FileItem copyWith({
    File? file,
    int? orderIndex,
    int? pageCount,
  }) {
    return FileItem(
      file: file ?? this.file,
      orderIndex: orderIndex ?? this.orderIndex,
      pageCount: pageCount ?? this.pageCount,
    );
  }
}

