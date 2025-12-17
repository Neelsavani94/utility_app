import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:share_plus/share_plus.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';

class ExtractTextScreen extends StatefulWidget {
  final String? imagePath;
  
  const ExtractTextScreen({
    super.key,
    this.imagePath,
  });

  @override
  State<ExtractTextScreen> createState() => _ExtractTextScreenState();
}

class _ExtractTextScreenState extends State<ExtractTextScreen> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  File? _selectedImage;
  String _extractedText = '';
  bool _isProcessing = false;
  bool _hasExtractedText = false;

  @override
  void initState() {
    super.initState();
    if (widget.imagePath != null) {
      _selectedImage = File(widget.imagePath!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processImage();
      });
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _extractedText = '';
          _hasExtractedText = false;
        });
        _processImage();
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _extractedText = '';
      _hasExtractedText = false;
    });

    try {
      final inputImage = InputImage.fromFilePath(_selectedImage!.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      setState(() {
        _extractedText = recognizedText.text;
        _hasExtractedText = _extractedText.isNotEmpty;
        _isProcessing = false;
      });

      if (_extractedText.isEmpty) {
        _showError('No text found in image');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Error processing image: $e');
    }
  }

  void _copyText() {
    if (_extractedText.isEmpty) return;
    
    Clipboard.setData(ClipboardData(text: _extractedText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Text copied to clipboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareText() async {
    if (_extractedText.isEmpty) return;
    
    try {
      await Share.share(_extractedText);
    } catch (e) {
      _showError('Error sharing: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
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
          'OCR Scanner',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
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
                Icons.refresh_rounded,
                color: colorScheme.onSurface,
                size: 20,
              ),
              onPressed: _selectedImage != null ? _processImage : null,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Image Preview Section
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
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 64,
                            color: colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: AppConstants.spacingM),
                          Text(
                            'No image selected',
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacingS),
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.image_rounded),
                            label: const Text('Pick Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spacingL,
                                vertical: AppConstants.spacingM,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Extracted Text Section
          Expanded(
            flex: 4,
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
                  // Header with Scanify AI and Action Buttons
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
                      if (_hasExtractedText)
                        Row(
                          children: [
                            // Share Button
                            IconButton(
                              icon: Icon(
                                Icons.share_rounded,
                                color: colorScheme.onSurface,
                                size: 24,
                              ),
                              onPressed: _shareText,
                            ),
                            // Copy Button
                            IconButton(
                              icon: Icon(
                                Icons.copy_rounded,
                                color: colorScheme.onSurface,
                                size: 24,
                              ),
                              onPressed: _copyText,
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingS),

                  // Extracted Text Display
                  Expanded(
                    child: _isProcessing
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _hasExtractedText
                            ? SingleChildScrollView(
                                child: Text(
                                  _extractedText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurface,
                                    height: 1.5,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  _selectedImage == null
                                      ? 'Select an image to extract text'
                                      : 'No text found in image',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.5),
                                    fontSize: 14,
                                  ),
                                ),
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

