import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';

class ScanPDFViewerScreen extends StatefulWidget {
  final String pdfPath;

  const ScanPDFViewerScreen({
    super.key,
    required this.pdfPath,
  });

  @override
  State<ScanPDFViewerScreen> createState() => _ScanPDFViewerScreenState();
}

class _ScanPDFViewerScreenState extends State<ScanPDFViewerScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  int _totalPages = 0;
  int _currentPage = 0;
  PDFViewController? _pdfViewController;

  @override
  void initState() {
    super.initState();
    _checkFileExists();
  }

  Future<void> _checkFileExists() async {
    final file = File(widget.pdfPath);
    if (!await file.exists()) {
      setState(() {
        _hasError = true;
        _errorMessage = 'PDF file not found';
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openWithSystemViewer() async {
    try {
      final result = await OpenFile.open(widget.pdfPath);
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sharePDF() async {
    try {
      final file = File(widget.pdfPath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(widget.pdfPath)],
          text: 'Scanned PDF Document',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF file not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        title: Column(
          children: [
            Text(
              'PDF Viewer',
              style: TextStyle(
                color: colorScheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_totalPages > 0)
              Text(
                'Page $_currentPage of $_totalPages',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.open_in_new_rounded,
              color: colorScheme.onSurface,
              size: 20,
            ),
            onPressed: _openWithSystemViewer,
            tooltip: 'Open with System Viewer',
          ),
          IconButton(
            icon: Icon(
              Icons.share_rounded,
              color: colorScheme.onSurface,
              size: 20,
            ),
            onPressed: _sharePDF,
            tooltip: 'Share PDF',
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: colorScheme.error,
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Error Loading PDF',
              style: TextStyle(
                color: colorScheme.onBackground,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingXL,
              ),
              child: Text(
                _errorMessage ?? 'Unknown error',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppConstants.spacingXL),
            ElevatedButton.icon(
              onPressed: _openWithSystemViewer,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open with System Viewer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingL,
                  vertical: AppConstants.spacingM,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PDFView(
      filePath: widget.pdfPath,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      defaultPage: 0,
      fitPolicy: FitPolicy.BOTH,
      preventLinkNavigation: false,
      onRender: (pages) {
        setState(() {
          _totalPages = pages ?? 0;
        });
      },
      onError: (error) {
        setState(() {
          _hasError = true;
          _errorMessage = error.toString();
        });
      },
      onPageError: (page, error) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error loading page $page: $error';
        });
      },
      onViewCreated: (PDFViewController controller) {
        setState(() {
          _pdfViewController = controller;
        });
      },
      onLinkHandler: (String? uri) {
        // Handle PDF links if needed
      },
      onPageChanged: (int? page, int? total) {
        setState(() {
          _currentPage = (page ?? 0) + 1;
          _totalPages = total ?? 0;
        });
      },
    );
  }
}

