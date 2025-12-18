import 'package:flutter/material.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/photo_editor_service.dart';
import '../../Services/document_scan_serivce.dart';
import '../../Providers/home_provider.dart';
import 'package:provider/provider.dart';
import '../scan_pdf/scan_pdf_bottom_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_pdf;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

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
            NavigationService.toImportFiles(forExtractText: true);
          } else if (label == 'QR Reader') {
            _handleQRScan(context, colorScheme);
          } else if (label == 'QR Generate') {
            NavigationService.toQRGenerator();
          } else if (label == 'Scan PDF') {
            _showScanPDFOptions(context, colorScheme, isDark);
          } else if (label == 'eSign') {
            NavigationService.toESignList();
          } else if (label == 'Compress') {
            _handleCompress(context, colorScheme);
          } else if (label == 'Watermark') {
            NavigationService.toImportFiles(forWatermark: true);
          } else if (label == 'Import') {
            NavigationService.toImportFiles();
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

      // Open ProImageEditor directly for first image
      final photoEditorService = PhotoEditorService.instance;
      await photoEditorService.openEditorForMultipleAndSave(
        context: context,
        imageFiles: files,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open gallery: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleFileImport(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    try {
      // Use FilePicker for files
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'webp', 'pdf'],
      );

      if (result == null || result.files.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No files selected'),
              backgroundColor: colorScheme.surfaceVariant,
            ),
          );
        }
        return;
      }

      final imageFiles = result.files
          .where((file) => file.path != null)
          .map((file) => File(file.path!))
          .toList();

      if (imageFiles.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Selected files could not be read'),
              backgroundColor: colorScheme.surfaceVariant,
            ),
          );
        }
        return;
      }

      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Importing ${imageFiles.length} file(s)...',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Import and save using document scan service
      final scanService = DocumentScanService();
      await scanService.importAndSaveImages(imageFiles: imageFiles);

      // Refresh home screen documents
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        final provider = Provider.of<HomeProvider>(context, listen: false);
        provider.loadDocuments();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${imageFiles.length} file(s) imported successfully'),
            backgroundColor: colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing files: $e'),
            backgroundColor: colorScheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Handle Compress - Direct PDF file pick and compress
  Future<void> _handleCompress(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    try {
      // Pick PDF files only
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No files selected'),
              backgroundColor: colorScheme.surfaceVariant,
            ),
          );
        }
        return;
      }

      final files = result.files
          .where((file) => file.path != null)
          .map((file) => File(file.path!))
          .toList();

      if (files.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Selected files could not be read'),
              backgroundColor: colorScheme.surfaceVariant,
            ),
          );
        }
        return;
      }

      // Navigate to full screen progress
      if (!context.mounted) return;
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _CompressProgressScreen(
            files: files,
            colorScheme: colorScheme,
          ),
        ),
      );
      
      // Refresh home screen documents after returning
      if (context.mounted) {
        final provider = Provider.of<HomeProvider>(context, listen: false);
        provider.loadDocuments();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Handle QR Scan - Open scanner directly
  Future<void> _handleQRScan(BuildContext context, ColorScheme colorScheme) async {
    try {
      final String? result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SimpleBarcodeScannerPage(),
        ),
      );

      if (result != null && result.isNotEmpty && context.mounted && result.toString() != '-1') {
        // Determine if it's a QR code or barcode
        final isQRCode = result.startsWith('http://') || 
                        result.startsWith('https://') ||
                        result.startsWith('www.') ||
                        result.contains('://');

        final scannedType = isQRCode ? 'qrCode' : 'barcode';
        _showQRResultPopup(context, result, scannedType, colorScheme);
      }
    } catch (e) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error scanning: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  // Show QR Scan Result Popup
  void _showQRResultPopup(
    BuildContext context,
    String scannedText,
    String scannedType,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppConstants.spacingM),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          scannedType == 'qrCode' ? 'QR Code' : 'Barcode',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colorScheme.onSurface,
                          size: 24,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Scanned Text
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingM,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.spacingM),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.surface.withOpacity(0.5)
                          : colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      scannedText,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.onSurface,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingM),
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final searchQuery = Uri.encodeComponent(scannedText);
                            final searchUrl = Uri.parse('https://www.google.com/search?q=$searchQuery');
                            try {
                              await launchUrl(
                                searchUrl,
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (e) {
                              Fluttertoast.showToast(
                                msg: 'Could not open browser',
                                toastLength: Toast.LENGTH_SHORT,
                              );
                            }
                          },
                          icon: const Icon(Icons.search_rounded, size: 20),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppConstants.spacingM,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingM),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await Share.share(scannedText);
                            } catch (e) {
                              Fluttertoast.showToast(
                                msg: 'Error sharing: $e',
                                toastLength: Toast.LENGTH_SHORT,
                              );
                            }
                          },
                          icon: const Icon(Icons.share_rounded, size: 20),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppConstants.spacingM,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImportBottomSheet extends StatelessWidget {
  final ColorScheme colorScheme;
  final Function() onFileImport;

  const _ImportBottomSheet({
    required this.colorScheme,
    required this.onFileImport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withOpacity(0.98)
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Import From',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              _buildImportOption(
                context,
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: colorScheme.primary,
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 12),
              _buildImportOption(
                context,
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: colorScheme.secondary,
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 12),
              _buildImportOption(
                context,
                icon: Icons.folder_rounded,
                label: 'Files',
                color: colorScheme.tertiary,
                onTap: onFileImport,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.5)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Full screen compression progress widget
class _CompressProgressScreen extends StatefulWidget {
  final List<File> files;
  final ColorScheme colorScheme;

  const _CompressProgressScreen({
    required this.files,
    required this.colorScheme,
  });

  @override
  State<_CompressProgressScreen> createState() => _CompressProgressScreenState();
}

class _CompressProgressScreenState extends State<_CompressProgressScreen> {
  double _progress = 0.0;
  String _currentFileName = '';
  int _currentFileIndex = 0;
  int _totalFiles = 0;
  bool _isComplete = false;
  int _successCount = 0;
  int _failureCount = 0;

  @override
  void initState() {
    super.initState();
    _totalFiles = widget.files.length;
    _startCompression();
  }

  Future<void> _startCompression() async {
    final List<File> savedFiles = [];

    for (int i = 0; i < widget.files.length; i++) {
      if (!mounted) break;

      final file = widget.files[i];
      
      // Update UI at start of file processing
      setState(() {
        _currentFileIndex = i + 1;
        _currentFileName = file.path.split('/').last;
        _progress = i / widget.files.length; // Start of this file
      });

      try {
        if (!await file.exists()) {
          _failureCount++;
          // Update progress even on failure
          setState(() {
            _progress = (i + 1) / widget.files.length;
          });
          continue;
        }

        final fileName = file.path.split('/').last;
        final fileNameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
        
        // Update progress: 10% into current file (reading)
        setState(() {
          _progress = (i + 0.1) / widget.files.length;
        });
        
        final pdfBytes = await file.readAsBytes();
        
        // Update progress: 30% into current file (loading PDF)
        setState(() {
          _progress = (i + 0.3) / widget.files.length;
        });
        
        final pdfDocument = syncfusion_pdf.PdfDocument(inputBytes: pdfBytes);

        // Update progress: 50% into current file (optimizing)
        setState(() {
          _progress = (i + 0.5) / widget.files.length;
        });
        
        // Optimize PDF
        final optimizedBytes = await pdfDocument.save();
        pdfDocument.dispose();

        // Update progress: 70% into current file (processing bytes)
        setState(() {
          _progress = (i + 0.7) / widget.files.length;
        });

        // Use optimized if smaller, otherwise use original
        final compressedBytes = optimizedBytes.length < pdfBytes.length
            ? Uint8List.fromList(optimizedBytes)
            : pdfBytes;

        // Update progress: 80% into current file (saving)
        setState(() {
          _progress = (i + 0.8) / widget.files.length;
        });

        // Save to Download folder
        final directory = await getApplicationDocumentsDirectory();
        final downloadDir = Directory('${directory.path}/Download/Compressed');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }

        final compressedFileName = '${fileNameWithoutExt}_compressed.pdf';
        final compressedFile = File('${downloadDir.path}/$compressedFileName');
        await compressedFile.writeAsBytes(compressedBytes);

        // Update progress: 100% of current file completed
        setState(() {
          _progress = (i + 1) / widget.files.length;
        });

        if (await compressedFile.exists()) {
          savedFiles.add(compressedFile);
          _successCount++;
        } else {
          _failureCount++;
        }
      } catch (e) {
        _failureCount++;
        print('Error compressing file ${file.path}: $e');
        // Update progress even on error
        setState(() {
          _progress = (i + 1) / widget.files.length;
        });
      }
      
      // Small delay to ensure UI updates are visible
      await Future.delayed(const Duration(milliseconds: 50));
    }

    setState(() {
      _progress = 1.0;
      _isComplete = true;
    });

    // Show completion message
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _successCount > 0
                  ? '$_successCount PDF(s) compressed and saved to Download folder'
                  : 'Compression completed with errors',
            ),
            backgroundColor: _successCount > 0
                ? widget.colorScheme.primary
                : widget.colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
        // Auto close after 2 seconds
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingXL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Progress indicator
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 12,
                          backgroundColor: colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ),
                      // Percentage text
                      Text(
                        '${(_progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXL),
                // Status text
                Text(
                  _isComplete ? 'Compression Complete!' : 'Compressing PDFs...',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingM),
                // File info
                if (_currentFileName.isNotEmpty) ...[
                  Text(
                    _currentFileName,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                ],
                // Progress text
                Text(
                  'File $_currentFileIndex of $_totalFiles',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXL),
                // Results
                if (_isComplete) ...[
                  Container(
                    padding: const EdgeInsets.all(AppConstants.spacingM),
                    decoration: BoxDecoration(
                      color: _successCount > 0
                          ? colorScheme.primary.withOpacity(0.1)
                          : colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _successCount > 0 ? Icons.check_circle : Icons.error,
                          color: _successCount > 0
                              ? colorScheme.primary
                              : colorScheme.error,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          '$_successCount successful, $_failureCount failed',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _successCount > 0
                                ? colorScheme.primary
                                : colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
