import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../../Routes/app_routes.dart';
import '../../Models/signature_model.dart';

class SignListScreen extends StatefulWidget {
  const SignListScreen({super.key});

  @override
  State<SignListScreen> createState() => _SignListScreenState();
}

class _SignListScreenState extends State<SignListScreen> {
  final GetStorage _storage = GetStorage();
  List<SignatureModel> _signatures = [];

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  // Reload when screen becomes visible again
  void _reloadOnResume() {
    _loadSignatures();
  }

  void _loadSignatures() {
    final signaturesJson = _storage.read('signatures') as List<dynamic>?;
    if (signaturesJson != null) {
      setState(() {
        _signatures = signaturesJson
            .map((json) => SignatureModel.fromMap(json as Map<String, dynamic>))
            .toList();
      });
    }
  }

  void _saveSignatures() {
    final signaturesJson = _signatures.map((s) => s.toMap()).toList();
    _storage.write('signatures', signaturesJson);
  }

  void _deleteSignature(String id) {
    setState(() {
      _signatures.removeWhere((s) => s.id == id);
    });
    _saveSignatures();
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
          'eSign',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: _signatures.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_rounded,
                    size: 80,
                    color: colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  Text(
                    'No signatures yet',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingXS),
                  Text(
                    'Tap the + button to create your first signature',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: _signatures.length,
              itemBuilder: (context, index) {
                return _buildSignatureCard(
                  _signatures[index],
                  colorScheme,
                  isDark,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await NavigationService.navigateTo(AppRoutes.esignCreate);
          // Reload signatures when returning from create screen
          if (mounted) {
            _reloadOnResume();
          }
        },
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildSignatureCard(
    SignatureModel signature,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withOpacity(0.3)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withOpacity(0.2)
              : colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Signature Preview - Full area
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surface.withOpacity(0.2)
                    : colorScheme.surfaceVariant.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: signature.isTextSignature
                  ? Center(
                      child: Text(
                        signature.textContent ?? 'Signature',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : signature.imagePath != null &&
                          File(signature.imagePath!).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(signature.imagePath!),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.edit_rounded,
                                  color: isDark 
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.3),
                                  size: 32,
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.edit_rounded,
                            color: isDark 
                                ? Colors.white.withOpacity(0.3)
                                : Colors.black.withOpacity(0.3),
                            size: 32,
                          ),
                        ),
            ),
          ),
          // Action Buttons - Minimal design
          Positioned(
            top: 8,
            left: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _downloadSignature(signature),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.download_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showDeleteDialog(signature),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(SignatureModel signature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Signature'),
        content: Text('Are you sure you want to delete "${signature.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteSignature(signature.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadSignature(SignatureModel signature) async {
    try {
      Uint8List? imageBytes;
      
      if (signature.isTextSignature) {
        // Create image bytes from text signature
        imageBytes = await _createTextSignatureImageBytes(signature);
      } else if (signature.imagePath != null && File(signature.imagePath!).existsSync()) {
        // Read image bytes from file
        final sourceFile = File(signature.imagePath!);
        imageBytes = await sourceFile.readAsBytes();
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unable to load signature image'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      // Generate filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'signature_${signature.name.replaceAll(' ', '_')}_$timestamp.png';

      // Save to gallery using saver_gallery
      final result = await SaverGallery.saveImage(
        imageBytes,
        fileName: fileName,
        quality: 100,
        skipIfExists: false,
      );

      if (mounted) {
        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Signature saved to gallery'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save signature: ${result.errorMessage ?? "Unknown error"}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving signature: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<Uint8List> _createTextSignatureImageBytes(SignatureModel signature) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final textSpan = TextSpan(
      text: signature.textContent ?? 'Signature',
      style: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        color: Colors.black,
        fontStyle: FontStyle.italic,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Draw on canvas with padding and transparent background
    const padding = 40.0;
    final width = textPainter.width + (padding * 2);
    final height = textPainter.height + (padding * 2);
    
    // Draw transparent background (or white if needed)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.transparent,
    );
    
    textPainter.paint(canvas, Offset(padding, padding));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    image.dispose();
    
    if (byteData == null) {
      throw Exception('Failed to convert signature to PNG');
    }
    
    return byteData.buffer.asUint8List();
  }
}

