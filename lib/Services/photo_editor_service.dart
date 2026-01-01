import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../Services/document_scan_serivce.dart';
import '../Services/file_storage_service.dart';
import '../Providers/home_provider.dart';
import 'package:provider/provider.dart';

class PhotoEditorService {
  static final PhotoEditorService instance = PhotoEditorService._init();
  final DocumentScanService _scanService = DocumentScanService();

  PhotoEditorService._init();

  /// Open ProImageEditor directly and save edited image using document scan service flow
  Future<void> openEditorAndSave({
    required BuildContext context,
    required File imageFile,
    String watermarkText = 'Scanify AI',
  }) async {
    try {
      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();
      final fileName = imageFile.path.split('/').last;

      // Open ProImageEditor
      final editedBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _ProImageEditorPage(
            initialBytes: imageBytes,
            watermarkText: watermarkText,
            hostTheme: Theme.of(context),
          ),
        ),
      );

      // Save edited image if user completed editing
      if (editedBytes != null && context.mounted) {
        // Save original edited image
        await _scanService.saveEditedImage(
          imageBytes: editedBytes,
          originalFileName: fileName,
        );

        // Convert edited image to PDF and save to download folder
        try {
          await _convertImageToPDFAndSave(
            imageBytes: editedBytes,
            fileName: fileName,
          );
        } catch (e) {
          print('Error converting to PDF: $e');
          // Continue even if PDF conversion fails
        }

        // Refresh home screen documents
        if (context.mounted) {
          final provider = Provider.of<HomeProvider>(context, listen: false);
          provider.loadDocuments();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Image saved and PDF created successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Open ProImageEditor for multiple images (process first one)
  Future<void> openEditorForMultipleAndSave({
    required BuildContext context,
    required List<File> imageFiles,
    String watermarkText = 'Scanify AI',
  }) async {
    if (imageFiles.isEmpty) return;

    // Process first image
    await openEditorAndSave(
      context: context,
      imageFile: imageFiles[0],
      watermarkText: watermarkText,
    );
  }

  /// Open ProImageEditor and save edited image to DocumentDetail table
  Future<void> openEditorAndSaveToDocumentDetail({
    required BuildContext context,
    required File imageFile,
    required int documentId,
    String watermarkText = 'Scanify AI',
  }) async {
    try {
      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();
      final fileName = imageFile.path.split('/').last;

      // Open ProImageEditor
      final editedBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _ProImageEditorPage(
            initialBytes: imageBytes,
            watermarkText: watermarkText,
            hostTheme: Theme.of(context),
          ),
        ),
      );

      // Save edited image if user completed editing
      if (editedBytes != null && context.mounted) {
        // Save to DocumentDetail table
        await _scanService.saveEditedImageToDocumentDetail(
          documentId: documentId,
          imageBytes: editedBytes,
          originalFileName: fileName,
        );

        // Refresh home screen documents
        if (context.mounted) {
          final provider = Provider.of<HomeProvider>(context, listen: false);
          provider.loadDocuments();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Page added successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Open ProImageEditor and update existing DocumentDetail entry
  Future<void> openEditorAndUpdateDocumentDetail({
    required BuildContext context,
    required File imageFile,
    required int documentDetailId,
    String watermarkText = 'Scanify AI',
  }) async {
    try {
      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();
      final fileName = imageFile.path.split('/').last;

      // Open ProImageEditor
      final editedBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _ProImageEditorPage(
            initialBytes: imageBytes,
            watermarkText: watermarkText,
            hostTheme: Theme.of(context),
          ),
        ),
      );

      // Update edited image if user completed editing
      if (editedBytes != null && context.mounted) {
        // Update existing DocumentDetail entry
        await _scanService.updateEditedImageInDocumentDetail(
          documentDetailId: documentDetailId,
          imageBytes: editedBytes,
          originalFileName: fileName,
        );

        // Refresh home screen documents
        if (context.mounted) {
          final provider = Provider.of<HomeProvider>(context, listen: false);
          provider.loadDocuments();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Document updated successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Convert image bytes to PDF and save to download folder and database
  Future<void> _convertImageToPDFAndSave({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      // Create PDF document using pdf package
      final pdf = pw.Document();
      
      // Create PDF image from bytes
      final pdfImage = pw.MemoryImage(imageBytes);
      
      // Get image dimensions (approximate for pdf package)
      // We'll use full page size and let it fit
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                pdfImage,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );

      // Save PDF to bytes
      final List<int> pdfBytesList = await pdf.save();
      final Uint8List pdfBytes = Uint8List.fromList(pdfBytesList);

      // Save to device Download folder (public Downloads folder)
      Directory downloadDir;
      String? savedFilePath;
      
      try {
        if (Platform.isAndroid) {
          // For Android, use the public Downloads directory
          // Try multiple common paths for public Downloads folder
          final List<String> possiblePaths = [
            '/storage/emulated/0/Download',
            '/sdcard/Download',
            '/storage/sdcard0/Download',
            '/mnt/sdcard/Download',
          ];
          
          // Try each path until one works
          bool pathFound = false;
          Directory? tempDir;
          for (final pathStr in possiblePaths) {
            try {
              tempDir = Directory(pathStr);
              // Check if directory exists or can be created
              if (await tempDir.exists()) {
                pathFound = true;
                break;
              } else {
                // Try to create it (may fail due to permissions)
                try {
                  await tempDir.create(recursive: true);
                  if (await tempDir.exists()) {
                    pathFound = true;
                    break;
                  }
                } catch (e) {
                  // Cannot create, try next path
                  continue;
                }
              }
            } catch (e) {
              // Continue to next path
              continue;
            }
          }
          
          // If no public path worked, throw error (don't use app directory)
          if (!pathFound || tempDir == null) {
            throw Exception('Cannot access device Download folder. Please check storage permissions.');
          } else {
            downloadDir = tempDir;
          }
        } else if (Platform.isIOS) {
          // For iOS, use documents directory
          final directory = await getApplicationDocumentsDirectory();
          downloadDir = Directory('${directory.path}/Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
        } else {
          // Fallback for other platforms
          final directory = await getApplicationDocumentsDirectory();
          downloadDir = Directory('${directory.path}/Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
        }

        // Generate PDF file name
        final String baseFileName = path.basenameWithoutExtension(fileName);
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final String finalFileName = '${baseFileName}_$timestamp.pdf';
        
        // Save PDF file to download folder
        final File pdfFile = File('${downloadDir.path}/$finalFileName');
        await pdfFile.writeAsBytes(pdfBytes);
        savedFilePath = pdfFile.path;
        
        // Verify file was written
        if (!await pdfFile.exists()) {
          throw Exception('File was not created successfully');
        }
        
        // On Android, refresh media scanner to make file visible
        if (Platform.isAndroid) {
          try {
            // Use platform channel to refresh media scanner
            // This ensures the file appears in Downloads app
            await _refreshMediaStore(savedFilePath);
          } catch (e) {
            // Media scanner refresh is optional, continue even if it fails
            print('Media scanner refresh failed: $e');
          }
        }

        print('PDF saved to download folder: $savedFilePath');
        
        // Save PDF to database using FileStorageService
        try {
          final fileStorageService = FileStorageService.instance;
          final docId = await fileStorageService.savePDFFile(
            pdfBytes: pdfBytes,
            fileName: finalFileName,
            title: baseFileName,
          );
          
          if (docId != null) {
            print('PDF saved to database with ID: $docId');
          } else {
            print('Warning: PDF saved to download folder but failed to save to database');
          }
        } catch (e) {
          print('Error saving PDF to database: $e');
          // Continue even if database save fails - at least it's saved to download folder
        }
        
      } catch (e) {
        print('Error saving PDF to device Download folder: $e');
        // Re-throw to be handled by caller
        rethrow;
      }
    } catch (e) {
      print('Error converting image to PDF: $e');
      rethrow;
    }
  }

  /// Refresh media store on Android to make file visible in Downloads app
  Future<void> _refreshMediaStore(String filePath) async {
    try {
      const platform = MethodChannel('com.example.utility_app/media');
      await platform.invokeMethod('refreshMediaStore', {'path': filePath});
    } catch (e) {
      print('Media scanner refresh not available: $e');
      print('File saved at: $filePath');
    }
  }
}

class _ProImageEditorPage extends StatelessWidget {
  const _ProImageEditorPage({
    required this.initialBytes,
    required this.watermarkText,
    required this.hostTheme,
  });

  final Uint8List initialBytes;
  final String watermarkText;
  final ThemeData hostTheme;

  @override
  Widget build(BuildContext context) {
    final configs = ProImageEditorConfigs(
      designMode: hostTheme.brightness == Brightness.dark
          ? ImageEditorDesignMode.cupertino
          : ImageEditorDesignMode.material,
      theme: hostTheme,
      helperLines: const HelperLineConfigs(),
      stickerEditor: StickerEditorConfigs(
        enabled: true,
        builder: (setLayer, scrollController) => _WatermarkPalette(
          watermarkText: watermarkText,
          colorScheme: hostTheme.colorScheme,
          setLayer: setLayer,
          scrollController: scrollController,
        ),
      ),
    );

    return Theme(
      data: hostTheme,
      child: ProImageEditor.memory(
        initialBytes,
        configs: configs,
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (bytes) async {
            if (context.mounted) {
              Navigator.of(context).pop(bytes);
            }
          },
          onCloseEditor: (_) {
            Navigator.of(context).maybePop();
          },
        ),
      ),
    );
  }
}

class _WatermarkPalette extends StatelessWidget {
  const _WatermarkPalette({
    required this.watermarkText,
    required this.colorScheme,
    required this.setLayer,
    required this.scrollController,
  });

  final String watermarkText;
  final ColorScheme colorScheme;
  final Function(WidgetLayer) setLayer;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final text = watermarkText.isEmpty ? 'Scanify AI' : watermarkText;
    final presets = [
      _WatermarkPreset(
        label: 'Glass capsule',
        description: 'Rounded translucent badge',
        builder: (value, scheme) => _WatermarkBadge(
          text: value,
          background: scheme.onSurface.withOpacity(0.08),
          borderColor: scheme.onSurface.withOpacity(0.4),
          textColor: scheme.onSurface,
        ),
      ),
      _WatermarkPreset(
        label: 'Ribbon',
        description: 'Gradient ribbon for headers',
        builder: (value, scheme) => _WatermarkBadge(
          text: value,
          gradient: [
            scheme.primary.withOpacity(0.95),
            scheme.secondary.withOpacity(0.95),
          ],
          borderColor: Colors.transparent,
          textColor: Colors.white,
        ),
      ),
      _WatermarkPreset(
        label: 'Minimal stamp',
        description: 'Simple uppercase watermark',
        builder: (value, scheme) => _WatermarkBadge(
          text: value.toUpperCase(),
          background: Colors.transparent,
          borderColor: scheme.onSurface.withOpacity(0.6),
          textColor: scheme.onSurface,
        ),
      ),
    ];

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: presets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final preset = presets[index];
        return Card(
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListTile(
            leading: Icon(
              Icons.water_drop_outlined,
              color: colorScheme.primary,
            ),
            title: Text(preset.label),
            subtitle: Text(
              preset.description,
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
            ),
            trailing: Icon(
              Icons.add_circle_outline,
              color: colorScheme.primary,
            ),
            onTap: () {
              setLayer(
                WidgetLayer(
                  widget: preset.builder(text, colorScheme),
                  exportConfigs: WidgetLayerExportConfigs(
                    meta: {'watermark': preset.label},
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _WatermarkPreset {
  const _WatermarkPreset({
    required this.label,
    required this.description,
    required this.builder,
  });

  final String label;
  final String description;
  final Widget Function(String text, ColorScheme scheme) builder;
}

class _WatermarkBadge extends StatelessWidget {
  const _WatermarkBadge({
    required this.text,
    required this.borderColor,
    required this.textColor,
    this.background = Colors.transparent,
    this.gradient,
  });

  final String text;
  final Color borderColor;
  final Color textColor;
  final Color background;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: gradient == null ? background : null,
        gradient: gradient != null ? LinearGradient(colors: gradient!) : null,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

