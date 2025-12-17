import 'package:flutter/material.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';

class QRReaderScreen extends StatefulWidget {
  const QRReaderScreen({super.key});

  @override
  State<QRReaderScreen> createState() => _QRReaderScreenState();
}

class _QRReaderScreenState extends State<QRReaderScreen> {
  String? _scannedType;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _openScanner() async {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    try {
      final String? result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SimpleBarcodeScannerPage(),
        ),
      );

      if (result != null && result.isNotEmpty && mounted && result.toString() != '-1') {
        // Determine if it's a QR code or barcode based on the result
        // Simple barcode scanner doesn't distinguish, so we'll check if it looks like a URL
        final isQRCode = result.startsWith('http://') || 
                        result.startsWith('https://') ||
                        result.startsWith('www.') ||
                        result.contains('://');

        setState(() {
          _scannedType = isQRCode ? 'qrCode' : 'barcode';
        });

        _showResultPopup(context, result, _scannedType!, colorScheme, isDark);
      } else if (mounted) {
        // User cancelled or no result - stay on screen, don't go back
        // This allows user to try scanning again
      }
    } catch (e) {
      if (mounted) {
        _showError('Error scanning: $e', colorScheme);
        // Go back on error
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            NavigationService.goBack();
          }
        });
      }
    }
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
          'QR Scanner',
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // QR Code Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXL),
                
                // Title
                Text(
                  'Scan QR Code or Barcode',
                  style: TextStyle(
                    color: colorScheme.onBackground,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingM),
                
                // Description
                Text(
                  'Tap the button below to open the scanner and scan any QR code or barcode',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingXXL),
                
                // Scan Button
                ElevatedButton.icon(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
                  label: const Text(
                    'Open Scanner',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingXL,
                      vertical: AppConstants.spacingL,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResultPopup(
    BuildContext context,
    String scannedText,
    String scannedType,
    ColorScheme colorScheme,
    bool isDark,
  ) {
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
                // Header with Close Button (Top Right)
                Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // QR or Barcode Type Label
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
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? colorScheme.surface.withOpacity(0.5)
                              : colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: colorScheme.onSurface,
                            size: 24,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _resetScanner();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scanned Text Display
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

                // Action Buttons Row
                Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  child: Row(
                    children: [
                      // Search Text Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _searchText(scannedText, colorScheme),
                          icon: const Icon(Icons.search_rounded, size: 20),
                          label: const Text('Search Text'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppConstants.spacingM,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingM),
                      // Share Text Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _shareText(scannedText, colorScheme),
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
                            elevation: 0,
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

  void _resetScanner() {
    setState(() {
      _scannedType = null;
    });
    // Open scanner again
    _openScanner();
  }

  Future<void> _searchText(String text, ColorScheme colorScheme) async {
    try {
      // Create search URL
      final searchQuery = Uri.encodeComponent(text);
      final searchUrl = Uri.parse('https://www.google.com/search?q=$searchQuery');

      // Use externalApplication mode which automatically shows browser picker
      // on Android/iOS when multiple browsers are installed
      // This will display all installed browsers for the user to choose from
      final launched = await launchUrl(
        searchUrl,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        // Fallback to platformDefault if externalApplication fails
        await launchUrl(
          searchUrl,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      _showError('Could not open browser. Please check if a browser is installed.', colorScheme);
    }
  }

  Future<void> _shareText(String text, ColorScheme colorScheme) async {
    try {
      await Share.share(text);
    } catch (e) {
      _showError('Error sharing: $e', colorScheme);
    }
  }

  void _showError(String message, ColorScheme colorScheme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
