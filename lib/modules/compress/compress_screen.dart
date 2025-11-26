import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import 'models/compress_file_item.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  List<CompressFileItem> _files = [];
  bool _isCompressing = false;
  double _compressionProgress = 0.0;

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
                : colorScheme.surface.withOpacity(0.65),
            borderRadius: BorderRadius.circular(12),
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
          'Compress Files',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: _isCompressing
          ? _buildCompressingState(colorScheme)
          : _files.isEmpty
              ? _buildEmptyState(colorScheme, isDark)
              : _buildFilesList(colorScheme, isDark),
    );
  }

  Widget _buildCompressingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: _compressionProgress,
            color: colorScheme.primary,
          ),
          const SizedBox(height: AppConstants.spacingL),
          Text(
            'Compressing files...\n${(_compressionProgress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.compress_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingXL),
            Text(
              'Select Files to Compress',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Choose images, PDFs, or any files to compress and reduce file size',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingXL),
            FilledButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Pick Files'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingXL,
                  vertical: AppConstants.spacingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesList(ColorScheme colorScheme, bool isDark) {
    final totalOriginalSize = _files.fold<int>(
      0,
      (sum, file) => sum + file.originalSize,
    );
    final totalCompressedSize = _files.fold<int>(
      0,
      (sum, file) => sum + (file.compressedSize ?? file.originalSize),
    );
    final totalSaved = totalOriginalSize - totalCompressedSize;
    final compressionRatio = totalOriginalSize > 0
        ? ((totalSaved / totalOriginalSize) * 100)
        : 0.0;

    return Column(
      children: [
        // Summary Card
        Container(
          margin: const EdgeInsets.all(AppConstants.spacingM),
          padding: const EdgeInsets.all(AppConstants.spacingL),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.5)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? colorScheme.outline.withOpacity(0.3)
                  : colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Files: ${_files.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (_files.every((f) => f.isCompressed))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingM,
                        vertical: AppConstants.spacingS,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${compressionRatio.toStringAsFixed(1)}% saved',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingS),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original Size',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        _formatSize(totalOriginalSize),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  if (_files.every((f) => f.isCompressed))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Compressed Size',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        Text(
                          _formatSize(totalCompressedSize),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        // Files List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
            itemCount: _files.length,
            itemBuilder: (context, index) {
              return _buildFileCard(_files[index], colorScheme, isDark, index);
            },
          ),
        ),
        // Action Buttons
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add More'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppConstants.spacingM,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _files.every((f) => f.isCompressed)
                        ? _downloadAllFiles
                        : _compressAllFiles,
                    icon: Icon(
                      _files.every((f) => f.isCompressed)
                          ? Icons.download_rounded
                          : Icons.compress_rounded,
                    ),
                    label: Text(
                      _files.every((f) => f.isCompressed)
                          ? 'Download All'
                          : 'Compress All',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppConstants.spacingM,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileCard(
    CompressFileItem file,
    ColorScheme colorScheme,
    bool isDark,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withOpacity(0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withOpacity(0.3)
              : colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppConstants.spacingM),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getFileTypeColor(file.fileType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getFileTypeIcon(file.fileType),
            color: _getFileTypeColor(file.fileType),
            size: 24,
          ),
        ),
        title: Text(
          file.fileName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppConstants.spacingXS),
            Wrap(
              spacing: AppConstants.spacingM,
              runSpacing: AppConstants.spacingXS,
              children: [
                Text(
                  'Original: ${file.formattedOriginalSize}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                if (file.isCompressed)
                  Text(
                    'Compressed: ${file.formattedCompressedSize}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            if (file.isCompressed && file.compressionRatio > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppConstants.spacingXS),
                child: Text(
                  '${file.compressionRatio.toStringAsFixed(1)}% smaller',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        trailing: file.isCompressing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : file.isCompressed
                ? IconButton(
                    icon: const Icon(Icons.download_rounded),
                    onPressed: () => _downloadFile(file),
                    tooltip: 'Download',
                  )
                : IconButton(
                    icon: const Icon(Icons.compress_rounded),
                    onPressed: () => _compressFile(file, index),
                    tooltip: 'Compress',
                  ),
      ),
    );
  }

  IconData _getFileTypeIcon(String fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileTypeColor(String fileType) {
    switch (fileType) {
      case 'image':
        return Colors.blue;
      case 'pdf':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final newFiles = result.files
          .where((file) => file.path != null)
          .map((file) {
            final fileObj = File(file.path!);
            final fileName = file.name;
            final extension = fileName.split('.').last.toLowerCase();
            return CompressFileItem(
              originalFile: fileObj,
              fileName: fileName,
              fileExtension: extension,
              originalSize: fileObj.lengthSync(),
            );
          })
          .toList();

      setState(() {
        _files.addAll(newFiles);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _compressFile(CompressFileItem file, int index) async {
    setState(() {
      _files[index].isCompressing = true;
    });

    try {
      File? compressedFile;
      int compressedSize = 0;

      if (file.fileType == 'image') {
        compressedFile = await _compressImage(file);
      } else if (file.fileType == 'pdf') {
        compressedFile = await _compressPdf(file);
      } else {
        // For other files, we can't really compress them
        // Just copy them as is
        compressedFile = file.originalFile;
      }

      if (compressedFile != null) {
        compressedSize = await compressedFile.length();
        setState(() {
          _files[index].compressedFile = compressedFile;
          _files[index].compressedSize = compressedSize;
          _files[index].isCompressed = true;
          _files[index].isCompressing = false;
        });
      } else {
        setState(() {
          _files[index].isCompressing = false;
        });
      }
    } catch (e) {
      setState(() {
        _files[index].isCompressing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error compressing ${file.fileName}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<File?> _compressImage(CompressFileItem file) async {
    try {
      final imageBytes = await file.originalFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) return null;

      // Resize if image is too large (max 2000px on longest side)
      img.Image processedImage = image;
      if (image.width > 2000 || image.height > 2000) {
        final ratio = image.width > image.height
            ? 2000 / image.width
            : 2000 / image.height;
        processedImage = img.copyResize(
          image,
          width: (image.width * ratio).toInt(),
          height: (image.height * ratio).toInt(),
        );
      }

      // Encode with quality compression
      final compressedBytes = img.encodeJpg(processedImage, quality: 85);
      
      final directory = await getApplicationDocumentsDirectory();
      final compressDir = Directory('${directory.path}/Compressed');
      if (!await compressDir.exists()) {
        await compressDir.create(recursive: true);
      }

      final extension = file.fileExtension.toLowerCase();
      final outputFormat = ['jpg', 'jpeg'].contains(extension) ? 'jpg' : 'png';
      final compressedFile = File(
        '${compressDir.path}/${file.fileName}_compressed.$outputFormat',
      );
      
      await compressedFile.writeAsBytes(compressedBytes);
      return compressedFile;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  Future<File?> _compressPdf(CompressFileItem file) async {
    try {
      final pdfBytes = await file.originalFile.readAsBytes();
      final pdfDocument = PdfDocument(inputBytes: pdfBytes);
      
      // For PDF compression, we can optimize by removing unnecessary data
      // Syncfusion doesn't have direct compression, so we'll save with optimization
      final optimizedBytes = await pdfDocument.save();
      pdfDocument.dispose();

      // If optimized is larger, use original
      if (optimizedBytes.length >= pdfBytes.length) {
        return file.originalFile;
      }

      final directory = await getApplicationDocumentsDirectory();
      final compressDir = Directory('${directory.path}/Compressed');
      if (!await compressDir.exists()) {
        await compressDir.create(recursive: true);
      }

      final compressedFile = File(
        '${compressDir.path}/${file.fileName}_compressed.pdf',
      );
      
      await compressedFile.writeAsBytes(optimizedBytes);
      return compressedFile;
    } catch (e) {
      print('Error compressing PDF: $e');
      return null;
    }
  }

  Future<void> _compressAllFiles() async {
    setState(() {
      _isCompressing = true;
      _compressionProgress = 0.0;
    });

    for (int i = 0; i < _files.length; i++) {
      if (!_files[i].isCompressed) {
        await _compressFile(_files[i], i);
      }
      setState(() {
        _compressionProgress = (i + 1) / _files.length;
      });
    }

    setState(() {
      _isCompressing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All files compressed successfully'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _downloadFile(CompressFileItem file) async {
    try {
      final fileToDownload = file.compressedFile ?? file.originalFile;
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/Download/Scanify AI/Compressed');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final fileName = file.isCompressed
          ? '${file.fileName}_compressed.${file.fileExtension}'
          : file.fileName;
      final destFile = File('${downloadsDir.path}/$fileName');
      await fileToDownload.copy(destFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.fileName} downloaded successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadAllFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/Download/Scanify AI/Compressed');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      int downloadedCount = 0;
      for (final file in _files) {
        final fileToDownload = file.compressedFile ?? file.originalFile;
        final fileName = file.isCompressed
            ? '${file.fileName}_compressed.${file.fileExtension}'
            : file.fileName;
        final destFile = File('${downloadsDir.path}/$fileName');
        await fileToDownload.copy(destFile.path);
        downloadedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$downloadedCount file(s) downloaded successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading files: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

