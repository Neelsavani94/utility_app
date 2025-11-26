import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import 'models/pdf_page_image.dart';

class SplitPdfImagesListScreen extends StatefulWidget {
  final List<PdfPageImage> pageImages;

  const SplitPdfImagesListScreen({super.key, required this.pageImages});

  @override
  State<SplitPdfImagesListScreen> createState() => _SplitPdfImagesListScreenState();
}

class _SplitPdfImagesListScreenState extends State<SplitPdfImagesListScreen> {
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
          'Edited Images (${widget.pageImages.length})',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareAllImages,
            tooltip: 'Share All Images',
          ),
        ],
      ),
      body: widget.pageImages.isEmpty
          ? _buildEmptyState(colorScheme)
          : _buildImagesList(colorScheme, isDark),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.25),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            'No images available',
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

  Widget _buildImagesList(ColorScheme colorScheme, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppConstants.spacingM,
        mainAxisSpacing: AppConstants.spacingM,
        childAspectRatio: 0.75,
      ),
      itemCount: widget.pageImages.length,
      itemBuilder: (context, index) {
        final pageImage = widget.pageImages[index];
        return _buildImageCard(pageImage, colorScheme, isDark, index);
      },
    );
  }

  Widget _buildImageCard(
    PdfPageImage pageImage,
    ColorScheme colorScheme,
    bool isDark,
    int index,
  ) {
    return GestureDetector(
      onTap: () => _viewImageFullScreen(pageImage, index),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surface.withOpacity(0.5)
              : Colors.white,
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
                  : colorScheme.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: _ImagePreviewWidget(pageImage: pageImage),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingS),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Page ${pageImage.pageNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withOpacity(0.85),
                          ),
                        ),
                        if (pageImage.isEdited)
                          Text(
                            'Edited',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onSelected: (value) {
                      if (value == 'share') {
                        _shareImage(pageImage);
                      } else if (value == 'delete') {
                        _deleteImage(index);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_rounded, size: 18),
                            const SizedBox(width: AppConstants.spacingS),
                            const Text('Share'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 18, color: colorScheme.error),
                            const SizedBox(width: AppConstants.spacingS),
                            Text('Delete', style: TextStyle(color: colorScheme.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewImageFullScreen(PdfPageImage pageImage, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          pageImages: widget.pageImages,
          initialIndex: index,
        ),
      ),
    );
  }

  Future<void> _shareImage(PdfPageImage pageImage) async {
    try {
      final bytes = await pageImage.loadBytes();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/page_${pageImage.pageNumber}.png');
      await tempFile.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Page ${pageImage.pageNumber} from Split PDF',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing image: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _shareAllImages() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final List<XFile> files = [];

      for (final pageImage in widget.pageImages) {
        final bytes = await pageImage.loadBytes();
        final tempFile = File('${tempDir.path}/page_${pageImage.pageNumber}.png');
        await tempFile.writeAsBytes(bytes);
        files.add(XFile(tempFile.path));
      }

      await Share.shareXFiles(
        files,
        text: 'Split PDF Images (${widget.pageImages.length} pages)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing images: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _deleteImage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: Text('Are you sure you want to delete page ${widget.pageImages[index].pageNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                widget.pageImages.removeAt(index);
              });
              Navigator.of(context).pop();
              if (widget.pageImages.isEmpty) {
                NavigationService.goBack();
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewWidget extends StatelessWidget {
  const _ImagePreviewWidget({required this.pageImage});

  final PdfPageImage pageImage;

  @override
  Widget build(BuildContext context) {
    if (pageImage.editedBytes != null && pageImage.editedBytes!.isNotEmpty) {
      return Image.memory(
        pageImage.editedBytes!,
        fit: BoxFit.cover,
        key: ValueKey('edited_${pageImage.id}'),
      );
    }

    if (pageImage.imageBytes != null) {
      return Image.memory(
        pageImage.imageBytes!,
        fit: BoxFit.cover,
        key: ValueKey('original_${pageImage.id}'),
      );
    }

    if (pageImage.imageFile != null) {
      return Image.file(
        pageImage.imageFile!,
        fit: BoxFit.cover,
        key: ValueKey('file_${pageImage.id}'),
      );
    }

    return Container(
      color: Colors.grey[300],
      child: const Center(child: Icon(Icons.error_outline)),
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final List<PdfPageImage> pageImages;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.pageImages,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Page ${widget.pageImages[_currentIndex].pageNumber} / ${widget.pageImages.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.pageImages.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final pageImage = widget.pageImages[index];
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: _ImagePreviewWidget(pageImage: pageImage),
            ),
          );
        },
      ),
    );
  }
}

