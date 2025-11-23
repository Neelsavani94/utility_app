import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _isScanning = true;
  String? _scannedText;
  String? _scannedType;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full Screen Scanner
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (!_isScanning) return;

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final barcode = barcodes.first;
                if (barcode.rawValue != null) {
                  setState(() {
                    _isScanning = false;
                    _scannedText = barcode.rawValue;
                    _scannedType = barcode.type.name;
                  });
                  _controller.stop();
                  _showResultPopup(context, _scannedText!, _scannedType!, colorScheme, isDark);
                }
              }
            },
          ),

          // Top Overlay with Close Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => NavigationService.goBack(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scanning Frame Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: colorScheme.primary,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Corner indicators
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: colorScheme.primary, width: 4),
                          left: BorderSide(color: colorScheme.primary, width: 4),
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: colorScheme.primary, width: 4),
                          right: BorderSide(color: colorScheme.primary, width: 4),
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: colorScheme.primary, width: 4),
                          left: BorderSide(color: colorScheme.primary, width: 4),
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: colorScheme.primary, width: 4),
                          right: BorderSide(color: colorScheme.primary, width: 4),
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Instructions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Position QR code or Barcode within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Scanning will happen automatically',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
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
      _isScanning = true;
      _scannedText = null;
      _scannedType = null;
    });
    _controller.start();
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

  Widget _buildBrowserSelectionSheet(
    BuildContext context,
    Uri searchUrl,
    String searchText,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    // Common browsers with their package names and display names
    final browsers = [
      {
        'name': 'Chrome',
        'package': 'com.android.chrome',
        'icon': Icons.language,
        'color': const Color(0xFF4285F4),
      },
      {
        'name': 'Firefox',
        'package': 'org.mozilla.firefox',
        'icon': Icons.language,
        'color': const Color(0xFFFF7139),
      },
      {
        'name': 'Edge',
        'package': 'com.microsoft.emmx',
        'icon': Icons.language,
        'color': const Color(0xFF0078D4),
      },
      {
        'name': 'Brave',
        'package': 'com.brave.browser',
        'icon': Icons.language,
        'color': const Color(0xFFFF9500),
      },
      {
        'name': 'Opera',
        'package': 'com.opera.browser',
        'icon': Icons.language,
        'color': const Color(0xFFFF1B2D),
      },
      {
        'name': 'Samsung Internet',
        'package': 'com.sec.android.app.sbrowser',
        'icon': Icons.language,
        'color': const Color(0xFF0066CC),
      },
      {
        'name': 'System Browser',
        'package': null,
        'icon': Icons.public,
        'color': colorScheme.primary,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Title
              Text(
                'Open with',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppConstants.spacingL),

              // Browser Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: AppConstants.spacingM,
                  mainAxisSpacing: AppConstants.spacingM,
                  childAspectRatio: 0.85,
                ),
                itemCount: browsers.length,
                itemBuilder: (context, index) {
                  final browser = browsers[index];
                  return _buildBrowserOption(
                    context,
                    browser['name'] as String,
                    browser['icon'] as IconData,
                    browser['color'] as Color,
                    browser['package'] as String?,
                    searchUrl,
                    colorScheme,
                    isDark,
                  );
                },
              ),

              const SizedBox(height: AppConstants.spacingM),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrowserOption(
    BuildContext context,
    String name,
    IconData icon,
    Color color,
    String? packageName,
    Uri searchUrl,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () async {
        Navigator.of(context).pop();
        // Small delay to allow bottom sheet to close
        await Future.delayed(const Duration(milliseconds: 300));
        await _launchBrowser(searchUrl, packageName, colorScheme);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surface.withOpacity(0.5)
              : colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? colorScheme.outline.withOpacity(0.2)
                : colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchBrowser(
    Uri searchUrl,
    String? packageName,
    ColorScheme colorScheme,
  ) async {
    try {
      // Use externalApplication mode which automatically shows browser picker
      // on Android when multiple browsers are installed
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

