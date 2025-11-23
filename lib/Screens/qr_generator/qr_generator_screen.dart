import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';

class QRGeneratorScreen extends StatefulWidget {
  const QRGeneratorScreen({super.key});

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  String _selectedType = 'Text';
  final TextEditingController _textController = TextEditingController();
  String? _generatedData;
  GlobalKey _qrKey = GlobalKey();
  bool _isTextEmpty = true;

  final List<String> _qrTypes = ['Text', 'Email', 'Phone', 'SMS', 'URL'];

  @override
  void initState() {
    super.initState();
    // Listen to text changes to update button state
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final isEmpty = _textController.text.trim().isEmpty;
    if (_isTextEmpty != isEmpty) {
      setState(() {
        _isTextEmpty = isEmpty;
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
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
          'QR Generator',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: _generatedData != null
            ? [
                // Download Button
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.surface.withOpacity(0.2)
                        : colorScheme.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.download_rounded,
                      color: colorScheme.onSurface,
                      size: 20,
                    ),
                    onPressed: () => _downloadQRCode(colorScheme, isDark),
                    padding: EdgeInsets.zero,
                  ),
                ),
                // Share Button
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.surface.withOpacity(0.2)
                        : colorScheme.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.share_rounded,
                      color: colorScheme.onSurface,
                      size: 20,
                    ),
                    onPressed: () => _shareQRCode(colorScheme, isDark),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ]
            : null,
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
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // QR Type Dropdown
              _buildTypeDropdown(colorScheme, isDark),

              const SizedBox(height: AppConstants.spacingL),

              // TextField
              _buildTextField(colorScheme, isDark),

              const SizedBox(height: AppConstants.spacingL),

              // Generate Button
              _buildGenerateButton(colorScheme, isDark),

              const SizedBox(height: AppConstants.spacingXL),

              // Generated QR Code View
              if (_generatedData != null)
                _buildQRCodeView(_generatedData!, colorScheme, isDark)
              else
                _buildPlaceholderView(colorScheme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown(ColorScheme colorScheme, bool isDark) {
    return Container(
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
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: colorScheme.onSurface,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
          ),
          items: _qrTypes.map((String type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Row(
                children: [
                  Icon(
                    _getTypeIcon(type),
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Text(
                    type,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedType = newValue;
                _textController.clear();
                _generatedData = null;
                _isTextEmpty = true;
              });
            }
          },
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Email':
        return Icons.email_rounded;
      case 'Phone':
        return Icons.phone_rounded;
      case 'SMS':
        return Icons.sms_rounded;
      case 'URL':
        return Icons.link_rounded;
      default:
        return Icons.text_fields_rounded;
    }
  }

  Widget _buildTextField(ColorScheme colorScheme, bool isDark) {
    return Container(
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
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _textController,
        maxLines: _selectedType == 'Text' ? 5 : 1,
        decoration: InputDecoration(
          hintText: _getPlaceholderText(),
          hintStyle: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.4),
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(AppConstants.spacingM),
        ),
        style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        keyboardType: _getKeyboardType(),
      ),
    );
  }

  String _getPlaceholderText() {
    switch (_selectedType) {
      case 'Email':
        return 'Enter email address (e.g., example@email.com)';
      case 'Phone':
        return 'Enter phone number (e.g., +1234567890)';
      case 'SMS':
        return 'Enter phone number (e.g., +1234567890)';
      case 'URL':
        return 'Enter URL (e.g., https://example.com)';
      default:
        return 'Enter text to generate QR code';
    }
  }

  TextInputType _getKeyboardType() {
    switch (_selectedType) {
      case 'Email':
        return TextInputType.emailAddress;
      case 'Phone':
      case 'SMS':
        return TextInputType.phone;
      case 'URL':
        return TextInputType.url;
      default:
        return TextInputType.text;
    }
  }

  Widget _buildGenerateButton(ColorScheme colorScheme, bool isDark) {
    final isEmpty = _isTextEmpty;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: isEmpty
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withOpacity(0.7),
                ],
              ),
        color: isEmpty
            ? (isDark
                  ? colorScheme.surface.withOpacity(0.3)
                  : colorScheme.surfaceVariant.withOpacity(0.5))
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isEmpty
            ? null
            : [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: isEmpty ? null : _generateQRCode,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_rounded,
              color: isEmpty
                  ? colorScheme.onSurface.withOpacity(0.4)
                  : Colors.white,
              size: 24,
            ),
            const SizedBox(width: AppConstants.spacingS),
            Text(
              'Generate QR Code',
              style: TextStyle(
                color: isEmpty
                    ? colorScheme.onSurface.withOpacity(0.4)
                    : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderView(ColorScheme colorScheme, bool isDark) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withOpacity(0.2)
              : colorScheme.outline.withOpacity(0.1),
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Your QR Code will appear here',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeView(String data, ColorScheme colorScheme, bool isDark) {
    return RepaintBoundary(
      key: _qrKey,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // QR Code
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: 250.0,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateQRCode() {
    final input = _textController.text.trim();
    if (input.isEmpty) return;

    String qrData = input;

    // Format data based on type
    switch (_selectedType) {
      case 'Email':
        qrData = 'mailto:$input';
        break;
      case 'Phone':
        qrData = 'tel:$input';
        break;
      case 'SMS':
        qrData = 'sms:$input';
        break;
      case 'URL':
        if (!input.startsWith('http://') && !input.startsWith('https://')) {
          qrData = 'https://$input';
        }
        break;
      default:
        qrData = input;
    }

    setState(() {
      _generatedData = qrData;
    });

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  Future<void> _downloadQRCode(ColorScheme colorScheme, bool isDark) async {
    if (_generatedData == null) return;

    try {
      // Capture QR code as image
      final imageBytes = await _captureQRCodeAsImage();

      if (imageBytes != null) {
        // Get downloads directory
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${directory.path}/qr_code_$timestamp.png');

        await file.writeAsBytes(imageBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR Code saved to ${file.path}'),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      _showError('Error downloading QR code: $e', colorScheme);
    }
  }

  Future<void> _shareQRCode(ColorScheme colorScheme, bool isDark) async {
    if (_generatedData == null) return;

    try {
      // Capture QR code as image
      final imageBytes = await _captureQRCodeAsImage();

      if (imageBytes != null) {
        // Save to temp directory for sharing
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${tempDir.path}/qr_code_$timestamp.png');

        await file.writeAsBytes(imageBytes);

        await Share.shareXFiles([XFile(file.path)]);

        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      _showError('Error sharing QR code: $e', colorScheme);
    }
  }

  Future<Uint8List?> _captureQRCodeAsImage() async {
    try {
      // Use QrPainter to create QR code image
      final painter = QrPainter(
        data: _generatedData!,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        color: Colors.black, // Black QR code
        emptyColor: Colors.white, // White background
      );

      // Render to image with padding
      final picRecorder = ui.PictureRecorder();
      final canvas = Canvas(picRecorder);
      const totalSize = 500.0;
      const padding = 40.0; // Padding on all sides
      const qrSize = totalSize - (padding * 2); // QR code size with padding

      // Fill canvas with white background first
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, totalSize, totalSize), whitePaint);

      // Translate canvas to center the QR code with padding
      canvas.save();
      canvas.translate(padding, padding);

      // Paint QR code on top (black on white) with padding around it
      painter.paint(canvas, Size(qrSize, qrSize));

      canvas.restore();

      final picture = picRecorder.endRecording();
      final image = await picture.toImage(totalSize.toInt(), totalSize.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing QR code: $e');
      return null;
    }
  }

  void _showError(String message, ColorScheme colorScheme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
