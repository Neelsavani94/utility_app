import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
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
  int _previewUpdateKey = 0; // Key to force PDFView to reload when preview changes

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
                if (entityName.contains(
                      fileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
                    ) ||
                    fileName.contains(
                      entityName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
                    )) {
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
                if (entityName.contains(
                      fileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
                    ) ||
                    fileName.contains(
                      entityName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
                    )) {
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
      log(
        'File not found in any storage location: $fileName (original path: $filePath)',
      );
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File not found: ${filePath.split('/').last}'),
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
                          child: _buildPreviewWidget(),
                        ),
                        // Watermark preview overlay (only for images, not PDFs)
                        if (_watermarkTextController.text.isNotEmpty &&
                            _selectedFile != null &&
                            !_selectedFile!.path.toLowerCase().endsWith('.pdf'))
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

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
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
                _buildColorOption(Colors.yellow, setModalState),
                _buildColorOption(Colors.red, setModalState),
                _buildColorOption(Colors.blue, setModalState),
                _buildColorOption(Colors.green, setModalState),
                _buildColorOption(Colors.orange, setModalState),
                _buildColorOption(Colors.purple, setModalState),
                _buildColorOption(Colors.pink, setModalState),
                _buildColorOption(Colors.black, setModalState),
                _buildColorOption(Colors.white, setModalState),
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
                setModalState(() {
                  _watermarkOpacity = value;
                });
                setState(() {
                  _watermarkOpacity = value;
                });
                // Update preview immediately after opacity change
                _updatePreview();
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
      },
    );
  }

  Widget _buildPreviewWidget() {
    if (_selectedFile == null) {
      return const SizedBox.shrink();
    }

    final extension = _selectedFile!.path.split('.').last.toLowerCase();
    final fileToShow = _previewFile ?? _selectedFile!;
    final filePath = fileToShow.path;

    if (extension == 'pdf') {
      // Show PDF preview with full viewer functionality
      if (filePath.isEmpty) {
        return Center(
          child: Text(
            'PDF preview not available',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        );
      }
      return PDFView(
        key: ValueKey('pdf_preview_${_previewUpdateKey}_$filePath'), // Force reload when key changes
        filePath: filePath,
        enableSwipe: true, // Enable swipe to navigate pages
        swipeHorizontal: true, // Horizontal swipe
        autoSpacing: true, // Auto spacing between pages
        pageFling: true, // Enable page fling
        fitEachPage: false, // Don't fit each page, show full document
        onRender: (pages) {
          log('PDF preview rendered with $pages pages (key: $_previewUpdateKey)');
        },
        onError: (error) {
          log('PDF preview error: $error');
        },
        onPageError: (page, error) {
          log('PDF preview page error: $page - $error');
        },
        onViewCreated: (PDFViewController controller) {
          log('PDF preview view created (key: $_previewUpdateKey)');
        },
        onPageChanged: (int? page, int? total) {
          if (page != null && total != null) {
            log('PDF preview: Page $page of $total');
          }
        },
      );
    } else {
      // Show image preview
      return Image.file(fileToShow, fit: BoxFit.contain);
    }
  }

  Future<void> _updatePreview() async {
    if (_selectedFile == null || _watermarkTextController.text.trim().isEmpty) {
      setState(() {
        _previewFile = null;
        _previewUpdateKey++; // Force refresh even when clearing preview
      });
      return;
    }

    try {
      final extension = _selectedFile!.path.split('.').last.toLowerCase();
      
      // Verify file exists
      if (!await _selectedFile!.exists()) {
        log('Preview: File does not exist');
        return;
      }

      log('Updating preview for $extension file...');
      String? previewPath;
      
      if (['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(extension)) {
        // Create image preview with watermark
        previewPath = await _createPreviewWatermark();
      } else if (extension == 'pdf') {
        // Create PDF preview with watermark
        previewPath = await _createPreviewPDFWatermark();
      } else {
        // Unsupported file type
        setState(() {
          _previewFile = null;
          _previewUpdateKey++;
        });
        return;
      }

      if (previewPath != null && previewPath.isNotEmpty && mounted) {
        log('Preview updated successfully: $previewPath');
        setState(() {
          _previewFile = File(previewPath!);
          _previewUpdateKey++; // Increment key to force PDFView reload
        });
      } else {
        log('Preview creation returned null or empty path');
        // If preview creation fails, just show original
        setState(() {
          _previewFile = null;
          _previewUpdateKey++; // Increment key even on failure
        });
      }
    } catch (e, stackTrace) {
      log('Preview update error: $e');
      log('Stack trace: $stackTrace');
      // On error, just show original file
      setState(() {
        _previewFile = null;
        _previewUpdateKey++;
      });
    }
  }

  // Helper function to render text to an image using dart:ui
  Future<img.Image?> _renderTextToImage(
    String text,
    double fontSize,
    Color color,
    double opacity,
  ) async {
    try {
      // Create a text style
      final textStyle = ui.TextStyle(
        color: color.withOpacity(opacity),
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      );

      // Create a paragraph builder
      final paragraphBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign:
              TextAlign.left, // Use left align to prevent text wrapping issues
          textDirection: TextDirection.ltr,
        ),
      );
      paragraphBuilder.pushStyle(textStyle);
      paragraphBuilder.addText(text);
      final paragraph = paragraphBuilder.build();

      // First, layout with a very large width to get the actual intrinsic width
      // This ensures we get the full text width without any constraints
      paragraph.layout(ui.ParagraphConstraints(width: 10000.0));

      // Get actual text dimensions - use maxIntrinsicWidth for full text width
      final textWidth = paragraph.maxIntrinsicWidth.ceil();
      final textHeight = paragraph.height.ceil();

      // Re-layout with the actual width to ensure proper rendering
      paragraph.layout(ui.ParagraphConstraints(width: textWidth.toDouble()));

      // Add generous padding to ensure text is fully visible
      final padding = (fontSize * 0.3).ceil().clamp(10, 50);
      final imageWidth = (textWidth + padding * 2).clamp(1, 10000);
      final imageHeight = (textHeight + padding * 2).clamp(1, 10000);

      log(
        'Rendering text: "$text" - Size: ${textWidth}x$textHeight, Image: ${imageWidth}x$imageHeight',
      );

      // Create a picture recorder and canvas
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw the text with padding offset to ensure full text is visible
      canvas.drawParagraph(
        paragraph,
        Offset(padding.toDouble(), padding.toDouble()),
      );

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(imageWidth, imageHeight);

      // Convert ui.Image to image package Image
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        log('Error: Failed to convert ui.Image to byte data');
        return null;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final decodedImage = img.decodeImage(pngBytes);

      if (decodedImage == null) {
        log('Error: Failed to decode PNG bytes');
        return null;
      }

      log(
        'Successfully rendered text image: ${decodedImage.width}x${decodedImage.height}',
      );
      return decodedImage;
    } catch (e, stackTrace) {
      log('Error rendering text to image: $e');
      log('Stack trace: $stackTrace');
      return null;
    }
  }

  // Helper function to draw text on image with rotation and position
  Future<void> _drawTextOnImage(
    img.Image image,
    String text,
    int x,
    int y,
    double fontSize,
    Color color,
    double opacity,
    double rotation, // in radians
  ) async {
    try {
      // Render text to image
      final textImage = await _renderTextToImage(
        text,
        fontSize,
        color,
        opacity,
      );
      if (textImage == null) {
        log('Warning: Failed to render text image');
        return;
      }

      if (textImage.width == 0 || textImage.height == 0) {
        log('Warning: Text image has zero dimensions');
        return;
      }

      // Apply rotation if needed
      img.Image rotatedText = textImage;
      if (rotation.abs() > 0.01) {
        rotatedText = img.copyRotate(
          textImage,
          angle: rotation * 180 / 3.14159,
        );
      }

      // Calculate position for centering the text
      final dstX = (x - rotatedText.width ~/ 2);
      final dstY = (y - rotatedText.height ~/ 2);

      // Composite the text image onto the main image
      // Allow negative positions to ensure full coverage
      img.compositeImage(image, rotatedText, dstX: dstX, dstY: dstY);

      log(
        'Watermark applied at ($dstX, $dstY) with size ${rotatedText.width}x${rotatedText.height}',
      );
    } catch (e, stackTrace) {
      log('Error drawing text on image: $e');
      log('Stack trace: $stackTrace');
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
        log(
          'Preview: File does not exist at ${actualFile.path}, trying to find it...',
        );
        // Try to find the file again
        await _checkAndSetFile(actualFile.path);
        actualFile = _selectedFile;
        if (actualFile == null || !await actualFile.exists()) {
          log('Preview: Could not find file');
          return null;
        }
      }

      // Read image to get dimensions
      log('Preview: Reading file from ${actualFile.path}');
      final inputBytes = await actualFile.readAsBytes();

      if (inputBytes.isEmpty) {
        log('Preview: File is empty');
        return null;
      }

      final inputImage = img.decodeImage(inputBytes);

      if (inputImage == null) {
        log('Preview: Failed to decode image');
        return null;
      }

      // Create a copy for watermarking
      final watermarkedImage = img.copyResize(
        inputImage,
        width: inputImage.width,
        height: inputImage.height,
      );

      final imageWidth = watermarkedImage.width;
      final imageHeight = watermarkedImage.height;
      log('Preview: Image dimensions ${imageWidth}x$imageHeight');

      // Calculate center position for preview
      final minDimension = imageWidth < imageHeight ? imageWidth : imageHeight;
      final textSize = (minDimension * 0.08).round().clamp(30, 150).toDouble();
      final centerX = (imageWidth / 2).round();
      final centerY = (imageHeight / 2).round();

      // Draw watermark at center for preview
      await _drawTextOnImage(
        watermarkedImage,
        _watermarkTextController.text.trim(),
        centerX,
        centerY,
        textSize,
        _watermarkColor,
        _watermarkOpacity,
        0, // No rotation for preview
      );

      // Save preview to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final previewPath = '${tempDir.path}/preview_$timestamp.jpg';

      // Clean up old preview files
      try {
        final dir = Directory(tempDir.path);
        await for (var entity in dir.list()) {
          if (entity is File && entity.path.contains('preview_')) {
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

      // Encode and save
      final previewBytes = img.encodeJpg(watermarkedImage, quality: 75);
      final previewFile = File(previewPath);
      await previewFile.writeAsBytes(previewBytes);

      if (await previewFile.exists()) {
        final fileSize = await previewFile.length();
        if (fileSize > 0) {
          log(
            'Preview created successfully: $previewPath (size: $fileSize bytes)',
          );
          return previewPath;
        } else {
          log('Preview: Result file is empty');
        }
      } else {
        log('Preview: Failed to create preview file');
      }
    } catch (e, stackTrace) {
      log('Preview watermark error: $e');
      log('Stack trace: $stackTrace');
    }
    return null;
  }

  Future<String?> _createPreviewPDFWatermark() async {
    if (_selectedFile == null || _watermarkTextController.text.trim().isEmpty) {
      return null;
    }

    try {
      // Re-verify file exists and get the actual file path
      File? actualFile = _selectedFile;
      if (!await actualFile!.exists()) {
        log(
          'Preview PDF: File does not exist at ${actualFile.path}, trying to find it...',
        );
        // Try to find the file again
        await _checkAndSetFile(actualFile.path);
        actualFile = _selectedFile;
        if (actualFile == null || !await actualFile.exists()) {
          log('Preview PDF: Could not find file');
          return null;
        }
      }

      // Read PDF file
      log('Preview PDF: Reading file from ${actualFile.path}');
      final inputBytes = await actualFile.readAsBytes();

      if (inputBytes.isEmpty) {
        log('Preview PDF: File is empty');
        return null;
      }

      final PdfDocument document = PdfDocument(inputBytes: inputBytes);
      final totalPages = document.pages.count;
      if (totalPages == 0) {
        document.dispose();
        log('Preview PDF: PDF has no pages');
        return null;
      }

      log('Preview PDF: Processing $totalPages pages');

      // Apply watermarks to ALL pages
      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final PdfPage page = document.pages[pageIndex];
        final PdfGraphics graphics = page.graphics;

        // Get page dimensions
        final double pageWidth = page.size.width;
        final double pageHeight = page.size.height;

        // Calculate font size based on page dimensions
        final minDimension = pageWidth < pageHeight ? pageWidth : pageHeight;
        final fontSize = (minDimension * 0.08).clamp(20.0, 80.0);

        // Create font for watermark
        final PdfFont font = PdfStandardFont(
          PdfFontFamily.helvetica,
          fontSize,
          style: PdfFontStyle.bold,
        );

        // Set transparency
        graphics.setTransparency(_watermarkOpacity);

        // Create brush with watermark color
        final brush = PdfSolidBrush(
          PdfColor(
            _watermarkColor.red,
            _watermarkColor.green,
            _watermarkColor.blue,
          ),
        );

        // Calculate diagonal positions for this page
        final positions = _calculateDiagonalPositions(
          pageWidth.toInt(),
          pageHeight.toInt(),
          fontSize.toInt(),
        );

        // Filter positions to ensure full page coverage
        final validPositions = positions.where((pos) {
          final x = pos['x'] as int;
          final y = pos['y'] as int;
          return x >= -pageWidth.toInt() * 0.5 &&
              x < pageWidth.toInt() * 1.5 &&
              y >= -pageHeight.toInt() * 0.5 &&
              y < pageHeight.toInt() * 1.5;
        }).toList();

        // Rotation angle for diagonal watermarks (-45 degrees)
        const double rotationAngle = -45.0;

        // Add watermarks at calculated positions
        for (final pos in validPositions) {
          final x = pos['x'] as int;
          final y = pos['y'] as int;

          try {
            // Save graphics state
            graphics.save();

            // Translate to position
            graphics.translateTransform(x.toDouble(), y.toDouble());

            // Rotate for diagonal watermark
            graphics.rotateTransform(rotationAngle);

            // Measure text to center it
            final PdfStringFormat format = PdfStringFormat(
              alignment: PdfTextAlignment.center,
            );
            final Size textSize = font.measureString(
              _watermarkTextController.text.trim(),
              format: format,
            );

            // Draw watermark text
            graphics.drawString(
              _watermarkTextController.text.trim(),
              font,
              brush: brush,
              bounds: Rect.fromLTWH(
                -textSize.width / 2,
                -textSize.height / 2,
                textSize.width,
                textSize.height,
              ),
              format: format,
            );

            // Restore graphics state
            graphics.restore();
          } catch (e) {
            log('Error adding watermark at position on page ${pageIndex + 1}: $e');
            // Continue with remaining watermarks
          }
        }
      }

      // Save preview PDF to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final previewPath = '${tempDir.path}/preview_pdf_$timestamp.pdf';

      // Clean up old preview PDF files
      try {
        final dir = Directory(tempDir.path);
        await for (var entity in dir.list()) {
          if (entity is File && entity.path.contains('preview_pdf_')) {
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

      // Save the preview PDF
      final List<int> pdfBytes = await document.save();
      document.dispose();

      if (pdfBytes.isEmpty) {
        log('Preview PDF: Generated PDF bytes are empty');
        return null;
      }

      log('Preview PDF: Saving ${pdfBytes.length} bytes to $previewPath');

      final previewFile = File(previewPath);
      await previewFile.writeAsBytes(pdfBytes);

      // Wait a moment for file system to sync
      await Future.delayed(const Duration(milliseconds: 150));

      if (await previewFile.exists()) {
        final fileSize = await previewFile.length();
        if (fileSize > 0) {
          log(
            'Preview PDF created successfully: $previewPath (size: $fileSize bytes)',
          );
          return previewPath;
        } else {
          log('Preview PDF: Result file is empty');
        }
      } else {
        log('Preview PDF: Failed to create preview file');
      }
    } catch (e, stackTrace) {
      log('Preview PDF watermark error: $e');
      log('Stack trace: $stackTrace');
    }
    return null;
  }

  Widget _buildColorOption(Color color, [StateSetter? modalStateSetter]) {
    final isSelected = _watermarkColor.value == color.value;
    return GestureDetector(
      onTap: () {
        // Update both modal state and main state
        if (modalStateSetter != null) {
          modalStateSetter(() {
            _watermarkColor = color;
          });
        }
        setState(() {
          _watermarkColor = color;
        });
        // Update preview immediately after color change
        _updatePreview();
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
          throw Exception(
            'File not found: ${_selectedFile?.path ?? "unknown"}',
          );
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
      final fileStorageService = FileStorageService.instance;
      final dbHelper = DatabaseHelper.instance;
      
      if (['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(extension)) {
        log('Processing as single image file');
        setState(() {
          _progress = 0.3;
        });
        
        // Apply watermark to image
        final outputBytes = await _watermarkImage(inputPath, watermarkText);
        
        if (outputBytes == null || outputBytes.isEmpty) {
          throw Exception('Failed to generate watermarked image');
        }
        
        setState(() {
          _progress = 0.6;
        });
        
        // Save single image to Document table
        final fileName = inputPath.split('/').last;
        final docId = await fileStorageService.saveImageFile(
          imageBytes: outputBytes,
          fileName: fileName,
          title: fileName.split('.').first,
        );
        
        if (docId == null) {
          throw Exception('Failed to save watermarked image to database');
        }
        
        log('✓ Single image saved to Document table (ID: $docId)');
        
        // IMPORTANT: Also save single images to DocumentDetail table
        final document = await dbHelper.getDocument(docId);
        if (document != null) {
          try {
            final timestamp = DateTime.now();
            final fileNameWithoutExt = fileName.contains('.')
                ? fileName.substring(0, fileName.lastIndexOf('.'))
                : fileName;
            
            final documentDetailMap = {
              'document_id': docId,
              'title': '${fileNameWithoutExt}_0',
              'type': 'image',
              'Image_path': document['Image_path']?.toString() ?? '',
              'image_thumbnail': document['image_thumbnail']?.toString() ?? '',
              'created_date': timestamp.toIso8601String(),
              'updated_date': timestamp.toIso8601String(),
              'favourite': 0,
              'is_deleted': 0,
            };
            
            final detailId = await dbHelper.createDocumentDetail(documentDetailMap);
            log('✓ Single watermarked image saved to DocumentDetail table (ID: $detailId, document_id: $docId)');
          } catch (e) {
            log('✗ Error saving to DocumentDetail table: $e');
            // Continue even if DocumentDetail save fails
          }
        }
        
        setState(() {
          _progress = 1.0;
          _isProcessing = false;
        });
        
        // Refresh home screen documents
        if (mounted) {
          final provider = Provider.of<HomeProvider>(context, listen: false);
          await provider.loadDocuments();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Watermark applied successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Get.back();
        }
        
      } else if (extension == 'pdf') {
        log('Processing as PDF file - converting pages to images');
        setState(() {
          _progress = 0.2;
        });
        
        // Apply watermark to PDF
        final watermarkedPdfBytes = await _watermarkPDF(inputPath, watermarkText);
        
        if (watermarkedPdfBytes == null || watermarkedPdfBytes.isEmpty) {
          throw Exception('Failed to generate watermarked PDF');
        }
        
        setState(() {
          _progress = 0.4;
        });
        
        // Convert PDF pages to images
        final imagesDir = await fileStorageService.getImagesDirectory();
        final baseFileName = inputPath.split('/').last.split('.').first;
        
        // Convert PDF to images using Printing.raster
        final imageStream = Printing.raster(watermarkedPdfBytes, dpi: 300);
        final List<Uint8List> pageImages = [];
        
        int pageIndex = 0;
        await for (final imageRaster in imageStream) {
          try {
            final imageBytes = await imageRaster.toPng();
            if (imageBytes.isNotEmpty) {
              pageImages.add(imageBytes);
              log('✓ Converted page ${pageIndex + 1} to image');
            }
          } catch (e) {
            log('✗ Error converting page ${pageIndex + 1} to image: $e');
          }
          pageIndex++;
        }
        
        if (pageImages.isEmpty) {
          throw Exception('Failed to convert PDF pages to images');
        }
        
        log('✓ Converted ${pageImages.length} PDF pages to images');
        
        setState(() {
          _progress = 0.6;
        });
        
        // Save first image to Document table
        final firstImageBytes = pageImages[0];
        final firstFileName = '${baseFileName}_0.png';
        final documentId = await fileStorageService.saveImageFile(
          imageBytes: firstImageBytes,
          fileName: firstFileName,
          title: baseFileName,
        );
        
        if (documentId == null) {
          throw Exception('Failed to save first image to Document table');
        }
        
        log('✓ First image saved to Document table (ID: $documentId)');
        
        setState(() {
          _progress = 0.7;
        });
        
        // Save all images (including first) to DocumentDetail table
        int successCount = 0;
        final baseTimestamp = DateTime.now();
        
        for (int i = 0; i < pageImages.length; i++) {
          try {
            // For first image, get paths from Document table
            String savedFilePath;
            String? savedThumbnailPath;
            
            if (i == 0) {
              final document = await dbHelper.getDocument(documentId);
              if (document != null) {
                savedFilePath = document['Image_path']?.toString() ?? '';
                savedThumbnailPath = document['image_thumbnail']?.toString();
              } else {
                throw Exception('Document not found after creation');
              }
            } else {
              // Save other images
              final fileTimestamp = baseTimestamp.add(Duration(milliseconds: i));
              final fileTimestampMs = fileTimestamp.millisecondsSinceEpoch;
              savedFilePath = '${imagesDir.path}/img_${fileTimestampMs}_$i.png';
              
              final file = File(savedFilePath);
              await file.writeAsBytes(pageImages[i]);
              
              // Generate thumbnail
              final thumbnailBytes = await fileStorageService.generateImageThumbnail(pageImages[i]);
              if (thumbnailBytes != null) {
                savedThumbnailPath = '${imagesDir.path}/thumb_${fileTimestampMs}_$i.jpg';
                final thumbFile = File(savedThumbnailPath);
                await thumbFile.writeAsBytes(thumbnailBytes);
              }
            }
            
            // Create DocumentDetail entry
            final fileTimestamp = baseTimestamp.add(Duration(milliseconds: i));
            final documentDetailMap = {
              'document_id': documentId,
              'title': '${baseFileName}_$i',
              'type': 'image',
              'Image_path': savedFilePath,
              'image_thumbnail': savedThumbnailPath,
              'created_date': fileTimestamp.toIso8601String(),
              'updated_date': fileTimestamp.toIso8601String(),
              'favourite': 0,
              'is_deleted': 0,
            };
            
            await dbHelper.createDocumentDetail(documentDetailMap);
            successCount++;
            log('✓ Page ${i + 1} saved to DocumentDetail table');
          } catch (e) {
            log('✗ Error saving page ${i + 1} to DocumentDetail: $e');
          }
        }
        
        log('✓ Saved $successCount/${pageImages.length} pages to DocumentDetail table');
        
        setState(() {
          _progress = 1.0;
          _isProcessing = false;
        });
        
        // Refresh home screen documents
        if (mounted) {
          final provider = Provider.of<HomeProvider>(context, listen: false);
          await provider.loadDocuments();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Watermark applied to ${pageImages.length} page(s)!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          Get.back();
        }
        
      } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
        throw Exception('Video watermarking is not supported');
      } else {
        throw Exception('Unsupported file type: $extension');
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
                    content: SingleChildScrollView(child: Text(errorMessage)),
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

      // Read input image
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

      // Create a copy for watermarking
      final watermarkedImage = img.copyResize(
        inputImage,
        width: inputImage.width,
        height: inputImage.height,
      );

      // Calculate image dimensions
      final imageWidth = watermarkedImage.width;
      final imageHeight = watermarkedImage.height;
      log('Image dimensions: ${imageWidth}x$imageHeight');

      // Calculate text size based on image dimensions
      // Use a percentage of the smaller dimension for better visibility
      final minDimension = imageWidth < imageHeight ? imageWidth : imageHeight;
      final textSize = (minDimension * 0.08).round().clamp(30, 150).toDouble();
      log(
        'Calculated text size: $textSize (image: ${imageWidth}x$imageHeight)',
      );

      // Calculate diagonal positions
      final positions = _calculateDiagonalPositions(
        imageWidth,
        imageHeight,
        textSize.round(),
      );

      // Filter positions to ensure full image coverage
      final validPositions = positions.where((pos) {
        final x = pos['x'] as int;
        final y = pos['y'] as int;
        // Include positions that will be visible on the image
        // Allow positions slightly outside bounds for full coverage
        return x >= -imageWidth * 0.5 &&
            x < imageWidth * 1.5 &&
            y >= -imageHeight * 0.5 &&
            y < imageHeight * 1.5;
      }).toList();

      log(
        'Calculated ${validPositions.length} watermark positions for full coverage',
      );

      log('Adding ${validPositions.length} watermarks...');

      // Rotation angle for diagonal watermarks (-45 degrees)
      const double rotationAngle = -0.785398; // -45 degrees in radians

      // Add watermarks at calculated positions
      for (int i = 0; i < validPositions.length; i++) {
        final pos = validPositions[i];
        final x = pos['x'] as int;
        final y = pos['y'] as int;

        try {
          log(
            'Adding watermark ${i + 1}/${validPositions.length} at position ($x, $y)',
          );

          // Draw watermark with rotation
          await _drawTextOnImage(
            watermarkedImage,
            text,
            x,
            y,
            textSize,
            _watermarkColor,
            _watermarkOpacity,
            rotationAngle,
      );

      setState(() {
            _progress = 0.5 + (0.3 * (i + 1) / validPositions.length);
          });
        } catch (e) {
          log('Error adding watermark at position $i: $e');
          if (i == 0) {
            throw Exception('Failed to apply watermark: $e');
          }
          // Continue with remaining watermarks
        }
      }

          setState(() {
        _progress = 0.9;
      });

      // Determine output format based on input
      final extension = inputPath.split('.').last.toLowerCase();
      Uint8List outputBytes;

      if (extension == 'png') {
        outputBytes = Uint8List.fromList(img.encodePng(watermarkedImage));
      } else {
        // Default to JPEG for jpg, jpeg, webp, etc.
        outputBytes = Uint8List.fromList(
          img.encodeJpg(watermarkedImage, quality: 90),
        );
      }

      if (outputBytes.isEmpty) {
        throw Exception('Failed to encode watermarked image');
      }

      log(
        'Watermarked image created successfully, size: ${outputBytes.length} bytes',
      );
      return outputBytes;
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
    // Calculate spacing with more space between watermarks
    // Increase multiplier to add more space between text instances
    // Consider both horizontal and vertical spacing for diagonal pattern
    final baseSpacing =
        textSize * 3.0; // Increased from 1.5 to 3.0 for more space
    final spacing = baseSpacing.round().clamp(
      100,
      400,
    ); // Increased min from 50 to 100

    // Create diagonal pattern covering the entire image
    // Start from outside the image bounds to ensure full coverage
    final startY = height + spacing;
    final endY = -spacing;
    final startX = -width - spacing;
    final endX = width * 2 + spacing;

    // Create diagonal grid pattern with increased spacing
    for (int y = startY; y >= endY; y -= spacing) {
      for (int x = startX; x <= endX; x += spacing) {
        positions.add({'x': x, 'y': y});
      }
    }

    log(
      'Calculated spacing: $spacing (textSize: $textSize) for ${positions.length} positions',
    );
    return positions;
  }

  Future<Uint8List?> _watermarkPDF(String inputPath, String text) async {
    setState(() {
      _progress = 0.4;
    });

    try {
      log('Starting PDF watermarking: $inputPath');

      // Read the PDF file
      final inputBytes = await File(inputPath).readAsBytes();
      if (inputBytes.isEmpty) {
        throw Exception('Input PDF file is empty');
      }

      final PdfDocument document = PdfDocument(inputBytes: inputBytes);
      final totalPages = document.pages.count;
      log('PDF has $totalPages pages');

      setState(() {
        _progress = 0.5;
      });

      // Add watermark to all pages with diagonal pattern
      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final PdfPage page = document.pages[pageIndex];
        final PdfGraphics graphics = page.graphics;

        // Get page dimensions
        final double pageWidth = page.size.width;
        final double pageHeight = page.size.height;
        log('Page ${pageIndex + 1}: ${pageWidth}x$pageHeight');

        // Calculate font size based on page dimensions (similar to images)
        final minDimension = pageWidth < pageHeight ? pageWidth : pageHeight;
        final fontSize = (minDimension * 0.08).clamp(20.0, 80.0);
        log('Calculated font size: $fontSize for page ${pageIndex + 1}');

        // Create font for watermark
        final PdfFont font = PdfStandardFont(
          PdfFontFamily.helvetica,
          fontSize,
          style: PdfFontStyle.bold,
        );

        // Calculate diagonal positions for this page
        final positions = _calculateDiagonalPositions(
          pageWidth.toInt(),
          pageHeight.toInt(),
          fontSize.toInt(),
        );

        // Filter positions to ensure full page coverage
        final validPositions = positions.where((pos) {
          final x = pos['x'] as int;
          final y = pos['y'] as int;
          return x >= -pageWidth.toInt() * 0.5 &&
              x < pageWidth.toInt() * 1.5 &&
              y >= -pageHeight.toInt() * 0.5 &&
              y < pageHeight.toInt() * 1.5;
        }).toList();

        log(
          'Page ${pageIndex + 1}: Adding ${validPositions.length} watermarks',
        );

        // Set transparency for all watermarks on this page
        graphics.setTransparency(_watermarkOpacity);

        // Create brush with watermark color
        final brush = PdfSolidBrush(
          PdfColor(
            _watermarkColor.red,
            _watermarkColor.green,
            _watermarkColor.blue,
          ),
        );

        // Rotation angle for diagonal watermarks (-45 degrees)
        const double rotationAngle = -0.785398; // -45 degrees in radians

        // Add watermarks at calculated positions
        for (int i = 0; i < validPositions.length; i++) {
          final pos = validPositions[i];
          final x = pos['x'] as int;
          final y = pos['y'] as int;

          try {
            // Save graphics state
            graphics.save();

            // Translate to position
            graphics.translateTransform(x.toDouble(), y.toDouble());

            // Rotate for diagonal watermark
            graphics.rotateTransform(rotationAngle * 180 / 3.14159);

            // Measure text to center it
        final PdfStringFormat format = PdfStringFormat(
          alignment: PdfTextAlignment.center,
        );
        final Size textSize = font.measureString(text, format: format);

            // Draw watermark text
        graphics.drawString(
          text,
          font,
              brush: brush,
              bounds: Rect.fromLTWH(
                -textSize.width / 2,
                -textSize.height / 2,
                textSize.width,
                textSize.height,
              ),
          format: format,
        );

            // Restore graphics state
            graphics.restore();
          } catch (e) {
            log('Error adding watermark at position $i on page ${pageIndex + 1}: $e');
            // Continue with remaining watermarks
          }
        }

        setState(() {
          _progress = 0.5 + (0.4 * (pageIndex + 1) / totalPages);
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

      if (bytes.isEmpty) {
        throw Exception('Failed to generate watermarked PDF - output is empty');
      }

      log(
        'Watermarked PDF created successfully, size: ${bytes.length} bytes',
      );
      return Uint8List.fromList(bytes);
    } catch (e, stackTrace) {
      log('Error in _watermarkPDF: $e');
      log('Stack trace: $stackTrace');
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
