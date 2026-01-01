import 'dart:developer';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../Services/photo_editor_service.dart';

class CustomScannerScreen extends StatefulWidget {
  final int? documentId; // Optional documentId for saving to DocumentDetail table

  const CustomScannerScreen({super.key, this.documentId});

  @override
  State<CustomScannerScreen> createState() => _CustomScannerScreenState();
}

class _CustomScannerScreenState extends State<CustomScannerScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isAutoCapture = false;
  bool _showCustomDesign = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // Show scanner choice popup after a delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showScannerChoiceDialog();
        }
      });
    });
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      log('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing camera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showScannerChoiceDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.98)
                : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 15),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Please Choose Scanner to scan Documents',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                          setState(() {
                            _showCustomDesign = true;
                            _isAutoCapture = false; // Set default to Manual
                          });
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Icon(
                            Icons.close_rounded,
                            color: colorScheme.onSurface.withOpacity(0.7),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Scanner Options
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildScannerOption(
                        context: context,
                        colorScheme: colorScheme,
                        isDark: isDark,
                        title: 'AI Scanner',
                        icon: Icons.auto_awesome_rounded,
                        description: 'Advanced scanning',
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          Navigator.of(context).pop('ai');
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildScannerOption(
                        context: context,
                        colorScheme: colorScheme,
                        isDark: isDark,
                        title: 'Simple Scanner',
                        icon: Icons.document_scanner_rounded,
                        description: 'Quick scanning',
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          setState(() {
                            _showCustomDesign = true;
                            _isAutoCapture = false; // Set default to Manual
                          });
                        },
                      ),
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

  Widget _buildScannerOption({
    required BuildContext context,
    required ColorScheme colorScheme,
    required bool isDark,
    required String title,
    required IconData icon,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceVariant.withOpacity(0.3)
                : colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final image = await _cameraController!.takePicture();
      log('Image captured: ${image.path}');

      // Close the scanner screen first
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Open photo editor with captured image
      if (mounted) {
        final imageFile = File(image.path);
        // If documentId is provided, save to DocumentDetail table; otherwise create new document
        if (widget.documentId != null) {
          await PhotoEditorService.instance.openEditorAndSaveToDocumentDetail(
            context: context,
            imageFile: imageFile,
            documentId: widget.documentId!,
            watermarkText: 'Scanify AI',
          );
        } else {
          await PhotoEditorService.instance.openEditorAndSave(
            context: context,
            imageFile: imageFile,
            watermarkText: 'Scanify AI',
          );
        }
      }
    } catch (e) {
      log('Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        log('Image selected: ${image.path}');

        // Close the scanner screen first
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Open photo editor with selected image
        if (mounted) {
          final imageFile = File(image.path);
          // If documentId is provided, save to DocumentDetail table; otherwise create new document
          if (widget.documentId != null) {
            await PhotoEditorService.instance.openEditorAndSaveToDocumentDetail(
              context: context,
              imageFile: imageFile,
              documentId: widget.documentId!,
              watermarkText: 'Scanify AI',
            );
          } else {
            await PhotoEditorService.instance.openEditorAndSave(
              context: context,
              imageFile: imageFile,
              watermarkText: 'Scanify AI',
            );
          }
        }
      }
    } catch (e) {
      log('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleAutoCaptureToggle() {
    setState(() {
      _isAutoCapture = !_isAutoCapture;
    });

    // If Auto Capture is enabled, show AI Scanner popup again
    if (_isAutoCapture) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _showScannerChoiceDialog();
        }
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // Camera Preview - Full Screen
            if (_isInitialized && _cameraController != null)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(color: colorScheme.primary),
                  ),
                ),
              ),
            // Top Close Button
            Positioned(
              top: padding.top + 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(20),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  // Right side icons (mute, status)
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.volume_off_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bottom Custom Design (only show if Simple Scanner was selected)
            if (_showCustomDesign)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: padding.bottom + 16,
                    left: 16,
                    right: 16,
                    top: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Camera Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Gallery Button
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _pickFromGallery,
                                borderRadius: BorderRadius.circular(28),
                                child: const Icon(
                                  Icons.photo_library_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                          // Capture Button
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _captureImage,
                                borderRadius: BorderRadius.circular(36),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Info Button
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Privacy Notice'),
                                      content: const Text(
                                        'Scanify AI will have access only to the images that you scan.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(28),
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Manual/Auto Capture Toggle
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildToggleButton(
                              label: 'Manual',
                              isSelected: !_isAutoCapture,
                              onTap: () {
                                setState(() {
                                  _isAutoCapture = false;
                                });
                              },
                            ),
                            _buildToggleButton(
                              label: 'Auto capture',
                              isSelected: _isAutoCapture,
                              onTap: _handleAutoCaptureToggle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Privacy Notice
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white.withOpacity(0.7),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Scanify AI will have access only to the images that you scan',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
