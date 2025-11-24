import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';

class ScanPDFFilterScreen extends StatefulWidget {
  final List<File> imageFiles;

  const ScanPDFFilterScreen({
    super.key,
    required this.imageFiles,
  });

  @override
  State<ScanPDFFilterScreen> createState() => _ScanPDFFilterScreenState();
}

class _ScanPDFFilterScreenState extends State<ScanPDFFilterScreen> {
  int _currentImageIndex = 0;
  String _selectedFilter = 'Original';
  Map<String, Uint8List?> _filteredImages = {};
  
  // Crop area state
  double _cropLeft = 0.05; // 5% from left
  double _cropTop = 0.15; // 15% from top
  double _cropWidth = 0.9; // 90% width
  double _cropHeight = 0.7; // 70% height
  String? _draggingHandle;
  Offset? _dragStartGlobal;
  Size? _containerSize;
  // Store initial crop values when drag starts
  double _initialCropLeft = 0.05;
  double _initialCropTop = 0.15;
  double _initialCropWidth = 0.9;
  double _initialCropHeight = 0.7;
  final GlobalKey _cropContainerKey = GlobalKey();
  
  final List<Map<String, dynamic>> _filters = [
    {'name': 'Original', 'filter': null, 'icon': Icons.image_outlined},
    {'name': 'Text Carbon', 'filter': 'carbon', 'icon': Icons.auto_fix_high_outlined},
    {'name': 'OCV Black', 'filter': 'blackAndWhite', 'icon': Icons.filter_b_and_w_outlined},
    {'name': 'Sharp Pop', 'filter': 'sharp', 'icon': Icons.auto_awesome_outlined},
    {'name': 'Vintage', 'filter': 'vintage', 'icon': Icons.camera_alt_outlined},
    {'name': 'Scratch', 'filter': 'scratch', 'icon': Icons.brush_outlined},
    {'name': 'Sepia', 'filter': 'sepia', 'icon': Icons.color_lens_outlined},
    {'name': 'Cool', 'filter': 'cool', 'icon': Icons.ac_unit_outlined},
    {'name': 'Warm', 'filter': 'warm', 'icon': Icons.wb_sunny_outlined},
    {'name': 'High Contrast', 'filter': 'highContrast', 'icon': Icons.contrast_outlined},
  ];

  @override
  void initState() {
    super.initState();
    // Pre-load filters in background for better UX
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadFilterThumbnails();
    });
  }

  // Pre-load all filter thumbnails for better UX
  Future<void> _preloadFilterThumbnails() async {
    for (final filter in _filters) {
      final filterName = filter['name'] as String;
      final filterType = filter['filter'] as String?;
      if (filterType != null) {
        await _applyFilter(filterName, filterType);
      }
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
          'Crop Document',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
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
                Icons.check_rounded,
                color: colorScheme.onSurface,
                size: 20,
              ),
              onPressed: _processAndConvert,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main Image Display Area
          Expanded(
            child: Container(
              key: _cropContainerKey,
              margin: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Image with filter - Live preview (behind overlay)
                    Positioned.fill(
                      child: _buildFilteredImageLive(),
                    ),
                    // Crop overlay (on top)
                    _buildCropOverlay(),
                  ],
                ),
              ),
            ),
          ),

          // Filter Options Carousel
          Container(
            height: 140,
            padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingM,
              ),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final filterName = filter['name'] as String;
                final filterType = filter['filter'] as String?;
                final filterIcon = filter['icon'] as IconData;
                final isSelected = _selectedFilter == filterName;
                return GestureDetector(
                  onTap: () async {
                    setState(() {
                      _selectedFilter = filterName;
                    });
                    // Apply filter immediately for live preview
                    if (filterType != null) {
                      await _applyFilter(filterName, filterType);
                    }
                  },
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: AppConstants.spacingS),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outline.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isDark ? colorScheme.surface : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildFilterThumbnail(filterName, filterType),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingS),
                        Icon(
                          filterIcon,
                          color: colorScheme.onSurface,
                          size: 16,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          filterName,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        // Store container size for drag calculations
        _containerSize ??= Size(constraints.maxWidth, constraints.maxHeight);
        _containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        // Calculate crop area based on percentages
        final width = constraints.maxWidth * _cropWidth;
        final height = constraints.maxHeight * _cropHeight;
        final left = constraints.maxWidth * _cropLeft;
        final top = constraints.maxHeight * _cropTop;

        return Stack(
          children: [
            // Dark overlay with transparent crop area
            CustomPaint(
              painter: CropOverlayPainter(
                cropRect: Rect.fromLTWH(left, top, width, height),
                overlayColor: isDark
                    ? Colors.black.withOpacity(0.6)
                    : Colors.black.withOpacity(0.4),
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            ),
            // Crop area border and handles
            Positioned(
              left: left,
              top: top,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Grid lines
                    CustomPaint(
                      painter: GridPainter(),
                      size: Size(width, height),
                    ),
                    // Crop handles - now interactive
                    ..._buildCropHandles(width, height, constraints.maxWidth, constraints.maxHeight),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildCropHandles(
    double width,
    double height,
    double containerWidth,
    double containerHeight,
  ) {
    return [
      // Top-left corner
      Positioned(
        left: -10,
        top: -10,
        child: _buildHandle(
          'topLeft',
          containerWidth,
          containerHeight,
        ),
      ),
      // Top-right corner
      Positioned(
        right: -10,
        top: -10,
        child: _buildHandle(
          'topRight',
          containerWidth,
          containerHeight,
        ),
      ),
      // Bottom-left corner
      Positioned(
        left: -10,
        bottom: -10,
        child: _buildHandle(
          'bottomLeft',
          containerWidth,
          containerHeight,
        ),
      ),
      // Bottom-right corner
      Positioned(
        right: -10,
        bottom: -10,
        child: _buildHandle(
          'bottomRight',
          containerWidth,
          containerHeight,
        ),
      ),
      // Top side
      Positioned(
        left: width / 2 - 10,
        top: -10,
        child: _buildHandle(
          'top',
          containerWidth,
          containerHeight,
        ),
      ),
      // Bottom side
      Positioned(
        left: width / 2 - 10,
        bottom: -10,
        child: _buildHandle(
          'bottom',
          containerWidth,
          containerHeight,
        ),
      ),
      // Left side
      Positioned(
        left: -10,
        top: height / 2 - 10,
        child: _buildHandle(
          'left',
          containerWidth,
          containerHeight,
        ),
      ),
      // Right side
      Positioned(
        right: -10,
        top: height / 2 - 10,
        child: _buildHandle(
          'right',
          containerWidth,
          containerHeight,
        ),
      ),
    ];
  }

  Widget _buildHandle(String handleType, double containerWidth, double containerHeight) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        final RenderBox? renderBox = _cropContainerKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          setState(() {
            _draggingHandle = handleType;
            _dragStartGlobal = details.globalPosition;
            // Store initial crop values
            _initialCropLeft = _cropLeft;
            _initialCropTop = _cropTop;
            _initialCropWidth = _cropWidth;
            _initialCropHeight = _cropHeight;
          });
        }
      },
      onPanUpdate: (details) {
        if (_draggingHandle == handleType && _dragStartGlobal != null) {
          // Convert global position to local position relative to container
          final RenderBox? renderBox = _cropContainerKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final localStart = renderBox.globalToLocal(_dragStartGlobal!);
            final localCurrent = renderBox.globalToLocal(details.globalPosition);
            final delta = localCurrent - localStart;
            
            // Update immediately for smooth dragging - always relative to initial position
            _updateCropArea(
              handleType,
              delta,
              containerWidth,
              containerHeight,
            );
          }
        }
      },
      onPanEnd: (details) {
        setState(() {
          _draggingHandle = null;
          _dragStartGlobal = null;
        });
      },
      child: Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surface : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.primary, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? Colors.black.withOpacity(0.5)
                      : Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateCropArea(
    String handleType,
    Offset delta,
    double containerWidth,
    double containerHeight,
  ) {
    if (_containerSize == null) return;

    // Convert pixel delta to percentage
    final deltaXPercent = delta.dx / containerWidth;
    final deltaYPercent = delta.dy / containerHeight;

    // Calculate new values based on handle type
    double newLeft = _initialCropLeft;
    double newTop = _initialCropTop;
    double newWidth = _initialCropWidth;
    double newHeight = _initialCropHeight;

    switch (handleType) {
      case 'topLeft':
        newLeft = (_initialCropLeft + deltaXPercent).clamp(0.0, _initialCropLeft + _initialCropWidth - 0.05);
        newTop = (_initialCropTop + deltaYPercent).clamp(0.0, _initialCropTop + _initialCropHeight - 0.05);
        newWidth = (_initialCropWidth - (newLeft - _initialCropLeft)).clamp(0.05, 1.0 - newLeft);
        newHeight = (_initialCropHeight - (newTop - _initialCropTop)).clamp(0.05, 1.0 - newTop);
        break;
      case 'topRight':
        newTop = (_initialCropTop + deltaYPercent).clamp(0.0, _initialCropTop + _initialCropHeight - 0.05);
        newWidth = (_initialCropWidth + deltaXPercent).clamp(0.05, 1.0 - _initialCropLeft);
        newHeight = (_initialCropHeight - (newTop - _initialCropTop)).clamp(0.05, 1.0 - newTop);
        break;
      case 'bottomLeft':
        newLeft = (_initialCropLeft + deltaXPercent).clamp(0.0, _initialCropLeft + _initialCropWidth - 0.05);
        newWidth = (_initialCropWidth - (newLeft - _initialCropLeft)).clamp(0.05, 1.0 - newLeft);
        newHeight = (_initialCropHeight + deltaYPercent).clamp(0.05, 1.0 - _initialCropTop);
        break;
      case 'bottomRight':
        newWidth = (_initialCropWidth + deltaXPercent).clamp(0.05, 1.0 - _initialCropLeft);
        newHeight = (_initialCropHeight + deltaYPercent).clamp(0.05, 1.0 - _initialCropTop);
        break;
      case 'top':
        newTop = (_initialCropTop + deltaYPercent).clamp(0.0, _initialCropTop + _initialCropHeight - 0.05);
        newHeight = (_initialCropHeight - (newTop - _initialCropTop)).clamp(0.05, 1.0 - newTop);
        break;
      case 'bottom':
        newHeight = (_initialCropHeight + deltaYPercent).clamp(0.05, 1.0 - _initialCropTop);
        break;
      case 'left':
        newLeft = (_initialCropLeft + deltaXPercent).clamp(0.0, _initialCropLeft + _initialCropWidth - 0.05);
        newWidth = (_initialCropWidth - (newLeft - _initialCropLeft)).clamp(0.05, 1.0 - newLeft);
        break;
      case 'right':
        newWidth = (_initialCropWidth + deltaXPercent).clamp(0.05, 1.0 - _initialCropLeft);
        break;
    }

    // Update state smoothly
    setState(() {
      _cropLeft = newLeft;
      _cropTop = newTop;
      _cropWidth = newWidth;
      _cropHeight = newHeight;
    });
  }

  Widget _buildFilteredImageLive() {
    return Center(
      child: Builder(
        builder: (context) {
          Widget imageWidget;
          
          if (_selectedFilter == 'Original') {
            imageWidget = Image.file(
              widget.imageFiles[_currentImageIndex],
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text('Error loading image: $error'),
                    ],
                  ),
                );
              },
            );
          } else {
            final imageKey = '${_currentImageIndex}_$_selectedFilter';
            
            // Show filtered image if available, otherwise show original while processing
            if (_filteredImages.containsKey(imageKey) && 
                _filteredImages[imageKey] != null) {
              imageWidget = Image.memory(
                _filteredImages[imageKey]!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.file(
                    widget.imageFiles[_currentImageIndex],
                    fit: BoxFit.contain,
                  );
                },
              );
            } else {
              // Show original while filter is being applied
              imageWidget = Stack(
                children: [
                  Image.file(
                    widget.imageFiles[_currentImageIndex],
                    fit: BoxFit.contain,
                  ),
                  // Loading indicator
                  Builder(
                    builder: (context) {
                      final colorScheme = Theme.of(context).colorScheme;
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.7)
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            }
          }
          
          return imageWidget;
        },
      ),
    );
  }

  Widget _buildFilterThumbnail(String filterName, String? filterType) {
    final imageKey = '${_currentImageIndex}_$filterName';
    
    if (filterType == null) {
      return Image.file(
        widget.imageFiles[_currentImageIndex],
        fit: BoxFit.cover,
      );
    }
    
    // Show filtered thumbnail if available
    if (_filteredImages.containsKey(imageKey) && 
        _filteredImages[imageKey] != null) {
      return Image.memory(
        _filteredImages[imageKey]!,
        fit: BoxFit.cover,
      );
    }
    
    // Show original with slight overlay while processing
    return Image.file(
      widget.imageFiles[_currentImageIndex],
      fit: BoxFit.cover,
      color: Colors.white.withOpacity(0.3),
      colorBlendMode: BlendMode.overlay,
    );
  }

  Future<void> _applyFilter(String filterName, String? filterType) async {
    if (filterType == null) {
      setState(() {});
      return;
    }

    final imageKey = '${_currentImageIndex}_$filterName';
    
    // If already processed, just update UI
    if (_filteredImages.containsKey(imageKey)) {
      setState(() {});
      return;
    }

    try {
      final imageBytes = await widget.imageFiles[_currentImageIndex].readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);
      
      if (decodedImage != null) {
        img.Image processedImage = decodedImage;
        
        // Apply filter based on type
        switch (filterType) {
          case 'carbon':
            // Text Carbon - Invert and enhance contrast
            processedImage = img.invert(decodedImage);
            processedImage = img.adjustColor(
              processedImage,
              contrast: 1.5,
              brightness: 0.9,
            );
            break;
            
          case 'blackAndWhite':
            // OCV Black - Pure grayscale
            processedImage = img.grayscale(decodedImage);
            processedImage = img.adjustColor(
              processedImage,
              contrast: 1.2,
            );
            break;
            
          case 'sharp':
            // Sharp Pop - High contrast and saturation
            processedImage = img.adjustColor(
              decodedImage,
              contrast: 1.4,
              brightness: 1.15,
              saturation: 1.3,
            );
            break;
            
          case 'vintage':
            // Vintage - Sepia with warm tones
            processedImage = img.grayscale(decodedImage);
            processedImage = _applyColorTint(processedImage, 1.2, 1.1, 0.9);
            processedImage = img.adjustColor(
              processedImage,
              contrast: 1.1,
            );
            break;
            
          case 'scratch':
            // Scratch effect - High contrast black and white with noise
            processedImage = img.grayscale(decodedImage);
            processedImage = img.adjustColor(
              processedImage,
              contrast: 2.0,
              brightness: 0.8,
            );
            // Add some noise for scratch effect
            processedImage = _addNoise(processedImage, intensity: 0.1);
            break;
            
          case 'sepia':
            // Sepia tone
            processedImage = img.grayscale(decodedImage);
            processedImage = _applyColorTint(processedImage, 1.35, 1.2, 0.95);
            break;
            
          case 'cool':
            // Cool tone - Blue tint
            processedImage = _applyColorTint(decodedImage, 0.9, 1.0, 1.2);
            processedImage = img.adjustColor(
              processedImage,
              saturation: 1.1,
            );
            break;
            
          case 'warm':
            // Warm tone - Orange/red tint
            processedImage = _applyColorTint(decodedImage, 1.2, 1.1, 0.9);
            processedImage = img.adjustColor(
              processedImage,
              saturation: 1.1,
            );
            break;
            
          case 'highContrast':
            // High contrast - Maximum contrast
            processedImage = img.adjustColor(
              decodedImage,
              contrast: 2.0,
              brightness: 1.0,
            );
            break;
            
          default:
            processedImage = decodedImage;
        }
        
        final filteredBytes = Uint8List.fromList(
          img.encodePng(processedImage),
        );

        setState(() {
          _filteredImages[imageKey] = filteredBytes;
        });
      }
    } catch (e) {
      print('Error applying filter: $e');
    }
  }
  
  // Apply color tint to image
  img.Image _applyColorTint(img.Image image, double rFactor, double gFactor, double bFactor) {
    final tintedImage = img.Image.from(image);
    
    for (int y = 0; y < tintedImage.height; y++) {
      for (int x = 0; x < tintedImage.width; x++) {
        final pixel = tintedImage.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        
        final newR = (r * rFactor).clamp(0, 255).toInt();
        final newG = (g * gFactor).clamp(0, 255).toInt();
        final newB = (b * bFactor).clamp(0, 255).toInt();
        
        tintedImage.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
      }
    }
    
    return tintedImage;
  }
  
  // Add noise for scratch effect
  img.Image _addNoise(img.Image image, {double intensity = 0.1}) {
    final noiseImage = img.Image.from(image);
    final random = math.Random();
    
    for (int y = 0; y < noiseImage.height; y++) {
      for (int x = 0; x < noiseImage.width; x++) {
        final pixel = noiseImage.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        
        // Add random noise
        final noise = (random.nextDouble() - 0.5) * 255 * intensity;
        final newR = (r + noise).clamp(0, 255).toInt();
        final newG = (g + noise).clamp(0, 255).toInt();
        final newB = (b + noise).clamp(0, 255).toInt();
        
        noiseImage.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
      }
    }
    
    return noiseImage;
  }

  void _processAndConvert() {
    // Navigate to progress screen
    NavigationService.toScanPDFProgress(
      imageFiles: widget.imageFiles,
      filter: _selectedFilter,
      filteredImages: _filteredImages,
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Grid lines should be subtle - use a neutral color
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1;

    // Vertical lines
    for (double i = size.width / 3; i < size.width; i += size.width / 3) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }

    // Horizontal lines
    for (double i = size.height / 3; i < size.height; i += size.height / 3) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final Color overlayColor;

  CropOverlayPainter({
    required this.cropRect,
    this.overlayColor = const Color(0x80000000),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    // Draw dark overlay with transparent crop area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create hole for crop area
    final cropPath = Path()
      ..addRect(cropRect);

    // Combine paths to create overlay with hole
    final combinedPath = Path.combine(
      PathOperation.difference,
      path,
      cropPath,
    );

    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is CropOverlayPainter) {
      return oldDelegate.cropRect != cropRect;
    }
    return true;
  }
}

