import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/file_storage_service.dart';
import '../../Services/database_helper.dart';
import '../../Providers/home_provider.dart';
import 'simple_scanner_type_screen.dart';

class SimpleScannerEditorScreen extends StatefulWidget {
  final List<File> images;
  final ScanType scanType;

  const SimpleScannerEditorScreen({
    super.key,
    required this.images,
    required this.scanType,
  });

  @override
  State<SimpleScannerEditorScreen> createState() =>
      _SimpleScannerEditorScreenState();
}

class _SimpleScannerEditorScreenState
    extends State<SimpleScannerEditorScreen> {
  late final PageController _pageController;
  final List<_EditableImage> _images = [];
  int _currentIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _images.addAll(widget.images.map(_EditableImage.new));

    if (_images.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMessage('No images to edit.');
        NavigationService.goBack();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _editImage(int index) async {
    if (index >= _images.length) return;

    final image = _images[index];
    final sourceBytes = await image.file.readAsBytes();
    final hostTheme = Theme.of(context);

    final editedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Theme(
          data: hostTheme,
          child: ProImageEditor.memory(
            sourceBytes,
            configs: ProImageEditorConfigs(
              heroTag: 'image_$index',
            ),
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
        ),
      ),
    );

    if (editedBytes != null) {
      setState(() {
        image.editedBytes = editedBytes;
        image.isEdited = true;
      });
    }
  }

  Future<void> _addImage() async {
    // Navigate back to camera or gallery picker
    await NavigationService.toSimpleScannerCamera(
      scanType: widget.scanType,
    );
  }

  void _removeImage(int index) {
    if (_images.length <= 1) {
      _showMessage('At least one image is required.');
      return;
    }

    setState(() {
      _images.removeAt(index);
      if (_currentIndex >= _images.length) {
        _currentIndex = _images.length - 1;
      }
      _pageController.jumpToPage(_currentIndex);
    });
  }

  void _reorderImage(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    setState(() {
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
      _currentIndex = newIndex;
      _pageController.jumpToPage(_currentIndex);
    });
  }

  Future<void> _saveImages() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final fileStorageService = FileStorageService.instance;
      int savedCount = 0;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < _images.length; i++) {
        final image = _images[i];
        final bytes = image.editedBytes ?? await image.file.readAsBytes();
        final fileName = 'scan_${widget.scanType.name}_${timestamp}_${i + 1}.jpg';
        
        final docId = await fileStorageService.saveImageFile(
          imageBytes: bytes,
          fileName: fileName,
          title: 'Scan_${widget.scanType.name}_${i + 1}',
        );

        if (docId != null) {
          savedCount++;
        }
      }

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        // Refresh home screen documents
        final provider = Provider.of<HomeProvider>(context, listen: false);
        provider.loadDocuments();
        
        _showSaveDialog(savedCount, isPDF: false);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      _showMessage('Error saving images: $e');
    }
  }

  Future<void> _exportAsPDF() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final PdfDocument document = PdfDocument();

      for (final image in _images) {
        final bytes = image.editedBytes ?? await image.file.readAsBytes();
        final page = document.pages.add();
        final pageSize = page.size;
        
        // Calculate image size to fit page
        final img.Image? decodedImage = img.decodeImage(bytes);
        if (decodedImage != null) {
          final imageWidth = decodedImage.width.toDouble();
          final imageHeight = decodedImage.height.toDouble();
          final pageWidth = pageSize.width - 40; // margins
          final pageHeight = pageSize.height - 40;
          
          double width = imageWidth;
          double height = imageHeight;
          
          // Scale to fit page
          if (width > pageWidth || height > pageHeight) {
            final scale = (pageWidth / width).clamp(0.0, pageHeight / height);
            width = imageWidth * scale;
            height = imageHeight * scale;
          }
          
          final x = (pageSize.width - width) / 2;
          final y = (pageSize.height - height) / 2;
          
          page.graphics.drawImage(
            PdfBitmap(bytes),
            Rect.fromLTWH(x, y, width, height),
          );
        }
      }

      final pdfBytesList = await document.save();
      document.dispose();
      final pdfBytes = Uint8List.fromList(pdfBytesList);

      // Save PDF using file storage service
      final fileStorageService = FileStorageService.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final docId = await fileStorageService.savePDFFile(
        pdfBytes: pdfBytes,
        fileName: 'scan_${widget.scanType.name}_$timestamp.pdf',
        title: 'Scan_${widget.scanType.name}_PDF',
      );
      
      // Get the saved file path from database
      String? pdfPath;
      if (docId != null) {
        final savedDoc = await DatabaseHelper.instance.getDocumentById(docId);
        pdfPath = savedDoc?.imagePath;
        
        // Refresh home screen documents
        if (mounted) {
          final provider = Provider.of<HomeProvider>(context, listen: false);
          provider.loadDocuments();
        }
      }

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        _showSaveDialog(1, isPDF: true, pdfPath: pdfPath);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      _showMessage('Error creating PDF: $e');
    }
  }

  void _showSaveDialog(int count, {bool isPDF = false, String? pdfPath}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved Successfully'),
        content: Text(
          isPDF
              ? 'PDF saved successfully.'
              : '$count image(s) saved successfully.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (isPDF && pdfPath != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Share.shareXFiles([XFile(pdfPath)]);
              },
              child: const Text('Share'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_images.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('No Images'),
        ),
        body: const Center(child: Text('No images to edit')),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colorScheme.onSurface,
          ),
          onPressed: () => NavigationService.goBack(),
        ),
        title: Column(
          children: [
            Text(
              'Edit Scan',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_currentIndex + 1} of ${_images.length}',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_images.length > 1)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurface),
              onSelected: (value) {
                if (value == 'reorder') {
                  _showReorderDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reorder',
                  child: Row(
                    children: [
                      Icon(Icons.swap_vert_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Reorder Pages'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Image Viewer
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final image = _images[index];
                return GestureDetector(
                  onTap: () => _editImage(index),
                  child: Container(
                    margin: const EdgeInsets.all(AppConstants.spacingM),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: image.editedBytes != null
                          ? Image.memory(
                              image.editedBytes!,
                              fit: BoxFit.contain,
                            )
                          : Image.file(
                              image.file,
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Controls
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thumbnail strip
                if (_images.length > 1)
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        final image = _images[index];
                        final isSelected = index == _currentIndex;
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: image.editedBytes != null
                                  ? Image.memory(
                                      image.editedBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      image.file,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: AppConstants.spacingM),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Edit button
                    _buildActionButton(
                      context,
                      icon: Icons.edit_rounded,
                      label: 'Edit',
                      onTap: () => _editImage(_currentIndex),
                      colorScheme: colorScheme,
                    ),

                    // Add button
                    _buildActionButton(
                      context,
                      icon: Icons.add_rounded,
                      label: 'Add',
                      onTap: _addImage,
                      colorScheme: colorScheme,
                    ),

                    // Remove button
                    if (_images.length > 1)
                      _buildActionButton(
                        context,
                        icon: Icons.delete_rounded,
                        label: 'Remove',
                        onTap: () => _removeImage(_currentIndex),
                        colorScheme: colorScheme,
                        isDestructive: true,
                      ),

                    // Save button
                    _buildActionButton(
                      context,
                      icon: Icons.save_rounded,
                      label: 'Save',
                      onTap: _saveImages,
                      colorScheme: colorScheme,
                      isLoading: _isSaving,
                    ),

                    // Export PDF button
                    _buildActionButton(
                      context,
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'PDF',
                      onTap: _exportAsPDF,
                      colorScheme: colorScheme,
                      isLoading: _isSaving,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    bool isDestructive = false,
    bool isLoading = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDestructive
                          ? Colors.red
                          : colorScheme.primary,
                    ),
                  ),
                )
              else
                Icon(
                  icon,
                  color: isDestructive
                      ? Colors.red
                      : colorScheme.primary,
                  size: 24,
                ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isDestructive
                      ? Colors.red
                      : colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReorderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reorder Pages'),
        content: SizedBox(
          width: double.maxFinite,
          child: ReorderableListView(
            shrinkWrap: true,
            onReorder: _reorderImage,
            children: _images.asMap().entries.map((entry) {
              final index = entry.key;
              final image = entry.value;
              return ListTile(
                key: ValueKey(index),
                leading: Icon(Icons.drag_handle_rounded),
                title: Text('Page ${index + 1}'),
                trailing: image.isEdited
                    ? Icon(Icons.check_circle_rounded, color: Colors.green)
                    : null,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _EditableImage {
  final File file;
  Uint8List? editedBytes;
  bool isEdited;

  _EditableImage(this.file) : isEdited = false;
}

