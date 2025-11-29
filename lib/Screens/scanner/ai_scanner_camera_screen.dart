import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';

class AIScannerCameraScreen extends StatefulWidget {
  const AIScannerCameraScreen({super.key});

  @override
  State<AIScannerCameraScreen> createState() => _AIScannerCameraScreenState();
}

class _AIScannerCameraScreenState extends State<AIScannerCameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _autoCapture = false;
  bool _torchEnabled = false;
  List<File> _capturedImages = [];
  bool _showEdgeDetection = true;
  List<CameraDescription>? _cameras;
  DateTime? _lastCaptureTime;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras available')),
          );
        }
        return;
      }

      // Use back camera by default
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium, // Use medium to reduce buffer usage
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _disposeCamera();
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    if (_controller != null) {
      try {
        // Stop any active image streams
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
      } catch (e) {
        // Ignore errors when stopping stream
      }
      
      try {
        await _controller!.dispose();
      } catch (e) {
        // Ignore disposal errors
      }
      
      _controller = null;
      _isInitialized = false;
    }
  }

  Future<void> _captureImage() async {
    if (!_isInitialized || 
        _controller == null || 
        !_controller!.value.isInitialized || 
        _isCapturing) {
      return;
    }

    // Debounce: Prevent captures within 1 second of each other
    final now = DateTime.now();
    if (_lastCaptureTime != null && 
        now.difference(_lastCaptureTime!) < const Duration(seconds: 1)) {
      return;
    }
    _lastCaptureTime = now;

    setState(() {
      _isCapturing = true;
    });

    try {
      // Small delay to prevent rapid captures
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Check if still valid before capture
      if (!mounted || 
          _controller == null || 
          !_controller!.value.isInitialized) {
        setState(() {
          _isCapturing = false;
        });
        return;
      }
      
      // Capture image
      final XFile image = await _controller!.takePicture();
      final file = File(image.path);
      
      // Apply AI enhancements in background (don't block camera)
      // Process in isolate or with delay to prevent blocking
      final enhancedFile = await Future.microtask(() => _applyAIEnhancements(file));
      
      if (mounted) {
        setState(() {
          _capturedImages.add(enhancedFile);
          _isCapturing = false;
        });

        // Delay before navigation to ensure camera is stable
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Dispose camera before navigation to prevent buffer issues
        await _disposeCamera();
        
        // Navigate to AI editor
        if (mounted) {
          NavigationService.toAIScannerEditor(images: _capturedImages);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing image: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _toggleTorch() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      if (_torchEnabled) {
        await _controller!.setFlashMode(FlashMode.off);
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _torchEnabled = !_torchEnabled;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling flash: $e')),
        );
      }
    }
  }

  Future<File> _applyAIEnhancements(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) return imageFile;

      // Apply AI enhancements
      // 1. Auto color correction
      image = _autoColorCorrection(image);
      
      // 2. Noise reduction
      image = _reduceNoise(image);
      
      // 3. Sharpness enhancement
      image = _enhanceSharpness(image);
      
      // 4. Contrast adjustment
      image = _adjustContrast(image, 1.1);

      // Save enhanced image
      final enhancedBytes = img.encodeJpg(image, quality: 95);
      final directory = await getApplicationDocumentsDirectory();
      final enhancedPath = '${directory.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final enhancedFile = File(enhancedPath);
      await enhancedFile.writeAsBytes(enhancedBytes);
      
      return enhancedFile;
    } catch (e) {
      // If enhancement fails, return original
      return imageFile;
    }
  }

  img.Image _autoColorCorrection(img.Image image) {
    // Auto white balance and color correction
    return img.adjustColor(image, 
      saturation: 1.1,
      brightness: 1.05,
    );
  }

  img.Image _reduceNoise(img.Image image) {
    // Simple noise reduction using blur and sharpen
    var blurred = img.gaussianBlur(image, radius: 1);
    return img.adjustColor(blurred, contrast: 1.05);
  }

  img.Image _enhanceSharpness(img.Image image) {
    // Sharpness enhancement
    return img.convolution(image, filter: [
      0, -1, 0,
      -1, 5, -1,
      0, -1, 0
    ]);
  }

  img.Image _adjustContrast(img.Image image, double contrast) {
    return img.adjustColor(image, contrast: contrast);
  }

  Widget _buildEdgeDetectionOverlay(Size screenSize) {
    if (!_showEdgeDetection) return const SizedBox.shrink();

    return Center(
      child: Container(
        width: screenSize.width * 0.85,
        height: screenSize.height * 0.5,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.green,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Corner indicators with animation
            ...List.generate(4, (index) {
              final positions = [
                Alignment.topLeft,
                Alignment.topRight,
                Alignment.bottomLeft,
                Alignment.bottomRight,
              ];
              return Positioned.fill(
                child: Align(
                  alignment: positions[index],
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border(
                        left: index == 0 || index == 2
                            ? const BorderSide(color: Colors.green, width: 4)
                            : BorderSide.none,
                        right: index == 1 || index == 3
                            ? const BorderSide(color: Colors.green, width: 4)
                            : BorderSide.none,
                        top: index == 0 || index == 1
                            ? const BorderSide(color: Colors.green, width: 4)
                            : BorderSide.none,
                        bottom: index == 2 || index == 3
                            ? const BorderSide(color: Colors.green, width: 4)
                            : BorderSide.none,
                      ),
                    ),
                  ),
                ),
              );
            }),
            // Center indicator
            Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;

    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          SizedBox.expand(
            child: CameraPreview(_controller!),
          ),

          // Edge Detection Overlay
          _buildEdgeDetectionOverlay(screenSize),

          // Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () async {
                        // Dispose camera before navigation
                        await _disposeCamera();
                        if (mounted) {
                          NavigationService.goBack();
                        }
                      },
                    ),
                  ),
                  Row(
                    children: [
                      // AI Mode indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colorScheme.primary, colorScheme.secondary],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'AI Mode',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Pages indicator
                      if (_capturedImages.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Stack(
                              children: [
                                const Icon(
                                  Icons.collections_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      '${_capturedImages.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onPressed: () async {
                              // Dispose camera before navigation
                              await _disposeCamera();
                              if (mounted) {
                                NavigationService.toAIScannerEditor(
                                  images: _capturedImages,
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Settings Panel
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 60, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Auto-capture toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _autoCapture
                              ? Icons.auto_awesome_rounded
                              : Icons.auto_awesome_outlined,
                          color: _autoCapture ? Colors.green : Colors.white,
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() {
                            _autoCapture = !_autoCapture;
                          });
                        },
                        tooltip: 'Auto Capture',
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Edge detection toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _showEdgeDetection
                              ? Icons.crop_free_rounded
                              : Icons.crop_free_outlined,
                          color: _showEdgeDetection ? Colors.green : Colors.white,
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() {
                            _showEdgeDetection = !_showEdgeDetection;
                          });
                        },
                        tooltip: 'Edge Detection',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Controls
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery button
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.photo_library_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () async {
                          // Gallery picker can still use image_picker
                          // or implement custom gallery picker
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gallery feature coming soon'),
                              ),
                            );
                          }
                        },
                      ),
                    ),

                    // Capture button
                    GestureDetector(
                      onTap: _captureImage,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.green,
                            width: 4,
                          ),
                          color: Colors.transparent,
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isCapturing
                                ? Colors.grey
                                : Colors.green,
                          ),
                        ),
                      ),
                    ),

                    // Flash toggle
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _torchEnabled
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: _toggleTorch,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // AI Processing indicator
          if (_isCapturing)
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI Processing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enhancing image quality',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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
}
