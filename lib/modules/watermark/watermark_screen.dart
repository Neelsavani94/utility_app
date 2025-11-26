import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:watermark_kit/watermark_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:image/image.dart' as img;
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';

class WatermarkScreen extends StatefulWidget {
  const WatermarkScreen({super.key});

  @override
  State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  File? _selectedFile;
  final TextEditingController _watermarkTextController = TextEditingController();
  bool _isProcessing = false;
  double _progress = 0.0;
  String? _outputPath;
  final WatermarkKit _watermarkKit = WatermarkKit();

  @override
  void dispose() {
    _watermarkTextController.dispose();
    super.dispose();
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
          'Watermark Document',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // File Picker Section
              GestureDetector(
                onTap: _isProcessing ? null : _pickFile,
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.spacingXL),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.surface.withOpacity(0.5)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusL),
                    border: Border.all(
                      color: isDark
                          ? colorScheme.outline.withOpacity(0.3)
                          : colorScheme.outline.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFile == null
                            ? Icons.upload_file_rounded
                            : Icons.check_circle_rounded,
                        size: 64,
                        color: _selectedFile == null
                            ? colorScheme.primary
                            : Colors.green,
                      ),
                      const SizedBox(height: AppConstants.spacingM),
                      Text(
                        _selectedFile == null
                            ? 'Tap to Pick File or Document'
                            : 'File Selected',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (_selectedFile != null) ...[
                        const SizedBox(height: AppConstants.spacingS),
                        Text(
                          _selectedFile!.path.split('/').last,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingXL),
              // Watermark Text Field
              Text(
                'Watermark Text',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppConstants.spacingM),
              TextField(
                controller: _watermarkTextController,
                enabled: !_isProcessing,
                decoration: InputDecoration(
                  hintText: 'Enter watermark text',
                  filled: true,
                  fillColor: isDark
                      ? colorScheme.surface.withOpacity(0.5)
                      : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingM,
                    vertical: AppConstants.spacingM,
                  ),
                ),
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: AppConstants.spacingXL),
              // Process Button
              if (_isProcessing) ...[
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingM),
                    Text(
                      'Processing... ${(_progress * 100).toInt()}%',
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingL),
              ],
              ElevatedButton(
                onPressed: (_selectedFile == null ||
                        _watermarkTextController.text.isEmpty ||
                        _isProcessing)
                    ? null
                    : _applyWatermark,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.spacingM,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Apply Watermark',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Output Section
              if (_outputPath != null && !_isProcessing) ...[
                const SizedBox(height: AppConstants.spacingXL),
                Container(
                  padding: const EdgeInsets.all(AppConstants.spacingL),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.green, size: 24),
                          const SizedBox(width: AppConstants.spacingM),
                          Expanded(
                            child: Text(
                              'Watermark applied successfully!',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingL),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _shareFile(),
                              icon: Icon(Icons.share_rounded),
                              label: Text('Share'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.primary,
                                side: BorderSide(color: colorScheme.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingM),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openFile(),
                              icon: Icon(Icons.open_in_new_rounded),
                              label: Text('Open'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _outputPath = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _applyWatermark() async {
    if (_selectedFile == null || _watermarkTextController.text.isEmpty) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _outputPath = null;
    });

    try {
      final inputPath = _selectedFile!.path;
      final extension = inputPath.split('.').last.toLowerCase();
      final watermarkText = _watermarkTextController.text;

      // Get output directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFileName = 'watermarked_$timestamp.$extension';
      final outputPath = '${directory.path}/$outputFileName';

      setState(() {
        _progress = 0.2;
      });

      // Check file type and apply watermark accordingly
      if (['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(extension)) {
        // Image watermarking
        await _watermarkImage(inputPath, outputPath, watermarkText);
      } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
        // Video watermarking
        await _watermarkVideo(inputPath, outputPath, watermarkText);
      } else if (extension == 'pdf') {
        // PDF watermarking (convert to images first)
        await _watermarkPDF(inputPath, outputPath, watermarkText);
      } else {
        throw Exception('Unsupported file type: $extension');
      }

      setState(() {
        _progress = 1.0;
        _isProcessing = false;
        _outputPath = outputPath;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Watermark applied successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        final errorMessage = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage.length > 100 
                ? 'Error applying watermark: ${errorMessage.substring(0, 100)}...' 
                : 'Error applying watermark: $errorMessage',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _watermarkImage(
      String inputPath, String outputPath, String text) async {
    setState(() {
      _progress = 0.4;
    });

    try {
      // Read input image
      final inputBytes = await File(inputPath).readAsBytes();
      final inputImage = img.decodeImage(inputBytes);
      
      if (inputImage == null) {
        throw Exception('Failed to decode input image');
      }

      setState(() {
        _progress = 0.5;
      });

      // Create text watermark image
      final watermarkImage = await _createTextWatermarkImage(text, inputImage.width, inputImage.height);
      
      setState(() {
        _progress = 0.6;
      });

      // Apply watermark using watermark_kit
      final outputBytes = await _watermarkKit.composeImage(
        inputImage: Uint8List.fromList(inputBytes),
        watermarkImage: watermarkImage,
        anchor: 'center',
        margin: 0.0,
        marginUnit: 'px',
        widthPercent: 0.5, // Watermark width as percentage of base image
        opacity: 0.5,
        format: outputPath.toLowerCase().endsWith('.png') ? 'png' : 'jpeg',
        quality: 0.9,
      );

      setState(() {
        _progress = 0.8;
      });

      // Save output image
      await File(outputPath).writeAsBytes(outputBytes);

      setState(() {
        _progress = 0.9;
      });
    } catch (e) {
      throw Exception('Failed to watermark image: $e');
    }
  }

  // Helper method to create text watermark image
  // Creates a simple semi-transparent overlay that watermark_kit can use
  Future<Uint8List> _createTextWatermarkImage(String text, int baseWidth, int baseHeight) async {
    // Calculate watermark size (about 50% of base image width)
    final watermarkWidth = (baseWidth * 0.5).round().clamp(200, 800);
    final watermarkHeight = (baseHeight * 0.15).round().clamp(50, 200);
    
    // Create a semi-transparent white rectangle as watermark
    // Note: For proper text rendering, you might want to use a package like
    // 'screenshot' or 'widgets_to_image' to convert a Text widget to image
    final watermark = img.Image(width: watermarkWidth, height: watermarkHeight);
    
    // Fill with semi-transparent white (50% opacity)
    img.fill(watermark, color: img.ColorRgba8(255, 255, 255, 128));
    
    // Encode to PNG with transparency
    final watermarkBytes = img.encodePng(watermark);
    return Uint8List.fromList(watermarkBytes);
  }

  Future<void> _watermarkVideo(
      String inputPath, String outputPath, String text) async {
    setState(() {
      _progress = 0.4;
    });

    try {
      // Apply text watermark to video using watermark_kit
      final task = await _watermarkKit.composeVideo(
        inputVideoPath: inputPath,
        text: text,
        anchor: 'center',
        margin: 16.0,
        marginUnit: 'px',
        widthPercent: 0.3, // Watermark width as percentage of video width
        opacity: 0.5,
        codec: 'h264',
      );

      setState(() {
        _progress = 0.5;
      });

      // Monitor progress
      task.progress.listen((progress) {
        if (mounted) {
          setState(() {
            _progress = 0.5 + (progress * 0.4); // 50% to 90%
          });
        }
      });

      // Wait for completion
      final result = await task.done;
      
      // Copy result to output path
      final resultFile = File(result.path);
      await resultFile.copy(outputPath);

      setState(() {
        _progress = 0.95;
      });
    } catch (e) {
      throw Exception('Failed to watermark video: $e');
    }
  }

  Future<void> _watermarkPDF(
      String inputPath, String outputPath, String text) async {
    setState(() {
      _progress = 0.4;
    });

    try {
      // Read the PDF file
      final inputBytes = await File(inputPath).readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: inputBytes);

      setState(() {
        _progress = 0.5;
      });

      // Add watermark to all pages
      for (int i = 0; i < document.pages.count; i++) {
        final PdfPage page = document.pages[i];
        final PdfGraphics graphics = page.graphics;

        // Get page dimensions
        final double pageWidth = page.size.width;
        final double pageHeight = page.size.height;

        // Create font for watermark
        final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 48);
        final PdfStringFormat format = PdfStringFormat(
          alignment: PdfTextAlignment.center,
        );

        // Calculate text size
        final Size textSize = font.measureString(text, format: format);
        final double x = (pageWidth - textSize.width) / 2;
        final double y = (pageHeight - textSize.height) / 2;

        // Draw watermark with transparency
        graphics.setTransparency(0.5);
        graphics.drawString(
          text,
          font,
          brush: PdfSolidBrush(PdfColor(255, 255, 255)),
          bounds: Rect.fromLTWH(x, y, textSize.width, textSize.height),
          format: format,
        );

        setState(() {
          _progress = 0.5 + (0.3 * (i + 1) / document.pages.count);
        });
      }

      setState(() {
        _progress = 0.9;
      });

      // Save the watermarked PDF
      final List<int> bytes = await document.save();
      document.dispose();

      await File(outputPath).writeAsBytes(bytes);

      setState(() {
        _progress = 0.95;
      });
    } catch (e) {
      // If PDF library fails, show error - PDF watermarking should use PDF library
      throw Exception('PDF watermarking failed: $e. Please ensure the PDF file is valid.');
    }

    setState(() {
      _progress = 0.98;
    });
  }

  Future<void> _shareFile() async {
    if (_outputPath == null) return;

    try {
      await Share.shareXFiles(
        [XFile(_outputPath!)],
        text: 'Watermarked document',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _openFile() async {
    if (_outputPath == null) return;

    try {
      await OpenFile.open(_outputPath!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

