import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_pdf;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../../Routes/navigation_service.dart';
import '../import_files/import_files_screen.dart';
import '../../Services/database_helper.dart';
import '../../Services/file_storage_service.dart';
import '../../Providers/home_provider.dart';
import 'package:provider/provider.dart';
import '../../Models/document_model.dart';

class ArrangeFilesScreen extends StatefulWidget {
  final List<File> files;
  final DocumentModel? document;

  const ArrangeFilesScreen({super.key, required this.files, this.document});

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
      return FileItem(file: entry.value, orderIndex: entry.key);
    }).toList();
    // Initialize with no files selected by default
    _selectedIndices = <int>{};
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
            final pdfDocument = syncfusion_pdf.PdfDocument(
              inputBytes: pdfBytes,
            );
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
        // Don't auto-select restored files - keep current selection state
        // _selectedIndices remains unchanged
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
      if (file.path.toLowerCase().endsWith('.pdf')) {
        // Convert PDF to images - each page becomes a separate image file
        try {
          if (await file.exists()) {
            final pdfBytes = await file.readAsBytes();
            final pdfDocument = syncfusion_pdf.PdfDocument(
              inputBytes: pdfBytes,
            );
            final pageCount = pdfDocument.pages.count;

            if (pageCount > 0) {
              // Get temporary directory for saving page images
              final tempDir = await getTemporaryDirectory();
              final imagesDir = Directory('${tempDir.path}/arrange_pdf_images');
              if (!await imagesDir.exists()) {
                await imagesDir.create(recursive: true);
              }

              // Convert each PDF page to an image
              final imageStream = Printing.raster(pdfBytes, dpi: 300);

              int pageIndex = 0;
              await for (final imageRaster in imageStream) {
                if (pageIndex >= pageCount) break;

                try {
                  final imageBytes = await imageRaster.toPng();

                  if (imageBytes.isNotEmpty) {
                    // Save image to temporary directory
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    final imageFile = File(
                      '${imagesDir.path}/page_${timestamp}_${pageIndex + 1}.png',
                    );
                    await imageFile.writeAsBytes(imageBytes);

                    // Add image file to the list
                    setState(() {
                      final startIndex = _fileItems.length;
                      _fileItems.add(
                        FileItem(
                          file: imageFile,
                          orderIndex: startIndex,
                          pageCount: 1, // Each page image is 1 page
                        ),
                      );
                      // Don't auto-select new files - user must manually select them
                    });
                  }
                } catch (e) {
                  print(
                    'Error converting PDF page ${pageIndex + 1} to image: $e',
                  );
                }

                pageIndex++;
              }

              pdfDocument.dispose();
            } else {
              pdfDocument.dispose();
              // If PDF has no pages, skip it
              print('PDF has no pages: ${file.path}');
            }
          }
        } catch (e) {
          print('Error processing PDF file ${file.path}: $e');
          // If PDF conversion fails, add the original PDF file as fallback
          setState(() {
            final startIndex = _fileItems.length;
            _fileItems.add(
              FileItem(file: file, orderIndex: startIndex, pageCount: 1),
            );
          });
        }
      } else {
        // For non-PDF files (images), add them directly
        setState(() {
          final startIndex = _fileItems.length;
          _fileItems.add(
            FileItem(file: file, orderIndex: startIndex, pageCount: 1),
          );
          // Don't auto-select new files - user must manually select them
        });
      }
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
      developer.log('=== SAVE FILES START ===');
      developer.log('Total SELECTED files: ${selectedFiles.length}');

      if (selectedFiles.isEmpty) {
        throw Exception('No files selected');
      }

      // ========== STEP 1: Save first file as Document ==========
      developer.log('--- STEP 1: Saving first file as Document ---');
      final firstFileItem = _fileItems[selectedFiles[0]];
      final firstFile = firstFileItem.file;
      final isFirstPDF = firstFile.path.toLowerCase().endsWith('.pdf');
      final firstFileName = _getFileName(firstFile);
      developer.log('First file: $firstFileName, isPDF: $isFirstPDF');

      int? documentId;

      if (isFirstPDF) {
        final pdfBytes = await firstFile.readAsBytes();
        documentId = await _fileStorageService.savePDFFile(
          pdfBytes: pdfBytes,
          fileName: firstFileName,
          title: _getFileNameWithoutExtension(firstFileName),
        );
        developer.log('✓ PDF file saved to Document table with ID: $documentId');
      } else {
        documentId = await _fileStorageService.saveImageFileFromFile(
          imageFile: firstFile,
          title: _getFileNameWithoutExtension(firstFileName),
        );
        developer.log('✓ Image file saved to Document table with ID: $documentId');
      }

      if (documentId == null) {
        throw Exception('Failed to save first file');
      }

      // Get the created document to get file paths
      final document = await _dbHelper.getDocument(documentId);
      if (document == null) {
        throw Exception('Document not found after creation');
      }

      // ========== STEP 2: Save ALL selected files (including first) to DocumentDetail ==========
      // IMPORTANT: Even for single files, we save to DocumentDetail table
      developer.log('--- STEP 2: Saving all selected files to DocumentDetail ---');
      developer.log('Note: Single files will also be saved to DocumentDetail table');
      int successCount = 0;
      final baseTimestamp = DateTime.now();

      // Process all selected files (including the first one)
      // This ensures single files are also saved to DocumentDetail
      for (int i = 0; i < selectedFiles.length; i++) {
        try {
          final selectedIndex = selectedFiles[i];
          if (selectedIndex >= _fileItems.length) {
            developer.log('⚠ Selected index $selectedIndex is out of bounds, skipping');
            continue;
          }

          final fileItem = _fileItems[selectedIndex];
          final file = fileItem.file;
          final fileName = _getFileName(file);
          final isPDF = file.path.toLowerCase().endsWith('.pdf');
          developer.log('Processing file ${i + 1}/${selectedFiles.length}: $fileName, isPDF: $isPDF');

          String savedFilePath;
          String? savedThumbnailPath;

          // For the first file, use the paths from the Document table
          if (i == 0) {
            savedFilePath = document['Image_path']?.toString() ?? '';
            savedThumbnailPath = document['image_thumbnail']?.toString();
            developer.log('  ✓ Using paths from Document table');
          } else {
            // For other files, save them to appropriate directories
            final fileTimestamp = baseTimestamp.add(Duration(milliseconds: i));
            final timestamp = fileTimestamp.millisecondsSinceEpoch;

            if (isPDF) {
              final pdfBytes = await file.readAsBytes();
              final pdfDir = await _fileStorageService.getPDFDirectory();
              final fileExtension = fileName.contains('.')
                  ? fileName.substring(fileName.lastIndexOf('.'))
                  : '.pdf';
              savedFilePath = '${pdfDir.path}/pdf_${timestamp}_$i$fileExtension';
              final savedFile = File(savedFilePath);
              await savedFile.writeAsBytes(pdfBytes);
              developer.log('  ✓ PDF file saved to: $savedFilePath');

              // Generate thumbnail
              try {
                final thumbnailBytes = await _fileStorageService.generatePDFThumbnail(pdfBytes);
                if (thumbnailBytes != null) {
                  savedThumbnailPath = '${pdfDir.path}/thumb_${timestamp}_$i.jpg';
                  final thumbFile = File(savedThumbnailPath);
                  await thumbFile.writeAsBytes(thumbnailBytes);
                  developer.log('  ✓ PDF thumbnail generated');
                }
              } catch (e) {
                developer.log('  ✗ Error generating PDF thumbnail: $e');
              }
            } else {
              final imageBytes = await file.readAsBytes();
              final imagesDir = await _fileStorageService.getImagesDirectory();
              final fileExtension = fileName.contains('.')
                  ? fileName.substring(fileName.lastIndexOf('.'))
                  : '.jpg';
              savedFilePath = '${imagesDir.path}/img_${timestamp}_$i$fileExtension';
              final savedFile = File(savedFilePath);
              await savedFile.writeAsBytes(imageBytes);
              developer.log('  ✓ Image file saved to: $savedFilePath');

              // Generate thumbnail
              try {
                final thumbnailBytes = await _fileStorageService.generateImageThumbnail(imageBytes);
                if (thumbnailBytes != null) {
                  savedThumbnailPath = '${imagesDir.path}/thumb_${timestamp}_$i.jpg';
                  final thumbFile = File(savedThumbnailPath);
                  await thumbFile.writeAsBytes(thumbnailBytes);
                  developer.log('  ✓ Image thumbnail generated');
                }
              } catch (e) {
                developer.log('  ✗ Error generating image thumbnail: $e');
              }
            }
          }

          // Create DocumentDetail entry with document_id pointing to the first document
          // IMPORTANT: This runs for ALL files, including single files (when i == 0)
          // Single images/files will also be stored in DocumentDetail table
          final fileTimestamp = baseTimestamp.add(Duration(milliseconds: i));
          final documentDetailMap = {
            'document_id': documentId,
            'title': '${_getFileNameWithoutExtension(fileName)}_$i',
            'type': isPDF ? 'pdf' : 'image',
            'Image_path': savedFilePath,
            'image_thumbnail': savedThumbnailPath,
            'created_date': fileTimestamp.toIso8601String(),
            'updated_date': fileTimestamp.toIso8601String(),
            'favourite': 0,
            'is_deleted': 0,
          };

          final detailId = await _dbHelper.createDocumentDetail(documentDetailMap);
          developer.log('  ✓ DocumentDetail entry created (ID: $detailId, document_id: $documentId)');
          if (selectedFiles.length == 1) {
            developer.log('  ✓ Single file saved to DocumentDetail table');
          }
          successCount++;
        } catch (e) {
          developer.log('✗ Error saving file ${i + 1}: $e');
          // Continue with next file even if one fails
        }
      }

      // Final summary log
      developer.log('=== SAVE FILES COMPLETE ===');
      developer.log('Summary:');
      developer.log('  - Total SELECTED files: ${selectedFiles.length}');
      developer.log('  - Successfully saved: $successCount');
      developer.log('  - Document table entries: 1');
      developer.log('  - DocumentDetail table entries: $successCount');
      developer.log('===========================');

      // Refresh home provider to show new document
      if (mounted) {
        try {
          final provider = Provider.of<HomeProvider>(context, listen: false);
          developer.log('Refreshing documents list after save...');
          await Future.delayed(const Duration(milliseconds: 500));
          await provider.loadDocuments();
          developer.log('✓ Documents list refreshed');
        } catch (e) {
          developer.log('✗ Error refreshing documents after save: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$successCount of ${selectedFiles.length} file(s) saved successfully',
            ),
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
      developer.log('Error in _saveFiles: $e');
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
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
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
            icon: Icon(Icons.add_rounded, color: colorScheme.onSurface),
            onPressed: _addMoreFiles,
          ),
          IconButton(
            icon: Icon(Icons.save_rounded, color: colorScheme.onSurface),
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
                                    color: colorScheme.onSurface.withOpacity(
                                      0.3,
                                    ),
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
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                // Page count badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pageCount ${pageCount == 1 ? 'Page' : 'Pages'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
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
                      width: 25,
                      height: 25,
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
                        size: 14,
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

  FileItem({required this.file, required this.orderIndex, this.pageCount});

  FileItem copyWith({File? file, int? orderIndex, int? pageCount}) {
    return FileItem(
      file: file ?? this.file,
      orderIndex: orderIndex ?? this.orderIndex,
      pageCount: pageCount ?? this.pageCount,
    );
  }
}
