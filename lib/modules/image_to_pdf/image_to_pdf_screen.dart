import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:provider/provider.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/file_storage_service.dart';
import '../../Services/database_helper.dart';
import '../../Providers/home_provider.dart';
import 'models/image_item.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  List<ImageItem> _images = [];
  bool _isLoading = false;
  bool _isCreatingPdf = false;
  double _pdfProgress = 0.0;
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

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
          'Image to PDF',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? _buildLoadingState(colorScheme)
          : _images.isEmpty
              ? _buildEmptyState(colorScheme, isDark)
              : _buildPreviewSection(colorScheme, isDark),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: _isCreatingPdf ? _pdfProgress : null,
            color: colorScheme.primary,
          ),
          const SizedBox(height: AppConstants.spacingL),
          Text(
            _isCreatingPdf
                ? 'Creating PDF...\n${(_pdfProgress * 100).toStringAsFixed(0)}%'
                : 'Loading images...',
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
                Icons.image_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingXL),
            Text(
              'Select Images',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Choose images from your device to convert into a PDF document',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingXL),
            FilledButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Pick Images'),
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

  Widget _buildPreviewSection(ColorScheme colorScheme, bool isDark) {
    return Column(
      children: [
        Expanded(
          child: _buildImagePreview(colorScheme, isDark),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingL,
            AppConstants.spacingM,
            AppConstants.spacingL,
            AppConstants.spacingL,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FilledButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Add More'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.spacingM,
                      horizontal: AppConstants.spacingM,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _createPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Create PDF'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.spacingM,
                      horizontal: AppConstants.spacingM,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
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

  Widget _buildImagePreview(ColorScheme colorScheme, bool isDark) {
    return PageView.builder(
      controller: _pageController,
      itemCount: _images.length,
      onPageChanged: (index) {
        setState(() => _currentIndex = index);
      },
      itemBuilder: (context, index) {
        final image = _images[index];
        final isActive = index == _currentIndex;
        return Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(
                    horizontal: isActive ? 0 : 12,
                    vertical: isActive ? 0 : 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(
                          isActive ? 0.15 : 0.05,
                        ),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _PreviewImageWidget(image: image),
                        Positioned(
                          left: AppConstants.spacingM,
                          top: AppConstants.spacingM,
                          child: Chip(
                            backgroundColor: isDark
                                ? Colors.black54
                                : Colors.white.withOpacity(0.8),
                            label: Text(
                              'Image ${image.index + 1}${image.isEdited ? ' • Edited' : ''}',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : colorScheme.onSurface.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingM),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingM,
                  vertical: AppConstants.spacingS,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withOpacity(0.6)
                      : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${index + 1}/${_images.length}',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white
                        : colorScheme.onSurface.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingM),
              FilledButton.icon(
                onPressed: () => _openEditor(index),
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('Edit Image'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.spacingM,
                    horizontal: AppConstants.spacingL,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'webp'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final files = result.files
          .where((file) => file.path != null)
          .map((file) => File(file.path!))
          .toList();

      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Selected files could not be read'),
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            ),
          );
        }
        return;
      }

      setState(() {
        final startIndex = _images.length;
        _images.addAll(
          files.asMap().entries.map((entry) => ImageItem(
                originalFile: entry.value,
                index: startIndex + entry.key,
              )),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _openEditor(int index) async {
    if (!mounted) return;

    final image = _images[index];
    final sourceBytes = await image.loadBytes();

    final editedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ProImageEditorPage(
          initialBytes: sourceBytes,
          watermarkText: 'Scanify AI',
          hostTheme: Theme.of(context),
        ),
      ),
    );

    if (editedBytes != null && mounted) {
      setState(() {
        _images[index].editedBytes = editedBytes;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Image edited successfully'),
          duration: const Duration(seconds: 1),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _createPdf() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No images to convert'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isCreatingPdf = true;
      _pdfProgress = 0.0;
    });

    try {
      final pdfDocument = PdfDocument();
      final totalImages = _images.length;
      final totalSteps = totalImages + 1;
      int currentStep = 0;

      for (int i = 0; i < totalImages; i++) {
        currentStep++;
        setState(() {
          _pdfProgress = currentStep / totalSteps;
        });

        final imageBytes = await _images[i].loadBytes();
        final page = pdfDocument.pages.add();
        final pageSize = page.size;

        final image = PdfBitmap(imageBytes);
        final imageWidth = image.width.toDouble();
        final imageHeight = image.height.toDouble();

        final pageAspect = pageSize.width / pageSize.height;
        final imageAspect = imageWidth / imageHeight;

        double drawWidth, drawHeight, drawX, drawY;

        if (imageAspect > pageAspect) {
          drawWidth = pageSize.width;
          drawHeight = pageSize.width / imageAspect;
          drawX = 0;
          drawY = (pageSize.height - drawHeight) / 2;
        } else {
          drawHeight = pageSize.height;
          drawWidth = pageSize.height * imageAspect;
          drawX = (pageSize.width - drawWidth) / 2;
          drawY = 0;
        }

        page.graphics.drawImage(
          image,
          Rect.fromLTWH(drawX, drawY, drawWidth, drawHeight),
        );

        await Future.delayed(const Duration(milliseconds: 50));
      }

      currentStep++;
      setState(() {
        _pdfProgress = currentStep / totalSteps;
      });

      final pdfBytesList = await pdfDocument.save();
      pdfDocument.dispose();
      final pdfBytes = Uint8List.fromList(pdfBytesList);

      setState(() {
        _pdfProgress = 0.99;
      });

      // Save PDF using file storage service
      final fileStorageService = FileStorageService.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final docId = await fileStorageService.savePDFFile(
        pdfBytes: pdfBytes,
        fileName: 'Image_to_PDF_$timestamp.pdf',
        title: 'Image_to_PDF',
      );
      
      // Get the saved file path from database
      String? pdfPath;
      if (docId != null) {
        final document = await DatabaseHelper.instance.getDocumentById(docId);
        pdfPath = document?.imagePath;
        
        // Refresh home screen documents
        if (mounted) {
          final provider = Provider.of<HomeProvider>(context, listen: false);
          provider.loadDocuments();
        }
      }

      setState(() {
        _isLoading = false;
        _isCreatingPdf = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF created successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to PDF viewer if path is available
        if (pdfPath != null) {
          NavigationService.toScanPDFViewer(pdfPath: pdfPath);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isCreatingPdf = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating PDF: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _PreviewImageWidget extends StatelessWidget {
  const _PreviewImageWidget({required this.image});

  final ImageItem image;

  @override
  Widget build(BuildContext context) {
    if (image.editedBytes != null && image.editedBytes!.isNotEmpty) {
      return Image.memory(
        image.editedBytes!,
        fit: BoxFit.contain,
        key: ValueKey('edited_${image.id}'),
      );
    }

    return Image.file(
      image.originalFile,
      fit: BoxFit.contain,
      key: ValueKey('original_${image.id}'),
    );
  }
}

class _ProImageEditorPage extends StatelessWidget {
  const _ProImageEditorPage({
    required this.initialBytes,
    required this.watermarkText,
    required this.hostTheme,
  });

  final Uint8List initialBytes;
  final String watermarkText;
  final ThemeData hostTheme;

  @override
  Widget build(BuildContext context) {
    final configs = ProImageEditorConfigs(
      designMode: hostTheme.brightness == Brightness.dark
          ? ImageEditorDesignMode.cupertino
          : ImageEditorDesignMode.material,
      theme: hostTheme,
      helperLines: const HelperLineConfigs(),
    );

    return Theme(
      data: hostTheme,
      child: ProImageEditor.memory(
        initialBytes,
        configs: configs,
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
    );
  }
}

