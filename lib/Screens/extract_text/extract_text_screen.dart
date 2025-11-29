import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../../Models/extracted_text_model.dart';

class ExtractTextScreen extends StatefulWidget {
  final bool autoPickImage;
  
  const ExtractTextScreen({
    super.key,
    this.autoPickImage = false,
  });

  @override
  State<ExtractTextScreen> createState() => _ExtractTextScreenState();
}

class _ExtractTextScreenState extends State<ExtractTextScreen> {
  List<ExtractedTextModel> recentFiles = [];
  bool _isProcessing = false;
  final TextRecognizer _textRecognizer = TextRecognizer();
  ExtractedTextModel? _currentFile;
  PageController? _pageController;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    // Auto-trigger image picking if requested
    if (widget.autoPickImage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final colorScheme = Theme.of(context).colorScheme;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          _pickImage(colorScheme, isDark);
        }
      });
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _pageController?.dispose();
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
            onPressed: () {
              if (_currentFile != null) {
                setState(() {
                  _currentFile = null;
                  _pageController?.dispose();
                  _pageController = null;
                });
              } else {
                NavigationService.goBack();
              }
            },
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          _currentFile != null ? 'OCR Scanner' : 'Extract Text',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: _currentFile != null
            ? [
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.surface.withOpacity(0.2)
                        : colorScheme.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: colorScheme.onSurface,
                      size: 20,
                    ),
                    onPressed: () {
                      // Refresh functionality
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
              ]
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [colorScheme.background, colorScheme.background]
                : [
                    colorScheme.background,
                    colorScheme.surfaceVariant.withOpacity(0.3),
                  ],
          ),
        ),
        child: Stack(
          children: [
            if (_currentFile == null)
              // Initial view with pick buttons and recent files
              Column(
                children: [
                  // Top Row with Document and Image buttons
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.spacingM),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildPickButton(
                            context,
                            'Document',
                            Icons.description_rounded,
                            colorScheme.primary,
                            colorScheme,
                            isDark,
                            () => _pickDocument(colorScheme, isDark),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingM),
                        Expanded(
                          child: _buildPickButton(
                            context,
                            'Image',
                            Icons.image_rounded,
                            colorScheme.secondary,
                            colorScheme,
                            isDark,
                            () => _pickImage(colorScheme, isDark),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Recent Files Title
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingM,
                      vertical: AppConstants.spacingS,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Recent Files',
                          style: TextStyle(
                            color: colorScheme.onBackground,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Recent Files List/Grid
                  Expanded(
                    child: recentFiles.isEmpty
                        ? _buildEmptyState(context, colorScheme, isDark)
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.spacingM,
                            ),
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: AppConstants.spacingM,
                                mainAxisSpacing: AppConstants.spacingM,
                                childAspectRatio: 0.75,
                              ),
                              itemCount: recentFiles.length,
                              itemBuilder: (context, index) {
                                return _buildRecentFileCard(
                                  context,
                                  recentFiles[index],
                                  colorScheme,
                                  isDark,
                                  index,
                                );
                              },
                            ),
                          ),
                  ),
                ],
              )
            else
              // Preview view with document/image and extracted text
              _buildPreviewView(_currentFile!, colorScheme, isDark),
            if (_isProcessing)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppConstants.spacingL),
                    decoration: BoxDecoration(
                      color: isDark ? colorScheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingM),
                        Text(
                          'Extracting text...',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewView(
    ExtractedTextModel file,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final hasMultiplePages = file.pages != null && file.pages!.length > 1;

    return Column(
      children: [
        // Document/Image Preview Area (White background like screenshot)
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasMultiplePages
                  ? _buildMultiPageCarousel(file, colorScheme, isDark)
                  : _buildSinglePreview(file, colorScheme, isDark),
            ),
          ),
        ),

        // Extracted Text Section
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Name and Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scanify AI',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        // Share Button
                        IconButton(
                          icon: Icon(
                            Icons.share_rounded,
                            color: colorScheme.onSurface,
                            size: 24,
                          ),
                          onPressed: () => _shareText(
                            hasMultiplePages && _currentPageIndex < file.pages!.length
                                ? file.pages![_currentPageIndex].text
                                : file.extractedText,
                            colorScheme,
                          ),
                        ),
                        // Copy Button
                        IconButton(
                          icon: Icon(
                            Icons.copy_rounded,
                            color: colorScheme.onSurface,
                            size: 24,
                          ),
                          onPressed: () => _copyText(
                            hasMultiplePages && _currentPageIndex < file.pages!.length
                                ? file.pages![_currentPageIndex].text
                                : file.extractedText,
                            colorScheme,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingS),

                // Extracted Text Display
                Expanded(
                  child: SingleChildScrollView(
                    child: hasMultiplePages
                        ? _buildPageText(file, _currentPageIndex, colorScheme)
                        : Text(
                            file.extractedText,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface,
                              height: 1.5,
                              letterSpacing: 0.2,
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

  Widget _buildSinglePreview(
    ExtractedTextModel file,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    if (file.fileType == 'image' && file.filePath != null) {
      return Image.file(
        File(file.filePath!),
        fit: BoxFit.contain,
      );
    } else if (file.fileType == 'document' && file.filePath != null) {
      // Show PDF preview placeholder with document icon
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_rounded,
                size: 64,
                color: colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: AppConstants.spacingM),
              Text(
                file.fileName,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (file.pages != null && file.pages!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppConstants.spacingS),
                  child: Text(
                    '${file.pages!.length} pages',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        file.fileType == 'document'
            ? Icons.description_rounded
            : Icons.image_rounded,
        size: 64,
        color: colorScheme.onSurface.withOpacity(0.3),
      ),
    );
  }

  Widget _buildMultiPageCarousel(
    ExtractedTextModel file,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    if (_pageController == null) {
      _pageController = PageController();
    }

    return Stack(
      children: [
        // PDF Pages Carousel with PageView
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPageIndex = index;
            });
          },
          itemCount: file.pages!.length,
          itemBuilder: (context, index) {
            return Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_rounded,
                      size: 64,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: AppConstants.spacingM),
                    Text(
                      'Page ${index + 1} of ${file.pages!.length}',
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingS),
                    Text(
                      file.fileName,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Page Indicator (Bottom Center)
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              file.pages!.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPageIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPageIndex == index
                      ? colorScheme.primary
                      : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageText(
    ExtractedTextModel file,
    int pageIndex,
    ColorScheme colorScheme,
  ) {
    if (file.pages != null && pageIndex < file.pages!.length) {
      return Text(
        file.pages![pageIndex].text,
        style: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurface,
          height: 1.5,
          letterSpacing: 0.2,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPickButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    ColorScheme colorScheme,
    bool isDark,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Opacity(
        opacity: _isProcessing ? 0.6 : 1.0,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.text_fields_rounded,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            'No extracted files yet',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppConstants.spacingXS),
          Text(
            'Pick a document or image to extract text',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentFileCard(
    BuildContext context,
    ExtractedTextModel file,
    ColorScheme colorScheme,
    bool isDark,
    int index,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.8 + (value * 0.2), child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentFile = file;
            if (file.pages != null && file.pages!.length > 1) {
              _pageController = PageController();
              _currentPageIndex = 0;
            }
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surface.withOpacity(0.5) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? colorScheme.outline.withOpacity(0.3)
                  : colorScheme.outline.withOpacity(0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        file.fileType == 'document'
                            ? colorScheme.primary
                            : colorScheme.secondary,
                        (file.fileType == 'document'
                                ? colorScheme.primary
                                : colorScheme.secondary)
                            .withOpacity(0.7),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          file.fileType == 'document'
                              ? Icons.description_rounded
                              : Icons.image_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      if (file.pages != null && file.pages!.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${file.pages!.length} pages',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      file.formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDocument(ColorScheme colorScheme, bool isDark) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        setState(() {
          _isProcessing = true;
        });

        try {
          await _processPDF(filePath, fileName);
        } catch (e) {
          _showError('Error processing PDF: $e', colorScheme);
        } finally {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      _showError('Error picking document: $e', colorScheme);
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickImage(ColorScheme colorScheme, bool isDark) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null) {
        setState(() {
          _isProcessing = true;
        });

        try {
          await _processImage(image.path, image.name);
        } catch (e) {
          _showError('Error processing image: $e', colorScheme);
        } finally {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      _showError('Error picking image: $e', colorScheme);
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processPDF(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final pdfDocument = PdfDocument(inputBytes: bytes);
      final pageCount = pdfDocument.pages.count;

      List<ExtractedTextPage> pages = [];
      String combinedText = '';

      for (int i = 0; i < pageCount; i++) {
        try {
          String pageText = '';

          try {
            final textExtractor = PdfTextExtractor(pdfDocument);
            pageText = textExtractor.extractText(startPageIndex: i, endPageIndex: i);
          } catch (e) {
            // Text extraction failed (may be scanned PDF)
          }

          if (pageText.isNotEmpty) {
            pages.add(ExtractedTextPage(
              pageNumber: i + 1,
              text: pageText,
            ));
            combinedText += 'Page ${i + 1}:\n$pageText\n\n';
          }
        } catch (e) {
          print('Error processing page ${i + 1}: $e');
        }
      }

      pdfDocument.dispose();

      if (pages.isNotEmpty) {
        final extractedFile = ExtractedTextModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: fileName,
          extractedText: combinedText.trim(),
          pages: pages,
          createdAt: DateTime.now(),
          fileType: 'document',
          filePath: filePath,
        );

        setState(() {
          recentFiles.insert(0, extractedFile);
          _currentFile = extractedFile;
          if (pages.length > 1) {
            _pageController = PageController();
            _currentPageIndex = 0;
          }
        });
      } else {
        _showError('No text found in PDF', Theme.of(context).colorScheme);
      }
    } catch (e) {
      throw Exception('Failed to process PDF: $e');
    }
  }

  Future<void> _processImage(String imagePath, String fileName) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.isNotEmpty) {
        final extractedFile = ExtractedTextModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: fileName,
          extractedText: recognizedText.text,
          createdAt: DateTime.now(),
          fileType: 'image',
          filePath: imagePath,
        );

        setState(() {
          recentFiles.insert(0, extractedFile);
          _currentFile = extractedFile;
        });
      } else {
        _showError('No text found in image', Theme.of(context).colorScheme);
      }
    } catch (e) {
      throw Exception('Failed to process image: $e');
    }
  }

  void _copyText(String text, ColorScheme colorScheme) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Text copied to clipboard'),
        backgroundColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareText(String text, ColorScheme colorScheme) async {
    try {
      await Share.share(text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing: $e'),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showError(String message, ColorScheme colorScheme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
