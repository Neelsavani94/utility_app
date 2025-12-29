import 'dart:developer';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CustomDocumentScannerScreen extends StatefulWidget {
  const CustomDocumentScannerScreen({super.key});

  @override
  State<CustomDocumentScannerScreen> createState() =>
      _CustomDocumentScannerScreenState();
}

class _CustomDocumentScannerScreenState
    extends State<CustomDocumentScannerScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isAutoCapture = false;
  String? _selectedScannerType; // 'ai' or 'simple'

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // Show dialog after a small delay to allow camera to initialize
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.98)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Please Choose Scanner to scan Documents',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(16),
                          child: Icon(
                            Icons.close_rounded,
                            color: colorScheme.onSurface,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Scanner Options
                Row(
                  children: [
                    Expanded(
                      child: _buildScannerOption(
                        context: context,
                        colorScheme: colorScheme,
                        title: 'AI Scanner',
                        icon: Icons.auto_awesome,
                        isSelected: _selectedScannerType == 'ai',
                        onTap: () {
                          setState(() {
                            _selectedScannerType = 'ai';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildScannerOption(
                        context: context,
                        colorScheme: colorScheme,
                        title: 'Simple Scanner',
                        icon: Icons.qr_code_scanner,
                        isSelected: _selectedScannerType == 'simple',
                        onTap: () {
                          setState(() {
                            _selectedScannerType = 'simple';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // OK Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _selectedScannerType != null
                        ? () {
                            // Close dialog first
                            Navigator.of(context).pop();
                            // Then close custom scanner screen and return selected type
                            Navigator.of(context).pop(_selectedScannerType);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          colorScheme.surfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Ok',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerOption({
    required BuildContext context,
    required ColorScheme colorScheme,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Illustration placeholder (can be replaced with custom widget)
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    // If no scanner type selected, show dialog first
    if (_selectedScannerType == null) {
      _showScannerChoiceDialog();
      return;
    }

    // Return selected scanner type to home screen
    if (mounted) {
      Navigator.of(context).pop(_selectedScannerType);
    }
  }

  Future<void> _pickFromGallery() async {
    // If no scanner type selected, show dialog first
    if (_selectedScannerType == null) {
      _showScannerChoiceDialog();
      return;
    }

    // Return selected scanner type to home screen
    if (mounted) {
      Navigator.of(context).pop(_selectedScannerType);
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_isInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          // Top Close Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
          ),
          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                            onTap: () {
                              setState(() {
                                _isAutoCapture = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
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
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
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
                                // Show privacy info
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
                    // Privacy Notice
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Scanify AI will have access only to the images that you scan',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
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

