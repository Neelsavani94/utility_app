import 'package:flutter/material.dart';

class AppConstants {
  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 40.0;

  // Border Radius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;
  static const double radiusRound = 999.0;

  // Icon Sizes
  static const double iconXS = 16.0;
  static const double iconS = 20.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 48.0;

  // Tool Colors - Vibrant & Bold palette
  static const List<Color> toolColors = [
    Color(0xFFFF5722), // Vibrant Orange - Merge PDF
    Color(0xFFE91E63), // Vibrant Pink - Split PDF
    Color(0xFF00E676), // Vibrant Green - eSign
    Color(0xFF9C27B0), // Vibrant Purple - Watermark
    Color(0xFF6C5CE7), // Purple-Indigo - All Tools (matches theme)
  ];

  // Tool Icons
  static const List<IconData> toolIcons = [
    Icons.merge_type_rounded,
    Icons.content_cut_rounded,
    Icons.edit_rounded,
    Icons.water_drop_rounded,
    Icons.apps_rounded,
  ];

  // Tool Labels
  static const List<String> toolLabels = [
    'Merge PDF',
    'Split PDF',
    'eSign',
    'Watermark',
    'All Tools',
  ];

  // Document Categories
  static const List<String> documentCategories = [
    'All Docs',
    'Business Card',
    'ID Card',
    'Academic',
    'Personal',
  ];

  // Category Icons (Tag Symbols)
  static const List<IconData> categoryIcons = [
    Icons.label_rounded, // All Docs
    Icons.local_offer_rounded, // Business Card
    Icons.label_outline_rounded, // ID Card
    Icons.bookmark_rounded, // Academic
    Icons.local_offer_outlined, // Personal
  ];

  // Bottom Nav Items
  static const List<Map<String, dynamic>> bottomNavItems = [
    {'icon': Icons.home_rounded, 'label': 'Home'},
    {'icon': Icons.qr_code_scanner_rounded, 'label': 'QR Scan'},
    {'icon': Icons.camera_alt_rounded, 'label': 'Camera'},
    {'icon': Icons.document_scanner_rounded, 'label': 'OCR Scan'},
    {'icon': Icons.settings, 'label': 'Setting'},
  ];

  // All Tools List for Tools Screen
  static const List<Map<String, dynamic>> allToolsList = [
    {
      'label': 'Merge PDF',
      'icon': Icons.merge_type_rounded,
      'color': Color(0xFFFF5722), // Vibrant Orange
    },
    {
      'label': 'Split PDF',
      'icon': Icons.content_cut_rounded,
      'color': Color(0xFFE91E63), // Vibrant Pink
    },
    {
      'label': 'eSign',
      'icon': Icons.edit_rounded,
      'color': Color(0xFF003C1E), // Vibrant Green
    },
    {
      'label': 'Watermark',
      'icon': Icons.water_drop_rounded,
      'color': Color(0xFF9C27B0), // Vibrant Purple
    },
    {
      'label': 'Compress',
      'icon': Icons.archive_rounded,
      'color': Color(0xFFFF9800), // Orange
    },
    {
      'label': 'Image to PDF',
      'icon': Icons.image_rounded,
      'color': Color(0xFFFF5722), // Orange
    },
    {
      'label': 'Scan PDF',
      'icon': Icons.document_scanner_rounded,
      'color': Color(0xFF03A9F4), // Light Blue
    },
    {
      'label': 'QR Generate',
      'icon': Icons.qr_code_rounded,
      'color': Color(0xFF6C5CE7), // Purple-Indigo (theme)
    },
    {
      'label': 'QR Reader',
      'icon': Icons.qr_code_scanner_rounded,
      'color': Color(0xFF003C3A), // Green
    },
    {
      'label': 'Extract Texts',
      'icon': Icons.text_fields_rounded,
      'color': Color(0xFF03A5C4), // Light Blue
    },
  ];
}
