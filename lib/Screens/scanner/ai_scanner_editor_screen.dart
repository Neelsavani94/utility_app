import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/file_storage_service.dart';
import '../../Services/database_helper.dart';
import '../../Providers/home_provider.dart';

class AIScannerEditorScreen extends StatefulWidget {
  final List<File> images;

  const AIScannerEditorScreen({
    super.key,
    required this.images,
  });

  @override
  State<AIScannerEditorScreen> createState() => _AIScannerEditorScreenState();
}

class _AIScannerEditorScreenState extends State<AIScannerEditorScreen> {
  late final PageController _pageController;
  final List<_AIEditableImage> _images = [];
  int _currentIndex = 0;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _images.addAll(widget.images.map(_AIEditableImage.new));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _editImageWithAI(int index) async {
    if (index >= _images.length) return;

    final image = _images[index];
    final sourceBytes = await image.file.readAsBytes();
    final hostTheme = Theme.of(context);

    // Apply AI pre-processing before opening editor
    final aiEnhancedBytes = await _applyAIPreProcessing(sourceBytes);

    final editedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Theme(
          data: hostTheme,
          child: ProImageEditor.memory(
            aiEnhancedBytes,
            configs: ProImageEditorConfigs(
              heroTag: 'ai_image_$index',
              designMode: hostTheme.brightness == Brightness.dark
                  ? ImageEditorDesignMode.cupertino
                  : ImageEditorDesignMode.material,
              theme: hostTheme,
              helperLines: const HelperLineConfigs(),
            ),
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (bytes) async {
                if (context.mounted) {
                  Navigator.of(context).pop(bytes);
                }
              },
              onCloseEditor: (_) {
                Navigator.of(context).maybePop();
              },
            ),
          ),
        ),
      ),
    );

    if (editedBytes != null) {
      setState(() {
        image.editedBytes = editedBytes;
        image.isEdited = true;
      });
    }
  }

  Future<Uint8List> _applyAIPreProcessing(Uint8List bytes) async {
    try {
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return bytes;

      // Apply initial AI enhancements
      image = _autoColorCorrection(image);
      image = _enhanceSharpness(image);
      image = _adjustContrast(image, 1.05);

      return Uint8List.fromList(img.encodeJpg(image, quality: 95));
    } catch (e) {
      return bytes;
    }
  }


  img.Image _autoColorCorrection(img.Image image) {
    return img.adjustColor(image,
        saturation: 1.1, brightness: 1.05, contrast: 1.05);
  }

  img.Image _enhanceSharpness(img.Image image) {
    return img.convolution(image, filter: [
      0, -1, 0,
      -1, 5, -1,
      0, -1, 0
    ]);
  }

  img.Image _adjustContrast(img.Image image, double contrast) {
    return img.adjustColor(image, contrast: contrast);
  }

  img.Image _reduceNoise(img.Image image) {
    var blurred = img.gaussianBlur(image, radius: 1);
    return img.adjustColor(blurred, contrast: 1.05);
  }

  img.Image _smartColorGrading(img.Image image) {
    // Advanced color grading
    var enhanced = img.adjustColor(image,
        saturation: 1.2, brightness: 1.08, contrast: 1.15);
    return enhanced;
  }

  img.Image _enhanceText(img.Image image) {
    // Enhance text readability
    var sharpened = img.convolution(image, filter: [
      0, -0.5, 0,
      -0.5, 3, -0.5,
      0, -0.5, 0
    ]);
    return img.adjustColor(sharpened, contrast: 1.2, brightness: 1.1);
  }

  img.Image _documentMode(img.Image image) {
    // Optimize for document scanning
    var enhanced = img.adjustColor(image,
        saturation: 0.3, brightness: 1.1, contrast: 1.3);
    return img.convolution(enhanced, filter: [
      0, -1, 0,
      -1, 5, -1,
      0, -1, 0
    ]);
  }

  img.Image _vibrantFilter(img.Image image) {
    return img.adjustColor(image,
        saturation: 1.4, brightness: 1.05, contrast: 1.1);
  }

  img.Image _professionalFilter(img.Image image) {
    var enhanced = img.adjustColor(image,
        saturation: 1.15, brightness: 1.03, contrast: 1.12);
    return img.gaussianBlur(enhanced, radius: 1);
  }

  Future<void> _exportAsPDF() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final PdfDocument document = PdfDocument();

      for (final image in _images) {
        final bytes = image.editedBytes ?? await image.file.readAsBytes();
        final page = document.pages.add();
        final pageSize = page.size;

        // Calculate image size to fit page
        final img.Image? decodedImage = img.decodeImage(bytes);
        if (decodedImage != null) {
          final imageWidth = decodedImage.width.toDouble();
          final imageHeight = decodedImage.height.toDouble();
          final pageWidth = pageSize.width - 40; // margins
          final pageHeight = pageSize.height - 40;

          double width = imageWidth;
          double height = imageHeight;

          // Scale to fit page
          if (width > pageWidth || height > pageHeight) {
            final scale =
                (pageWidth / width).clamp(0.0, pageHeight / height);
            width = imageWidth * scale;
            height = imageHeight * scale;
          }

          final x = (pageSize.width - width) / 2;
          final y = (pageSize.height - height) / 2;

          page.graphics.drawImage(
            PdfBitmap(bytes),
            Rect.fromLTWH(x, y, width, height),
          );
        }
      }

      final pdfBytesList = await document.save();
      document.dispose();
      final pdfBytes = Uint8List.fromList(pdfBytesList);

      // Save PDF using file storage service
      final fileStorageService = FileStorageService.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final docId = await fileStorageService.savePDFFile(
        pdfBytes: pdfBytes,
        fileName: 'ai_scan_$timestamp.pdf',
        title: 'AI_Scan_PDF',
      );
      
      // Get the saved file path from database
      String? pdfPath;
      if (docId != null) {
        final savedDoc = await DatabaseHelper.instance.getDocumentById(docId);
        pdfPath = savedDoc?.imagePath;
        
        // Refresh home screen documents
        if (mounted) {
          final provider = Provider.of<HomeProvider>(context, listen: false);
          provider.loadDocuments();
        }
      }

      setState(() {
        _isExporting = false;
      });

      if (mounted) {
        _showExportDialog(pdfPath != null ? [pdfPath] : [], isPDF: true);
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
      });
      _showMessage('Error creating PDF: $e');
    }
  }

  Future<void> _exportAsImages() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final fileStorageService = FileStorageService.instance;
      int savedCount = 0;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < _images.length; i++) {
        final image = _images[i];
        final bytes = image.editedBytes ?? await image.file.readAsBytes();
        final fileName = 'ai_scan_${timestamp}_${i + 1}.jpg';
        
        final docId = await fileStorageService.saveImageFile(
          imageBytes: bytes,
          fileName: fileName,
          title: 'AI_Scan_${i + 1}',
        );

        if (docId != null) {
          savedCount++;
        }
      }

      setState(() {
        _isExporting = false;
      });

      if (mounted) {
        // Refresh home screen documents
        final provider = Provider.of<HomeProvider>(context, listen: false);
        provider.loadDocuments();
        
        _showExportDialog([], isPDF: false, count: savedCount);
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
      });
      _showMessage('Error saving images: $e');
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showExportDialog(List<String> paths, {bool isPDF = false, int? count}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text('Exported Successfully'),
          ],
        ),
        content: Text(
          isPDF
              ? 'PDF exported with ${_images.length} page(s).'
              : '${count ?? paths.length} image(s) exported successfully.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (isPDF && paths.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Share.shareXFiles([XFile(paths.first)]);
              },
              child: const Text('Share'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_images.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('No Images'),
        ),
        body: const Center(child: Text('No images to view')),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colorScheme.onSurface,
          ),
          onPressed: () => NavigationService.goBack(),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  'AI Scanner Editor',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              '${_currentIndex + 1} of ${_images.length}',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurface),
            onSelected: (value) {
              if (value == 'export_pdf') {
                _exportAsPDF();
              } else if (value == 'export_images') {
                _exportAsImages();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Export as PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_images',
                child: Row(
                  children: [
                    Icon(Icons.image_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Export as Images'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Image Viewer
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final image = _images[index];
                return GestureDetector(
                  onTap: () => _editImageWithAI(index),
                  child: Container(
                    margin: const EdgeInsets.all(AppConstants.spacingM),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: image.editedBytes != null
                              ? Image.memory(
                                  image.editedBytes!,
                                  fit: BoxFit.contain,
                                )
                              : Image.file(
                                  image.file,
                                  fit: BoxFit.contain,
                                ),
                        ),
                        if (image.isEdited)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'AI Edited',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // AI Features Info
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withOpacity(0.1),
                  colorScheme.secondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'AI Enhanced',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap image to edit with AI-powered tools',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // Bottom Controls
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thumbnail strip
                if (_images.length > 1)
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        final image = _images[index];
                        final isSelected = index == _currentIndex;
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: image.editedBytes != null
                                      ? Image.memory(
                                          image.editedBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          image.file,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                if (image.isEdited)
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                if (_images.length > 1)
                  const SizedBox(height: AppConstants.spacingM),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // AI Edit button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _editImageWithAI(_currentIndex),
                        icon: Icon(Icons.auto_awesome_rounded),
                        label: const Text('AI Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    // Save Images button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _exportAsImages,
                        icon: _isExporting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : const Icon(Icons.image_rounded),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.secondary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    // Export PDF button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _exportAsPDF,
                        icon: _isExporting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.tertiary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
}

class _AIEditableImage {
  final File file;
  Uint8List? editedBytes;
  bool isEdited;

  _AIEditableImage(this.file) : isEdited = false;
}

