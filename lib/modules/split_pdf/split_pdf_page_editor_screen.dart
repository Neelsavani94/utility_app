import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class SplitPdfPageEditorScreen extends StatelessWidget {
  final Uint8List initialBytes;
  final Function(Uint8List)? onImageEdited;

  const SplitPdfPageEditorScreen({
    super.key,
    required this.initialBytes,
    this.onImageEdited,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: ProImageEditor.memory(
          initialBytes,
          configs: ProImageEditorConfigs(
            designMode: isDark
                ? ImageEditorDesignMode.cupertino
                : ImageEditorDesignMode.material,
            theme: theme,
            helperLines: const HelperLineConfigs(),
          ),
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) async {
              // Return edited bytes back to the previous screen
              if (context.mounted) {
                // Call callback if provided (for backward compatibility)
                if (onImageEdited != null) {
                  onImageEdited!(bytes);
                }
                // Return the edited bytes as navigation result using GetX
                // Get.back(result: bytes);
              }
            },
            onCloseEditor: (_) {
              // Close editor without saving changes
              if (context.mounted) {
                Get.back();
              }
            },
          ),
        ),
      ),
    );
  }
}
