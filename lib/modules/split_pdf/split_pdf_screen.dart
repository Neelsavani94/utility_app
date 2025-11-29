import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/file_storage_service.dart';
import '../../Providers/home_provider.dart';
import 'models/pdf_page_image.dart';

class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  List<PdfPageImage> _pageImages = [];
  bool _isLoading = false;
  bool _isConverting = false;
  double _conversionProgress = 0.0;
  String? _pdfFileName;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Split PDF',
              style: TextStyle(
                color: colorScheme.onBackground,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            if (_pdfFileName != null)
              Text(
                _pdfFileName!,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.65),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_pageImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.checklist_rounded),
              onPressed: () => _navigateToImagesList(),
              tooltip: 'View All Images',
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState(colorScheme)
          : _pageImages.isEmpty
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
            value: _isConverting ? _conversionProgress : null,
            color: colorScheme.primary,
          ),
          const SizedBox(height: AppConstants.spacingL),
          Text(
            _isConverting
                ? 'Converting PDF pages to images...\n${(_conversionProgress * 100).toStringAsFixed(0)}%'
                : 'Loading PDF...',
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
                Icons.picture_as_pdf_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingXL),
            Text(
              'Select PDF to Split',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Choose a PDF file from your device to convert each page into an editable image',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingXL),
            FilledButton.icon(
              onPressed: _selectPdf,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Select PDF'),
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
                  onPressed: () => _selectPdf(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Select New PDF'),
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
                  onPressed: _saveAllImages,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save All Images'),
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
      itemCount: _pageImages.length,
      itemBuilder: (context, index) {
        final pageImage = _pageImages[index];
        return Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.15),
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
                        _PreviewImageWidget(pageImage: pageImage),
                        Positioned(
                          left: AppConstants.spacingM,
                          top: AppConstants.spacingM,
                          child: Chip(
                            backgroundColor: isDark
                                ? Colors.black54
                                : Colors.white.withOpacity(0.8),
                            label: Text(
                              'Page ${pageImage.pageNumber}${pageImage.isEdited ? ' • Edited' : ''}',
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
                  '${index + 1}/${_pageImages.length}',
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

  Future<void> _selectPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return;
      }

      final pdfFile = File(result.files.first.path!);
      _pdfFileName = result.files.first.name;

      await _convertPdfToImages(pdfFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting PDF: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _convertPdfToImages(File pdfFile) async {
    setState(() {
      _isLoading = true;
      _isConverting = true;
      _conversionProgress = 0.0;
      _pageImages = [];
    });

    try {
      final pdfBytes = await pdfFile.readAsBytes();
      final pdfDocument = PdfDocument(inputBytes: pdfBytes);
      final pageCount = pdfDocument.pages.count;

      if (pageCount == 0) {
        throw Exception('PDF has no pages');
      }

      final List<PdfPageImage> pageImages = [];
      final tempDir = await getTemporaryDirectory();
      final imagesDir = Directory('${tempDir.path}/split_pdf_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Render all pages at once and extract individual pages
      final imageStream = Printing.raster(
        pdfBytes,
        dpi: 300,
      );
      
      int pageIndex = 0;
      await for (final imageRaster in imageStream) {
        if (pageIndex >= pageCount) break;
        
        setState(() {
          _conversionProgress = (pageIndex + 1) / pageCount;
        });

        try {
          final imageBytes = await imageRaster.toPng();

          if (imageBytes.isNotEmpty) {
            // Save image to temporary directory
            final imageFile = File('${imagesDir.path}/page_${pageIndex + 1}.png');
            await imageFile.writeAsBytes(imageBytes);
            
            pageImages.add(
              PdfPageImage(
                pageNumber: pageIndex + 1,
                imageFile: imageFile,
                imageBytes: imageBytes,
              ),
            );
          }
        } catch (e) {
          print('Error converting page ${pageIndex + 1}: $e');
        }
        
        pageIndex++;
      }

      pdfDocument.dispose();

      if (pageImages.isEmpty) {
        throw Exception('Failed to convert any pages to images');
      }

      setState(() {
        _pageImages = pageImages;
        _isLoading = false;
        _isConverting = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isConverting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error converting PDF: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _openEditor(int index) async {
    if (!mounted) return;

    final pageImage = _pageImages[index];
    final sourceBytes = await pageImage.loadBytes();
    final currentIndex = index;

    // Navigate to editor screen and wait for result
    final result = await NavigationService.toSplitPdfPageEditor(
      initialBytes: sourceBytes,
      onImageEdited: null, // We'll use navigation result instead
    );

    // Check if we got edited bytes back from the editor
    if (mounted && result != null && result is Uint8List) {
      final Uint8List editedBytes = result;
      
      // Create a new list with updated image
      final updatedPageImages = List<PdfPageImage>.from(_pageImages);
      updatedPageImages[currentIndex] = PdfPageImage(
        pageNumber: pageImage.pageNumber,
        imageFile: pageImage.imageFile,
        imageBytes: pageImage.imageBytes,
        editedBytes: editedBytes,
        id: pageImage.id,
      );

      setState(() {
        _pageImages = updatedPageImages;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image edited successfully'),
            duration: const Duration(seconds: 1),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
  }

  Future<void> _saveAllImages() async {
    if (_pageImages.isEmpty) return;

    try {
      final fileStorageService = FileStorageService.instance;
      int savedCount = 0;

      for (final pageImage in _pageImages) {
        final bytes = await pageImage.loadBytes();
        final fileName = _pdfFileName != null
            ? '${_pdfFileName!.replaceAll('.pdf', '')}_page_${pageImage.pageNumber}${pageImage.isEdited ? '_edited' : ''}.png'
            : 'page_${pageImage.pageNumber}${pageImage.isEdited ? '_edited' : ''}.png';
        
        final docId = await fileStorageService.saveImageFile(
          imageBytes: bytes,
          fileName: fileName,
          title: _pdfFileName != null
              ? '${_pdfFileName!.replaceAll('.pdf', '')}_page_${pageImage.pageNumber}'
              : 'Page_${pageImage.pageNumber}',
        );

        if (docId != null) {
          savedCount++;
        }
      }

      // Refresh home screen documents
      if (mounted) {
        final provider = Provider.of<HomeProvider>(context, listen: false);
        provider.loadDocuments();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved $savedCount image(s) successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Navigate to images list screen
      _navigateToImagesList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving images: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _navigateToImagesList() {
    NavigationService.toSplitPdfImagesList(pageImages: _pageImages);
  }
}

class _PreviewImageWidget extends StatelessWidget {
  const _PreviewImageWidget({required this.pageImage});

  final PdfPageImage pageImage;

  @override
  Widget build(BuildContext context) {
    if (pageImage.editedBytes != null && pageImage.editedBytes!.isNotEmpty) {
      return Image.memory(
        pageImage.editedBytes!,
        fit: BoxFit.contain,
        key: ValueKey('edited_${pageImage.id}'),
      );
    }
    
    if (pageImage.imageBytes != null) {
      return Image.memory(
        pageImage.imageBytes!,
        fit: BoxFit.contain,
        key: ValueKey('original_${pageImage.id}'),
      );
    }
    
    if (pageImage.imageFile != null) {
      return Image.file(
        pageImage.imageFile!,
        fit: BoxFit.contain,
        key: ValueKey('file_${pageImage.id}'),
      );
    }
    
    return const Center(child: Icon(Icons.error_outline));
  }
}

