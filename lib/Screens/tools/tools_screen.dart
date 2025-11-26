import 'package:flutter/material.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../scan_pdf/scan_pdf_bottom_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

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
          'All Tools',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [colorScheme.background, colorScheme.background]
                : [
                    colorScheme.background,
                    colorScheme.surfaceVariant.withOpacity(0.3),
                  ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: AppConstants.spacingL,
          ),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppConstants.spacingL,
              mainAxisSpacing: AppConstants.spacingL,
              childAspectRatio: 0.85,
            ),
            itemCount: AppConstants.allToolsList.length,
            itemBuilder: (context, index) {
              final tool = AppConstants.allToolsList[index];
              return _buildToolCard(
                context,
                tool['label'] as String,
                tool['icon'] as IconData,
                tool['color'] as Color,
                colorScheme,
                isDark,
                index,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    ColorScheme colorScheme,
    bool isDark,
    int index,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.8 + (value * 0.2), child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          if (label == 'Merge PDF') {
            _openPhotoEditor(context, colorScheme);
          } else if (label == 'Split PDF') {
            NavigationService.toSplitPDF();
          } else if (label == 'Extract Texts') {
            NavigationService.toExtractText();
          } else if (label == 'QR Reader') {
            NavigationService.toQRReader();
          } else if (label == 'QR Generate') {
            NavigationService.toQRGenerator();
          } else if (label == 'Scan PDF') {
            _showScanPDFOptions(context, colorScheme, isDark);
          } else if (label == 'eSign') {
            NavigationService.toESignList();
          } else if (label == 'Image to PDF') {
            NavigationService.toImageToPDF();
          } else if (label == 'Compress') {
            NavigationService.toCompress();
          } else if (label == 'Watermark') {
            NavigationService.toWatermark();
          }
          // Handle other tool taps
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surface.withOpacity(0.5) : Colors.white,
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
                    : color.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: AppConstants.spacingM),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingXS,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.85),
                    letterSpacing: 0.1,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScanPDFOptions(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final navigatorContext = context; // Store original context
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) => ScanPDFBottomSheet(
        onSourceSelected: (source) async {
          // Close bottom sheet first
          Navigator.of(bottomSheetContext).pop();
          
          // Small delay to ensure bottom sheet is closed
          await Future.delayed(const Duration(milliseconds: 300));
          
          final ImagePicker picker = ImagePicker();
          try {
            List<XFile> pickedFiles = [];
            
            if (source == ImageSource.camera) {
              // For camera, pick single image
              final XFile? pickedFile = await picker.pickImage(
                source: source,
                imageQuality: 85,
              );
              if (pickedFile != null) {
                pickedFiles = [pickedFile];
              }
            } else {
              // For gallery, pick multiple images
              pickedFiles = await picker.pickMultiImage(
                imageQuality: 85,
              );
            }

            if (pickedFiles.isNotEmpty) {
              final imageFiles = pickedFiles.map((f) => File(f.path)).toList();
              // Navigate to filter screen using original context
              if (navigatorContext.mounted) {
                // Use a small delay to ensure everything is ready
                await Future.delayed(const Duration(milliseconds: 100));
                NavigationService.toScanPDFFilter(imageFiles: imageFiles);
              }
            } else {
              // User cancelled - show message if context is still valid
              if (navigatorContext.mounted) {
                ScaffoldMessenger.of(navigatorContext).showSnackBar(
                  SnackBar(
                    content: const Text('No images selected'),
                    backgroundColor: colorScheme.surfaceVariant,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          } catch (e) {
            // Show error if context is still valid
            if (navigatorContext.mounted) {
              ScaffoldMessenger.of(navigatorContext).showSnackBar(
                SnackBar(
                  content: Text('Error picking images: $e'),
                  backgroundColor: colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _openPhotoEditor(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'webp'],
      );

      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No images selected'),
            backgroundColor: colorScheme.surfaceVariant,
          ),
        );
        return;
      }

      final files = result.files
          .where((file) => file.path != null)
          .map((file) => File(file.path!))
          .toList();

      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Selected files could not be read'),
            backgroundColor: colorScheme.surfaceVariant,
          ),
        );
        return;
      }

      if (files.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select at least 2 images to merge PDF'),
            backgroundColor: colorScheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      NavigationService.toPhotoEditor(imageFiles: files);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open gallery: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }
}
