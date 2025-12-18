import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:watermark_unique/watermark_unique.dart';
import 'package:watermark_unique/image_format.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/file_storage_service.dart';
import '../../Services/database_helper.dart';
import '../../Providers/home_provider.dart';

class WatermarkScreen extends StatefulWidget {
  final String? initialFilePath;

  const WatermarkScreen({super.key, this.initialFilePath});

  @override
  State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  File? _selectedFile;
  final TextEditingController _watermarkTextController =
      TextEditingController();
  bool _isProcessing = false;
  double _progress = 0.0;
  String? _outputPath;

  // Watermark customization options
  Color _watermarkColor = Colors.yellow;
  double _watermarkOpacity = 0.5;

  // Preview state
  File? _previewFile;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      _checkAndSetFile(widget.initialFilePath!);
    }
  }

  Future<void> _checkAndSetFile(String filePath) async {
    try {
      log('Checking file path: $filePath');
      
      // The path from database should be the full path from FileStorageService
      // First, try the path as-is (it might already be a full path)
      File? file = File(filePath);
      
      if (await file.exists()) {
        log('File found at original path: $filePath');
        setState(() {
          _selectedFile = file;
        });
        return;
      }

      // If path doesn't start with '/', it might be relative to app directory
      // Try constructing full path with application documents directory
      if (!filePath.startsWith('/')) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final fullPath = '${appDir.path}/$filePath';
          final fullPathFile = File(fullPath);
          if (await fullPathFile.exists()) {
            log('File found at constructed path: $fullPath');
            setState(() {
              _selectedFile = fullPathFile;
            });
            return;
          }
        } catch (e) {
          log('Error checking constructed path: $e');
        }
      }

      // If file doesn't exist, try to find it in storage directories
      log('File not found at: $filePath, searching in storage directories...');
      
      final fileName = filePath.split('/').last;
      final fileStorageService = FileStorageService.instance;
      
      // Try Images directory - search for files matching the pattern
      try {
        final imagesDir = await fileStorageService.getImagesDirectory();
        
        // First try exact filename match
        final possiblePath = '${imagesDir.path}/$fileName';
        var possibleFile = File(possiblePath);
        if (await possibleFile.exists()) {
          log('Found file in Images directory: $possiblePath');
          setState(() {
            _selectedFile = possibleFile;
          });
          return;
        }
        
        // If not found, try searching for files that contain the original filename
        // (in case the stored path has a different name pattern)
        try {
          final dir = Directory(imagesDir.path);
          if (await dir.exists()) {
            await for (var entity in dir.list()) {
              if (entity is File) {
                final entityName = entity.path.split('/').last;
                // Check if filename matches or contains parts of the original
                if (entityName.contains(fileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')) ||
                    fileName.contains(entityName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''))) {
                  log('Found similar file in Images directory: ${entity.path}');
                  setState(() {
                    _selectedFile = entity;
                  });
                  return;
                }
              }
            }
          }
        } catch (e) {
          log('Error searching Images directory: $e');
        }
      } catch (e) {
        log('Error checking Images directory: $e');
      }

      // Try PDF directory
      try {
        final pdfDir = await fileStorageService.getPDFDirectory();
        
        // First try exact filename match
        final possiblePath = '${pdfDir.path}/$fileName';
        var possibleFile = File(possiblePath);
        if (await possibleFile.exists()) {
          log('Found file in PDF directory: $possiblePath');
          setState(() {
            _selectedFile = possibleFile;
          });
          return;
        }
        
        // Search for similar files
        try {
          final dir = Directory(pdfDir.path);
          if (await dir.exists()) {
            await for (var entity in dir.list()) {
              if (entity is File) {
                final entityName = entity.path.split('/').last;
                if (entityName.contains(fileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')) ||
                    fileName.contains(entityName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''))) {
                  log('Found similar file in PDF directory: ${entity.path}');
                  setState(() {
                    _selectedFile = entity;
                  });
                  return;
                }
              }
            }
          }
        } catch (e) {
          log('Error searching PDF directory: $e');
        }
      } catch (e) {
        log('Error checking PDF directory: $e');
      }

      // Try documents directory (old import system)
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        final documentsPath = '${documentsDir.path}/documents/$fileName';
        final documentsFile = File(documentsPath);
        if (await documentsFile.exists()) {
          log('Found file in documents directory: $documentsPath');
          setState(() {
            _selectedFile = documentsFile;
          });
          return;
        }
      } catch (e) {
        log('Error checking documents directory: $e');
      }

      // File not found anywhere, show error
      log('File not found in any storage location: $fileName (original path: $filePath)');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File not found: ${filePath.split('/').last}',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 3),
            ),
          );
        });
      }
    } catch (e) {
      log('Error checking file: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error accessing file: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _watermarkTextController.dispose();
    // Clean up preview file
    if (_previewFile != null) {
      try {
        _previewFile!.delete();
      } catch (e) {
        // Ignore deletion errors
      }
    }
    super.dispose();
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
          'WaterMark',
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
          // Document Preview Area
          Expanded(
                child: Container(
              color: colorScheme.surface,
              child: _selectedFile == null
                  ? Center(
                  child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                            Icons.image_rounded,
                        size: 64,
                            color: colorScheme.onSurface.withOpacity(0.3),
                      ),
                          const SizedBox(height: 16),
                      Text(
                            'No document selected',
                        style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _pickFile,
                            icon: Icon(Icons.upload_file_rounded),
                            label: const Text('Pick Document'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        // Document preview
                        Center(
                          child: _previewFile != null
                              ? Image.file(_previewFile!, fit: BoxFit.contain)
                              : Image.file(_selectedFile!, fit: BoxFit.contain),
                        ),
                        // Watermark preview overlay (if text is entered)
                        if (_watermarkTextController.text.isNotEmpty &&
                            _selectedFile != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _WatermarkPainter(
                                  text: _watermarkTextController.text,
                                  color: _watermarkColor.withOpacity(
                                    _watermarkOpacity,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Loading overlay
                        if (_isProcessing)
                          Container(
                            color: Colors.black.withOpacity(0.5),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                  children: [
                                  const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                      ),
                    ),
                                  const SizedBox(height: 16),
                    Text(
                                    'Applying watermark...',
                      style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                      ),
                    ),
                  ],
                ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          // Bottom Action Bar
          Container(
            color: isDark
                ? colorScheme.surface.withOpacity(0.95)
                : colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Clear content button
                  _buildBottomActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Clear content',
                    onPressed: _clearContent,
                    colorScheme: colorScheme,
                  ),
                  // Edit content button
                  _buildBottomActionButton(
                    icon: Icons.edit_rounded,
                    label: 'Edit content',
                    onPressed: _editContent,
                    colorScheme: colorScheme,
                  ),
                  // Apply/Save button (green checkmark)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed:
                          (_selectedFile == null ||
                        _watermarkTextController.text.isEmpty ||
                        _isProcessing)
                    ? null
                    : _applyWatermark,
                      icon: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colorScheme.onSurface, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
                  style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _clearContent() {
    setState(() {
      _watermarkTextController.clear();
      _previewFile = null;
    });
    // Clean up preview file
    if (_previewFile != null) {
      try {
        _previewFile!.delete();
      } catch (e) {
        // Ignore deletion errors
      }
    }
  }

  void _editContent() {
    // Show bottom sheet for editing watermark text, color, and opacity
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildEditBottomSheet(context),
    );
  }

  Widget _buildEditBottomSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
                  decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
                  child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            Text(
              'Edit Watermark',
                              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            // Watermark Text Field
            TextField(
              controller: _watermarkTextController,
              decoration: InputDecoration(
                labelText: 'Watermark Text',
                hintText: 'Enter watermark text',
                filled: true,
                fillColor: isDark
                    ? colorScheme.surface.withOpacity(0.5)
                    : colorScheme.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                _updatePreview();
              },
            ),
            const SizedBox(height: 24),
            // Color Picker
            Text(
              'Color',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
                        children: [
                _buildColorOption(Colors.yellow),
                _buildColorOption(Colors.red),
                _buildColorOption(Colors.blue),
                _buildColorOption(Colors.green),
                _buildColorOption(Colors.orange),
                _buildColorOption(Colors.purple),
                _buildColorOption(Colors.pink),
                _buildColorOption(Colors.black),
                _buildColorOption(Colors.white),
              ],
            ),
            const SizedBox(height: 24),
            // Opacity Slider
            Text(
              'Opacity: ${(_watermarkOpacity * 100).toInt()}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: _watermarkOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: '${(_watermarkOpacity * 100).toInt()}%',
              onChanged: (value) {
                setState(() {
                  _watermarkOpacity = value;
                });
                // Update preview after opacity change
                Future.delayed(const Duration(milliseconds: 100), () {
                  _updatePreview();
                });
              },
              activeColor: colorScheme.primary,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                child: const Text('Done'),
                          ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Future<void> _updatePreview() async {
    if (_selectedFile == null || _watermarkTextController.text.trim().isEmpty) {
      setState(() {
        _previewFile = null;
      });
      return;
    }

    try {
      final extension = _selectedFile!.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(extension)) {
        // For PDFs, just show the original file
        setState(() {
          _previewFile = null;
        });
        return;
      }

      // Verify file exists
      if (!await _selectedFile!.exists()) {
        log('Preview: File does not exist');
        return;
      }

      // Create preview with watermark
      final previewPath = await _createPreviewWatermark();
      if (previewPath != null && mounted) {
        setState(() {
          _previewFile = File(previewPath);
        });
      } else {
        // If preview creation fails, just show original
        setState(() {
          _previewFile = null;
        });
      }
    } catch (e) {
      log('Preview update error: $e');
      // On error, just show original file
      setState(() {
        _previewFile = null;
      });
    }
  }

  Future<String?> _createPreviewWatermark() async {
    if (_selectedFile == null || _watermarkTextController.text.trim().isEmpty) {
      return null;
    }

    try {
      // Re-verify file exists and get the actual file path
      File? actualFile = _selectedFile;
      if (!await actualFile!.exists()) {
        log('Preview: File does not exist at ${actualFile.path}, trying to find it...');
        // Try to find the file again
        await _checkAndSetFile(actualFile.path);
        actualFile = _selectedFile;
        if (actualFile == null || !await actualFile.exists()) {
          log('Preview: Could not find file');
          return null;
        }
      }

      // Copy file to temp directory first to ensure watermark_unique can access it
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempInputPath = '${tempDir.path}/temp_input_$timestamp.jpg';
      final previewPath = '${tempDir.path}/preview_$timestamp.jpg';

      // Clean up old preview and temp files
      try {
        final dir = Directory(tempDir.path);
        await for (var entity in dir.list()) {
          if (entity is File && 
              (entity.path.contains('preview_') || entity.path.contains('temp_input_'))) {
            try {
              await entity.delete();
            } catch (e) {
              // Ignore deletion errors
            }
          }
        }
      } catch (e) {
        // Ignore cleanup errors
      }

      // Read image to get dimensions
      log('Preview: Reading file from ${actualFile.path}');
      final inputBytes = await actualFile.readAsBytes();
      
      if (inputBytes.isEmpty) {
        log('Preview: File is empty');
        return null;
      }

      // Copy to temp location for watermark_unique to access
      final tempInputFile = File(tempInputPath);
      await tempInputFile.writeAsBytes(inputBytes);
      
      if (!await tempInputFile.exists()) {
        log('Preview: Failed to create temp file');
        return null;
      }

      final inputImage = img.decodeImage(inputBytes);
      
      if (inputImage == null) {
        log('Preview: Failed to decode image');
        return null;
      }

      final imageWidth = inputImage.width;
      final imageHeight = inputImage.height;
      log('Preview: Image dimensions ${imageWidth}x$imageHeight');

      // Calculate center position for preview
      final textSize = (imageWidth * 0.1).round().clamp(40, 200);
      final centerX = (imageWidth / 2).round();
      final centerY = (imageHeight / 2).round();

      // Apply opacity to color
      final colorWithOpacity = Color.fromRGBO(
        _watermarkColor.red,
        _watermarkColor.green,
        _watermarkColor.blue,
        _watermarkOpacity,
      );

      // Use watermark_unique to create preview (single watermark at center for preview)
      // Use the temp file path which we know exists
      log('Preview: Applying watermark at ($centerX, $centerY) using temp file: $tempInputPath');
      final WatermarkUnique watermarkUnique = WatermarkUnique();
      final result = await watermarkUnique.addTextWatermark(
        filePath: tempInputPath,
        text: _watermarkTextController.text.trim(),
        x: centerX,
        y: centerY,
        textSize: textSize,
        color: colorWithOpacity,
        backgroundTextColor: Colors.transparent,
        quality: 75, // Lower quality for preview
        imageFormat: ImageFormat.jpeg,
      );

      // Clean up temp input file
      try {
        await tempInputFile.delete();
      } catch (e) {
        // Ignore deletion errors
      }

      if (result != null && result.isNotEmpty) {
        final resultFile = File(result);
        if (await resultFile.exists()) {
          // Verify file is not empty
          final fileSize = await resultFile.length();
          if (fileSize > 0) {
            // Copy to preview path
            await resultFile.copy(previewPath);
            log('Preview created successfully: $previewPath (size: $fileSize bytes)');
            return previewPath;
          } else {
            log('Preview: Result file is empty');
          }
        } else {
          log('Preview: Result file does not exist: $result');
        }
      } else {
        log('Preview: Watermark operation returned null');
      }
    } catch (e, stackTrace) {
      log('Preview watermark error: $e');
      log('Stack trace: $stackTrace');
    }
    return null;
  }

  Widget _buildColorOption(Color color) {
    final isSelected = _watermarkColor.value == color.value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _watermarkColor = color;
        });
        // Update preview after color change
        Future.delayed(const Duration(milliseconds: 100), () {
          _updatePreview();
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _outputPath = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _applyWatermark() async {
    // Validate inputs
    if (_selectedFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a file first'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    if (_watermarkTextController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter watermark text'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    // Verify file exists before processing
    if (!await _selectedFile!.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File not found: ${_selectedFile!.path.split('/').last}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _outputPath = null;
    });

    try {
      // Re-verify file exists before processing
      if (!await _selectedFile!.exists()) {
        log('File does not exist, trying to find it...');
        await _checkAndSetFile(_selectedFile!.path);
        if (_selectedFile == null || !await _selectedFile!.exists()) {
          throw Exception('File not found: ${_selectedFile?.path ?? "unknown"}');
        }
      }

      final inputPath = _selectedFile!.path;
      log('Starting watermark application for: $inputPath');
      
      // Get file extension
      final extension = inputPath.split('.').last.toLowerCase();
      final watermarkText = _watermarkTextController.text.trim();

      setState(() {
        _progress = 0.1;
      });

      // Check file type and apply watermark accordingly
      Uint8List? outputBytes;
      String fileType = 'image';
      
      if (['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(extension)) {
        log('Processing as image file');
        outputBytes = await _watermarkImage(inputPath, watermarkText);
        fileType = 'image';
      } else if (extension == 'pdf') {
        log('Processing as PDF file');
        outputBytes = await _watermarkPDF(inputPath, watermarkText);
        fileType = 'pdf';
      } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
        throw Exception('Video watermarking is not supported');
      } else {
        throw Exception('Unsupported file type: $extension');
      }

      setState(() {
        _progress = 0.8;
      });

      // Validate output
      if (outputBytes == null || outputBytes.isEmpty) {
        throw Exception('Failed to generate watermarked file - output is empty');
      }

      log('Watermark applied successfully, saving to database...');

      // Generate title from original filename
      final originalFileName = _selectedFile!.path.split('/').last;
      final fileNameWithoutExt = originalFileName.contains('.')
          ? originalFileName.substring(0, originalFileName.lastIndexOf('.'))
          : originalFileName;
      final title = '${fileNameWithoutExt}_Watermarked';

      // Save using file storage service - this creates a NEW database entry
      final fileStorageService = FileStorageService.instance;
      int? docId;
      
      setState(() {
        _progress = 0.9;
      });

      try {
      if (fileType == 'image') {
        docId = await fileStorageService.saveImageFile(
          imageBytes: outputBytes,
            fileName: 'watermarked_${DateTime.now().millisecondsSinceEpoch}.$extension',
            title: title,
        );
      } else if (fileType == 'pdf') {
        docId = await fileStorageService.savePDFFile(
          pdfBytes: outputBytes,
            fileName: 'watermarked_${DateTime.now().millisecondsSinceEpoch}.$extension',
            title: title,
          );
        }

        if (docId == null) {
          throw Exception('Failed to save watermarked file to database - docId is null');
        }

        log('File saved to database with ID: $docId');

      // Get saved file path from database
        final document = await DatabaseHelper.instance.getDocumentById(docId);
        if (document == null) {
          throw Exception('Document was not found in database after saving');
        }

        log('Document retrieved from database: ${document.imagePath}');
        
        // Refresh home screen documents
        if (mounted) {
          final provider = Provider.of<HomeProvider>(context, listen: false);
          provider.loadDocuments();
      }

      setState(() {
        _progress = 1.0;
        _isProcessing = false;
          _outputPath = document.imagePath;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
            content: Text('Watermark applied successfully!'),
            backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
          ),
        );
      }
      } catch (saveError) {
        log('Error saving to database: $saveError');
        throw Exception('Failed to save watermarked file: $saveError');
      }
    } catch (e, stackTrace) {
      log('Error in _applyWatermark: $e');
      log('Stack trace: $stackTrace');
      
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        String errorMessage = e.toString();
        // Remove "Exception: " prefix if present
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage.length > 150
                  ? '${errorMessage.substring(0, 150)}...'
                  : errorMessage,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Error Details'),
                    content: SingleChildScrollView(
                      child: Text(errorMessage),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Future<Uint8List?> _watermarkImage(String inputPath, String text) async {
    setState(() {
      _progress = 0.4;
    });

    try {
      log('Starting image watermarking: $inputPath');
      
      // Verify input file exists
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        throw Exception('Input file does not exist: $inputPath');
      }

      // Read input image to get dimensions for positioning
      final inputBytes = await inputFile.readAsBytes();
      if (inputBytes.isEmpty) {
        throw Exception('Input file is empty');
      }

      final inputImage = img.decodeImage(inputBytes);
      if (inputImage == null) {
        throw Exception('Failed to decode input image - file may be corrupted');
      }

      setState(() {
        _progress = 0.5;
      });

      // Calculate image dimensions
      final imageWidth = inputImage.width;
      final imageHeight = inputImage.height;
      log('Image dimensions: ${imageWidth}x$imageHeight');

      // Calculate text size based on image dimensions (10% of width, clamped)
      final textSize = (imageWidth * 0.1).round().clamp(40, 200);
      log('Calculated text size: $textSize');

      // Apply opacity to color
      final colorWithOpacity = Color.fromRGBO(
        _watermarkColor.red,
        _watermarkColor.green,
        _watermarkColor.blue,
        _watermarkOpacity,
      );

      // Copy file to temp directory first to ensure watermark_unique can access it
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempInputPath = '${tempDir.path}/watermark_input_$timestamp.jpg';
      final tempInputFile = File(tempInputPath);
      
      // Write input bytes to temp file
      await tempInputFile.writeAsBytes(inputBytes);
      
      if (!await tempInputFile.exists()) {
        throw Exception('Failed to create temp input file');
      }

      log('Created temp input file: $tempInputPath');

      // Use watermark_unique to add text watermark
      // Use diagonal pattern with multiple watermarks
      final WatermarkUnique watermarkUnique = WatermarkUnique();
      String currentPath = tempInputPath;
      int watermarkCount = 0;
      const int maxWatermarks = 8; // Reduced for better performance
      final List<String> tempFilesToCleanup = [tempInputPath]; // Track all temp files

      // Calculate diagonal positions
      final positions = _calculateDiagonalPositions(
        imageWidth,
        imageHeight,
        textSize,
      );

      // Limit positions and filter to valid ones (within image bounds)
      final validPositions = positions
          .where((pos) {
            final x = pos['x'] as int;
            final y = pos['y'] as int;
            return x >= -imageWidth && x < imageWidth * 2 &&
                   y >= -imageHeight && y < imageHeight * 2;
          })
          .take(maxWatermarks)
          .toList();

      log('Adding ${validPositions.length} watermarks...');

      // Add watermarks at calculated positions
      for (int i = 0; i < validPositions.length; i++) {
        final pos = validPositions[i];
        final x = pos['x'] as int;
        final y = pos['y'] as int;

        try {
          log('Adding watermark ${i + 1}/${validPositions.length} at position ($x, $y)');
          
          // Verify current file exists before watermarking
          final currentFile = File(currentPath);
          if (!await currentFile.exists()) {
            log('Current file does not exist: $currentPath');
            // Try to use the last known good file
            if (tempFilesToCleanup.length > 1) {
              // Use the previous result file
              currentPath = tempFilesToCleanup.last;
              log('Using previous result file: $currentPath');
              if (!await File(currentPath).exists()) {
                throw Exception('Previous result file also does not exist: $currentPath');
              }
            } else {
              throw Exception('Current file does not exist: $currentPath');
            }
          }

          log('Using file: $currentPath for watermark ${i + 1}');

          final result = await watermarkUnique.addTextWatermark(
            filePath: currentPath,
            text: text,
            x: x,
            y: y,
            textSize: textSize,
            color: colorWithOpacity,
            backgroundTextColor: Colors.transparent,
            quality: 90, // Higher quality for final output
            imageFormat: ImageFormat.jpeg,
          );

          if (result != null && result.isNotEmpty) {
            final resultFile = File(result);
            // Wait a bit for file system to sync
            await Future.delayed(const Duration(milliseconds: 100));
            
            if (await resultFile.exists()) {
              // Verify the file is not empty
              final fileSize = await resultFile.length();
              if (fileSize > 0) {
                // Copy result to a new temp file to ensure it persists
                final newTempPath = '${tempDir.path}/watermark_step_${i + 1}_$timestamp.jpg';
                await resultFile.copy(newTempPath);
                
                // Verify the copy exists
                final copiedFile = File(newTempPath);
                if (await copiedFile.exists()) {
                  // Update current path to the copied file
                  currentPath = newTempPath;
                  tempFilesToCleanup.add(newTempPath);
                  watermarkCount++;
                  log('Watermark ${i + 1} added successfully (file size: $fileSize bytes, copied to: $newTempPath)');
                } else {
                  log('Warning: Failed to copy result file to: $newTempPath');
                  if (i == 0) {
                    throw Exception('Failed to copy watermarked file');
                  }
                  continue;
                }
              } else {
                log('Warning: Watermarked file is empty at: $result');
                if (i == 0) {
                  throw Exception('Watermarked file is empty');
                }
                continue;
              }
            } else {
              log('Warning: Watermarked file not found at: $result');
              if (i == 0) {
                throw Exception('Watermarked file was not created');
              }
              continue;
            }
          } else {
            log('Warning: Watermark operation returned null for position $i');
            if (i == 0) {
              throw Exception('Watermark operation failed - returned null');
            }
            continue;
          }

          setState(() {
            _progress = 0.5 + (0.3 * (i + 1) / validPositions.length);
          });
        } catch (e) {
          log('Error adding watermark at position $i: $e');
          if (i == 0) {
            // If first watermark fails, throw error
            throw Exception('Failed to apply watermark: $e');
          }
          // For subsequent positions, continue but log warning
          log('Continuing with remaining watermarks...');
        }
      }

      if (watermarkCount == 0) {
        // Clean up temp files
        for (final tempPath in tempFilesToCleanup) {
          try {
            final file = File(tempPath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            // Ignore deletion errors
          }
        }
        throw Exception('Failed to add any watermarks');
      }

      log('Successfully added $watermarkCount/${validPositions.length} watermarks');

      setState(() {
        _progress = 0.9;
      });

      // Verify final file exists and read it
      final finalFile = File(currentPath);
      if (!await finalFile.exists()) {
        // Clean up temp files
        for (final tempPath in tempFilesToCleanup) {
          try {
            final file = File(tempPath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            // Ignore deletion errors
          }
        }
        throw Exception('Final watermarked file does not exist: $currentPath');
      }

      final fileSize = await finalFile.length();
      if (fileSize == 0) {
        throw Exception('Watermarked file is empty');
      }

      final outputBytes = await finalFile.readAsBytes();
      if (outputBytes.isEmpty) {
        throw Exception('Watermarked file is empty');
      }

      // Clean up all temp files after reading
      for (final tempPath in tempFilesToCleanup) {
        try {
          final file = File(tempPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ignore deletion errors
        }
      }

      log('Watermarked image created successfully, size: ${outputBytes.length} bytes');
      return Uint8List.fromList(outputBytes);
    } catch (e, stackTrace) {
      log('Error in _watermarkImage: $e');
      log('Stack trace: $stackTrace');
      throw Exception('Failed to watermark image: $e');
    }
  }

  List<Map<String, int>> _calculateDiagonalPositions(
    int width,
    int height,
    int textSize,
  ) {
    final positions = <Map<String, int>>[];
    final spacing = textSize * 2;

    // Create diagonal pattern from bottom-left to top-right
    for (int y = height; y > -spacing; y -= spacing) {
      for (int x = -width; x < width * 2; x += spacing) {
        positions.add({'x': x, 'y': y});
      }
    }

    return positions;
  }

  Future<void> _watermarkVideo(
    String inputPath,
    String outputPath,
    String text,
  ) async {
    // watermark_unique doesn't support video, so we'll skip it
    throw Exception(
      'Video watermarking not supported with watermark_unique package',
    );
  }

  Future<Uint8List?> _watermarkPDF(String inputPath, String text) async {
    setState(() {
      _progress = 0.4;
    });

    try {
      // Read the PDF file
      final inputBytes = await File(inputPath).readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: inputBytes);

      setState(() {
        _progress = 0.5;
      });

      // Add watermark to all pages
      for (int i = 0; i < document.pages.count; i++) {
        final PdfPage page = document.pages[i];
        final PdfGraphics graphics = page.graphics;

        // Get page dimensions
        final double pageWidth = page.size.width;
        final double pageHeight = page.size.height;

        // Create font for watermark
        final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 48);
        final PdfStringFormat format = PdfStringFormat(
          alignment: PdfTextAlignment.center,
        );

        // Calculate text size
        final Size textSize = font.measureString(text, format: format);
        final double x = (pageWidth - textSize.width) / 2;
        final double y = (pageHeight - textSize.height) / 2;

        // Draw watermark with specified color and opacity
        graphics.setTransparency(_watermarkOpacity);
        graphics.drawString(
          text,
          font,
          brush: PdfSolidBrush(
            PdfColor(
              _watermarkColor.red,
              _watermarkColor.green,
              _watermarkColor.blue,
            ),
          ),
          bounds: Rect.fromLTWH(x, y, textSize.width, textSize.height),
          format: format,
        );

        setState(() {
          _progress = 0.5 + (0.3 * (i + 1) / document.pages.count);
        });
      }

      setState(() {
        _progress = 0.9;
      });

      // Get the watermarked PDF bytes
      final List<int> bytes = await document.save();
      document.dispose();

      setState(() {
        _progress = 0.98;
      });

      return Uint8List.fromList(bytes);
    } catch (e) {
      // If PDF library fails, show error - PDF watermarking should use PDF library
      throw Exception(
        'PDF watermarking failed: $e. Please ensure the PDF file is valid.',
      );
    }
  }
}

// Custom painter for watermark preview overlay
class _WatermarkPainter extends CustomPainter {
  final String text;
  final Color color;

  _WatermarkPainter({required this.text, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: color,
      fontSize: size.width * 0.1,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Draw diagonal repeating watermark
    final spacing = textPainter.width * 1.5;
    final angle = -0.785; // -45 degrees in radians

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);

    for (double y = -size.height * 2; y < size.height * 2; y += spacing) {
      for (double x = -size.width * 2; x < size.width * 2; x += spacing) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WatermarkPainter oldDelegate) {
    return text != oldDelegate.text || color != oldDelegate.color;
  }
}

