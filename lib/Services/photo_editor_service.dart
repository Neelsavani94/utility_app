import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../Services/document_scan_serivce.dart';
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
        await _scanService.saveEditedImage(
          imageBytes: editedBytes,
          originalFileName: fileName,
        );

        // Refresh home screen documents
        if (context.mounted) {
          final provider = Provider.of<HomeProvider>(context, listen: false);
          provider.loadDocuments();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Image saved successfully'),
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

