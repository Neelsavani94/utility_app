import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/file_storage_service.dart';
import '../../Providers/home_provider.dart';
import 'package:provider/provider.dart';

class PhotoEditorScreen extends StatefulWidget {
  final List<File> imageFiles;

  const PhotoEditorScreen({super.key, required this.imageFiles});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  late final PageController _pageController;
  final TextEditingController _watermarkController = TextEditingController(
    text: 'Scanify AI',
  );
  final List<_EditableImage> _images = [];

  int _currentIndex = 0;
  bool _isEditorOpen = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _watermarkController.addListener(() => setState(() {}));
    _images.addAll(widget.imageFiles.map(_EditableImage.new));

    if (_images.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMessage('Please pick at least one image to continue.');
        NavigationService.goBack();
      });
    } else {
      // Open editor directly for the first image
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          setState(() {
            _isEditorOpen = true;
          });
          await _openEditorDirectly(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _watermarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // If editor is open or images are empty, show loading/empty state
    if (_isEditorOpen || _images.isEmpty) {
      return Scaffold(
        backgroundColor: colorScheme.background,
        body: _images.isEmpty
            ? _buildEmptyState(colorScheme)
            : const Center(
                child: CircularProgressIndicator(),
              ),
      );
    }

    // Show preview screen only if editor is not open
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
                : colorScheme.surface.withOpacity(0.65),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () => NavigationService.goBack(),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Column(
          children: [
            Text(
              'Photo Editor',
              style: TextStyle(
                color: colorScheme.onBackground,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              'Pro tools • Watermark • Crop • Filters',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.65),
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: _buildPreviewSection(colorScheme, isDark),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingL,
              AppConstants.spacingM,
              AppConstants.spacingL,
              AppConstants.spacingL,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openEditor(_currentIndex),
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: const Text('Edit'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppConstants.spacingM,
                              horizontal: AppConstants.spacingS,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingS),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saveAllImages,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Save'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppConstants.spacingM,
                              horizontal: AppConstants.spacingS,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _exportToPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('Generate PDF'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppConstants.spacingM,
                          horizontal: AppConstants.spacingM,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
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

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.25),
          ),
          const SizedBox(height: AppConstants.spacingM),
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

  Widget _buildPreviewSection(ColorScheme colorScheme, bool isDark) {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final image = _images[index];
              final isActive = index == _currentIndex;
              return AnimatedContainer(
                key: ValueKey('${image.id}_${image.isEdited}'),
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(
                  horizontal: isActive ? 0 : 12,
                  vertical: isActive ? 0 : 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(
                        isActive ? 0.15 : 0.05,
                      ),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _PreviewImage(image: image),
                      Positioned(
                        left: AppConstants.spacingM,
                        top: AppConstants.spacingM,
                        child: Chip(
                          backgroundColor: isDark
                              ? Colors.black54
                              : Colors.white.withOpacity(0.8),
                          label: Text(
                            image.isEdited ? 'Edited with Pro tools' : 'Original',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : colorScheme.onSurface.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: AppConstants.spacingM,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingM,
                vertical: AppConstants.spacingS,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.6)
                    : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                '${_currentIndex + 1}/${_images.length}',
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : colorScheme.onSurface.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openEditor(int index) async {
    await _openEditorDirectly(index);
  }

  Future<void> _openEditorDirectly(int index) async {
    if (!mounted) return;
    
    final sourceBytes = await _images[index].loadBytes();
    final watermark = _watermarkController.text.trim().isEmpty
        ? 'Scanify AI'
        : _watermarkController.text.trim();

    final editedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ProImageEditorPage(
          initialBytes: sourceBytes,
          watermarkText: watermark,
          hostTheme: Theme.of(context),
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _isEditorOpen = false;
      });
    }

    if (editedBytes != null && mounted) {
      setState(() {
        _images[index].editedBytes = editedBytes;
      });
      
      // Auto-save the edited image
      await _autoSaveImage(index, editedBytes);
    } else if (mounted) {
      // If user cancelled, just go back
      NavigationService.goBack();
    }
  }

  Future<void> _autoSaveImage(int index, Uint8List editedBytes) async {
    if (_isSaving) return; // Prevent duplicate saves
    
    try {
      _isSaving = true;
      final fileStorageService = FileStorageService.instance;
      final image = _images[index];
      
      final docId = await fileStorageService.saveImageFile(
        imageBytes: editedBytes,
        fileName: image.displayName,
        title: 'Photo_Edited_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (docId != null && mounted) {
        // Refresh home screen documents
        final provider = Provider.of<HomeProvider>(context, listen: false);
        provider.loadDocuments();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image saved successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back after saving
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          NavigationService.goBack();
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error saving image: $e');
      }
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _saveAllImages() async {
    if (_images.isEmpty) {
      _showMessage('No images to save');
      return;
    }

    try {
      final fileStorageService = FileStorageService.instance;
      int savedCount = 0;

      for (int i = 0; i < _images.length; i++) {
        final image = _images[i];
        final bytes = image.editedBytes ?? await image.loadBytes();
        
        final docId = await fileStorageService.saveImageFile(
          imageBytes: bytes,
          fileName: image.displayName,
          title: 'Photo_Edited_${i + 1}',
        );

        if (docId != null) {
          savedCount++;
        }
      }

      // Refresh home screen documents
      if (mounted) {
        final provider = Provider.of<HomeProvider>(context, listen: false);
        provider.loadDocuments();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$savedCount image(s) saved successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error saving images: $e');
      }
    }
  }

  Future<void> _exportToPdf() async {
    if (_images.isEmpty) {
      _showMessage('No images to export');
      return;
    }

    // Collect edited images (or original if not edited)
    final Map<String, Uint8List?> editedImagesMap = {};
    final List<File> imageFiles = [];

    for (int i = 0; i < _images.length; i++) {
      final image = _images[i];
      imageFiles.add(image.originalFile);
      
      // Use edited bytes if available, otherwise null (will use original)
      if (image.editedBytes != null) {
        final imageKey = '${i}_Edited';
        editedImagesMap[imageKey] = image.editedBytes;
      }
    }

    // Navigate to progress screen
    NavigationService.toScanPDFProgress(
      imageFiles: imageFiles,
      filter: 'Edited',
      filteredImages: editedImagesMap.isEmpty ? null : editedImagesMap,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.image});

  final _EditableImage image;

  @override
  Widget build(BuildContext context) {
    if (image.editedBytes != null && image.editedBytes!.isNotEmpty) {
      return Image.memory(
        image.editedBytes!,
        fit: BoxFit.cover,
        key: ValueKey('edited_${image.id}'),
      );
    }
    return Image.file(
      image.originalFile,
      fit: BoxFit.cover,
      key: ValueKey('original_${image.id}'),
    );
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
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: presets.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppConstants.spacingM),
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

class _EditableImage {
  _EditableImage(File file)
    : originalFile = file,
      id = '${DateTime.now().microsecondsSinceEpoch}_${file.hashCode}';

  final File originalFile;
  final String id;
  Uint8List? editedBytes;

  bool get isEdited => editedBytes != null;

  String get displayName => originalFile.path.split('/').last;

  Future<Uint8List> loadBytes() async {
    if (editedBytes != null) return editedBytes!;
    return originalFile.readAsBytes();
  }
}
