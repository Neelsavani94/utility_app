import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
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
          'My Signatures',
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
              padding: const EdgeInsets.all(AppConstants.spacingM),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppConstants.spacingM,
                mainAxisSpacing: AppConstants.spacingM,
                childAspectRatio: 0.85,
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
                : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Signature Preview
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: signature.isTextSignature
                        ? Center(
                            child: Text(
                              signature.textContent ?? 'Signature',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : signature.imagePath != null &&
                                File(signature.imagePath!).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(signature.imagePath!),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.edit_rounded,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.3),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.edit_rounded,
                                  color:
                                      colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  signature.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDate(signature.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          // Action Buttons
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.download_rounded,
                      size: 18,
                      color: colorScheme.onSurface,
                    ),
                    onPressed: () {
                      _downloadSignature(signature);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      _showDeleteDialog(signature);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
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
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/Download/Scanify AI/ESign');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      String? imagePath;
      
      if (signature.isTextSignature) {
        // Create image from text signature
        imagePath = await _createTextSignatureImage(signature, downloadsDir.path);
      } else if (signature.imagePath != null && File(signature.imagePath!).existsSync()) {
        // Copy existing image
        final sourceFile = File(signature.imagePath!);
        final fileName = '${signature.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
        final destFile = File('${downloadsDir.path}/$fileName');
        await sourceFile.copy(destFile.path);
        imagePath = destFile.path;
      }

      if (imagePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signature saved to Downloads/Scanify AI/ESign'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading signature: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<String> _createTextSignatureImage(SignatureModel signature, String dirPath) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final textSpan = TextSpan(
      text: signature.textContent ?? 'Signature',
      style: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
        fontStyle: FontStyle.italic,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Draw on canvas with padding
    const padding = 40.0;
    final width = textPainter.width + (padding * 2);
    final height = textPainter.height + (padding * 2);
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );
    
    textPainter.paint(canvas, Offset(padding, padding));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final fileName = '${signature.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('$dirPath/$fileName');
    await file.writeAsBytes(bytes);
    
    return file.path;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

