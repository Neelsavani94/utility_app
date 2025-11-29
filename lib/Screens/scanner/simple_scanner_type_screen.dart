import 'package:flutter/material.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';

enum ScanType {
  document,
  book,
  ocr,
  idCard,
  photo,
}

class SimpleScannerTypeScreen extends StatelessWidget {
  const SimpleScannerTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : colorScheme.background,
      appBar: AppBar(
        backgroundColor: isDark
            ? colorScheme.surface.withOpacity(0.3)
            : colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colorScheme.onSurface,
          ),
          onPressed: () => NavigationService.goBack(),
        ),
        title: Text(
          'Select Scan Type',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose the type of scan you want to perform',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXL),
              _buildScanTypeCard(
                context,
                scanType: ScanType.document,
                icon: Icons.description_rounded,
                title: 'Document',
                description: 'Scan documents, papers, and forms',
                color: const Color(0xFF2196F3),
                colorScheme: colorScheme,
                isDark: isDark,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildScanTypeCard(
                context,
                scanType: ScanType.book,
                icon: Icons.menu_book_rounded,
                title: 'Book',
                description: 'Scan book pages with page frame',
                color: const Color(0xFF9C27B0),
                colorScheme: colorScheme,
                isDark: isDark,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildScanTypeCard(
                context,
                scanType: ScanType.ocr,
                icon: Icons.text_fields_rounded,
                title: 'OCR',
                description: 'Extract text from images',
                color: const Color(0xFF00BCD4),
                colorScheme: colorScheme,
                isDark: isDark,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildScanTypeCard(
                context,
                scanType: ScanType.idCard,
                icon: Icons.badge_rounded,
                title: 'ID Card',
                description: 'Scan ID cards and licenses',
                color: const Color(0xFFFF9800),
                colorScheme: colorScheme,
                isDark: isDark,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildScanTypeCard(
                context,
                scanType: ScanType.photo,
                icon: Icons.photo_camera_rounded,
                title: 'Photo',
                description: 'Capture photos in normal mode',
                color: const Color(0xFF4CAF50),
                colorScheme: colorScheme,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanTypeCard(
    BuildContext context, {
    required ScanType scanType,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        NavigationService.toSimpleScannerCamera(scanType: scanType);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surface.withOpacity(0.5)
              : colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

