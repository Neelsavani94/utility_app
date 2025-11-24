import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import 'scan_pdf_bottom_sheet.dart';

class ScanPDFScreen extends StatefulWidget {
  const ScanPDFScreen({super.key});

  @override
  State<ScanPDFScreen> createState() => _ScanPDFScreenState();
}

class _ScanPDFScreenState extends State<ScanPDFScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  List<File> _selectedImages = [];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: _selectedImages.isEmpty
          ? _buildEmptyState(colorScheme, isDark)
          : _buildImagePreview(colorScheme, isDark),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.document_scanner_rounded,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: AppConstants.spacingL),
          Text(
            'No images selected',
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

  Widget _buildImagePreview(ColorScheme colorScheme, bool isDark) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.all(AppConstants.spacingM),
                child: Image.file(
                  _selectedImages[index],
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickMoreImages,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Add More'),
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    NavigationService.toScanPDFFilter(
                      imageFiles: _selectedImages,
                    );
                  },
                  icon: const Icon(Icons.filter_alt_rounded),
                  label: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _pickMoreImages() {
    _showSourceSelection();
  }

  void _showSourceSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ScanPDFBottomSheet(
        onSourceSelected: _pickImages,
      ),
    );
  }

  Future<void> _pickImages(ImageSource source) async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(
            pickedFiles.map((file) => File(file.path)).toList(),
          );
        });
      }
    } catch (e) {
      _showError('Error picking images: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

