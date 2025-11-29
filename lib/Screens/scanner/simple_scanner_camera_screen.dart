import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import 'simple_scanner_type_screen.dart';

class SimpleScannerCameraScreen extends StatefulWidget {
  final ScanType scanType;

  const SimpleScannerCameraScreen({
    super.key,
    required this.scanType,
  });

  @override
  State<SimpleScannerCameraScreen> createState() =>
      _SimpleScannerCameraScreenState();
}

class _SimpleScannerCameraScreenState
    extends State<SimpleScannerCameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _torchEnabled = false;
  List<File> _capturedImages = [];
  List<CameraDescription>? _cameras;

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
        ResolutionPreset.high,
        enableAudio: false,
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
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile image = await _controller!.takePicture();
      final file = File(image.path);
      
      setState(() {
        _capturedImages.add(file);
        _isCapturing = false;
      });

      // Navigate to editor with all captured images
      NavigationService.toSimpleScannerEditor(
        images: _capturedImages,
        scanType: widget.scanType,
      );
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
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

  Widget _buildFrameOverlay(ScanType scanType, Size screenSize) {
    final frameColor = Colors.white;

    switch (scanType) {
      case ScanType.document:
        // A4 document frame
        final frameWidth = screenSize.width * 0.85;
        final frameHeight = frameWidth * 1.414; // A4 ratio
        return Center(
          child: Container(
            width: frameWidth,
            height: frameHeight,
            decoration: BoxDecoration(
              border: Border.all(color: frameColor, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // Corner indicators
                Positioned(
                  top: -1,
                  left: -1,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: frameColor, width: 4),
                        top: BorderSide(color: frameColor, width: 4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: frameColor, width: 4),
                        top: BorderSide(color: frameColor, width: 4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  left: -1,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: frameColor, width: 4),
                        bottom: BorderSide(color: frameColor, width: 4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: frameColor, width: 4),
                        bottom: BorderSide(color: frameColor, width: 4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case ScanType.book:
        // Book page frame (wider)
        final frameWidth = screenSize.width * 0.9;
        final frameHeight = frameWidth * 1.3;
        return Center(
          child: Container(
            width: frameWidth,
            height: frameHeight,
            decoration: BoxDecoration(
              border: Border.all(color: frameColor, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );

      case ScanType.idCard:
        // ID card frame (credit card size)
        final frameWidth = screenSize.width * 0.75;
        final frameHeight = frameWidth * 0.63; // ID card ratio
        return Center(
          child: Container(
            width: frameWidth,
            height: frameHeight,
            decoration: BoxDecoration(
              border: Border.all(color: frameColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

      case ScanType.ocr:
        // OCR frame (similar to document)
        final frameWidth = screenSize.width * 0.85;
        final frameHeight = frameWidth * 1.2;
        return Center(
          child: Container(
            width: frameWidth,
            height: frameHeight,
            decoration: BoxDecoration(
              border: Border.all(color: frameColor, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

      case ScanType.photo:
        // No frame, just grid lines
        return Center(
          child: Container(
            width: screenSize.width * 0.9,
            height: screenSize.height * 0.6,
            decoration: BoxDecoration(
              border: Border.all(
                color: frameColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: CustomPaint(
              painter: GridPainter(color: frameColor.withOpacity(0.3)),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
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

          // Frame Overlay
          _buildFrameOverlay(widget.scanType, screenSize),

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
                      onPressed: () => NavigationService.goBack(),
                    ),
                  ),
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
                                  color: Colors.green,
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
                        onPressed: () {
                          // Navigate to editor with existing images
                          NavigationService.toSimpleScannerEditor(
                            images: _capturedImages,
                            scanType: widget.scanType,
                          );
                        },
                      ),
                    ),
                ],
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
                          // For now, just show a message
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
                            color: Colors.white,
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
                                : Colors.white,
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

          // Scan type indicator
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingM,
                    vertical: AppConstants.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getScanTypeLabel(widget.scanType),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getScanTypeLabel(ScanType scanType) {
    switch (scanType) {
      case ScanType.document:
        return 'Document';
      case ScanType.book:
        return 'Book';
      case ScanType.ocr:
        return 'OCR';
      case ScanType.idCard:
        return 'ID Card';
      case ScanType.photo:
        return 'Photo';
    }
  }
}

class GridPainter extends CustomPainter {
  final Color color;

  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    // Draw grid lines (rule of thirds)
    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 3;

    // Vertical lines
    canvas.drawLine(
      Offset(thirdWidth, 0),
      Offset(thirdWidth, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(thirdWidth * 2, 0),
      Offset(thirdWidth * 2, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, thirdHeight),
      Offset(size.width, thirdHeight),
      paint,
    );
    canvas.drawLine(
      Offset(0, thirdHeight * 2),
      Offset(size.width, thirdHeight * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
