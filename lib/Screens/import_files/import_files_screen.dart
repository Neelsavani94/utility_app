import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../Constants/app_constants.dart';
import '../../Providers/home_provider.dart';
import '../../Routes/navigation_service.dart';
import '../../Models/document_model.dart';
import '../../Services/document_scan_serivce.dart';
import '../home/document_detail_screen.dart';
import '../extract_text/extract_text_screen.dart';
import '../../modules/watermark/watermark_screen.dart';

class ImportFilesScreen extends StatefulWidget {
  final bool forExtractText;
  final bool forWatermark;
  
  const ImportFilesScreen({
    super.key,
    this.forExtractText = false,
    this.forWatermark = false,
  });

  @override
  State<ImportFilesScreen> createState() => _ImportFilesScreenState();
}

class _ImportFilesScreenState extends State<ImportFilesScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final DocumentScanService _scanService = DocumentScanService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().loadDocuments();
    });
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colorScheme.onSurface,
          ),
          onPressed: () => NavigationService.goBack(),
        ),
        title: Text(
          widget.forExtractText
              ? 'Select Document'
              : widget.forWatermark
                  ? 'Select Document'
                  : 'Import Files',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Consumer<HomeProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Three main action buttons (only show if not in Extract Text or Watermark mode)
                if (!widget.forExtractText && !widget.forWatermark) ...[
                  _buildActionButtons(context, colorScheme, isDark),
                  const SizedBox(height: 24),
                ],
                // Documents list
                _buildDocumentsList(context, provider, colorScheme, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          context,
          icon: Icons.folder_rounded,
          label: 'File Manager',
          color: const Color(0xFFFF9800), // Orange
          onTap: () => _handleFileManager(context, colorScheme),
          colorScheme: colorScheme,
          isDark: isDark,
        ),
        _buildActionButton(
          context,
          icon: Icons.image_rounded,
          label: 'Images',
          color: const Color(0xFF2196F3), // Blue
          onTap: () => _handleImages(context, colorScheme),
          colorScheme: colorScheme,
          isDark: isDark,
        ),
        _buildActionButton(
          context,
          icon: Icons.insert_drive_file_rounded,
          label: 'Files',
          color: const Color(0xFF2196F3), // Blue
          onTap: () => _handleFiles(context, colorScheme),
          colorScheme: colorScheme,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isDark 
                ? colorScheme.surface.withOpacity(0.3) 
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentsList(
    BuildContext context,
    HomeProvider provider,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    if (provider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppConstants.spacingXL),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final documents = provider.filteredDocuments;

    if (documents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 48,
                color: colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No documents yet',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Docs',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: documents.length,
          separatorBuilder: (context, index) => const SizedBox(height: 1),
          itemBuilder: (context, index) {
            final document = documents[index];
            return _buildDocumentCard(context, document, provider, colorScheme, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    DocumentModel document,
    HomeProvider provider,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () async {
        if (widget.forExtractText) {
          // Open Extract Text screen with document's image path
          final imagePath = document.imagePath ?? document.thumbnailPath;
          if (imagePath != null && imagePath.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExtractTextScreen(imagePath: imagePath),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Document image not available'),
                backgroundColor: colorScheme.error,
              ),
            );
          }
        } else if (widget.forWatermark) {
          // Open Watermark screen with document's image path
          final imagePath = document.imagePath ?? document.thumbnailPath;
          if (imagePath != null && imagePath.isNotEmpty) {
            // Verify file exists before navigating
            final file = File(imagePath);
            if (await file.exists()) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WatermarkScreen(initialFilePath: imagePath),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'File not found: ${imagePath.split('/').last}',
                  ),
                  backgroundColor: colorScheme.error,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Document image not available'),
                backgroundColor: colorScheme.error,
              ),
            );
          }
        } else {
          // Open document detail screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocumentDetailScreen(
                document: Document(
                  title: document.name,
                  type: document.category,
                  imagePath: document.imagePath ?? "",
                  thumbnailPath: document.thumbnailPath,
                  id: int.parse(document.id),
                  isFavourite: document.isFavorite,
                  isDeleted: document.isDeleted,
                  createdAt: document.createdAt,
                  deletedAt: document.deletedAt,
                ),
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark 
              ? colorScheme.surface.withOpacity(0.3) 
              : colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outline.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            _buildDocumentThumbnail(document, colorScheme, 48, isDark),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    document.name,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    document.formattedDate,
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // All Docs button (only show if not in Extract Text or Watermark mode)
            if (!widget.forExtractText && !widget.forWatermark)
              TextButton(
                onPressed: () => NavigationService.goBack(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'All Docs',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentThumbnail(
    DocumentModel document,
    ColorScheme colorScheme,
    double size,
    bool isDark,
  ) {
    final thumbnailPath = document.thumbnailPath;

    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      final thumbnailFile = File(thumbnailPath);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: colorScheme.surfaceVariant.withOpacity(0.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            thumbnailFile,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: colorScheme.surfaceVariant.withOpacity(0.2),
                child: Icon(
                  Icons.description_rounded,
                  color: colorScheme.onSurface.withOpacity(0.3),
                  size: size * 0.4,
                ),
              );
            },
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.description_rounded,
        color: colorScheme.onSurface.withOpacity(0.3),
        size: size * 0.4,
      ),
    );
  }

  Future<void> _handleFileManager(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    // Open file manager - similar to file import
    await _handleFileImport(context, colorScheme);
  }

  Future<void> _handleImages(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) {
        return;
      }

      final imageFiles = pickedFiles.map((f) => File(f.path)).toList();
      await _importFiles(context, colorScheme, imageFiles);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleFiles(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    await _handleFileImport(context, colorScheme);
  }

  Future<void> _handleFileImport(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'webp', 'pdf'],
      );

      if (result == null || result.files.isEmpty) {
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

      await _importFiles(context, colorScheme, files);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _importFiles(
    BuildContext context,
    ColorScheme colorScheme,
    List<File> files,
  ) async {
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Importing ${files.length} file(s)...',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      await _scanService.importAndSaveImages(imageFiles: files);

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        final provider = Provider.of<HomeProvider>(context, listen: false);
        provider.loadDocuments();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${files.length} file(s) imported successfully'),
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
}

