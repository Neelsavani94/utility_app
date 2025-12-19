import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_pdf;
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PDFCompressionService {
  static final PDFCompressionService instance = PDFCompressionService._init();
  PDFCompressionService._init();

  /// Compress PDF file by size with quality options
  /// 
  /// [pdfBytes] - Original PDF bytes
  /// [compressionLevel] - Compression level (0.0 to 1.0):
  ///   - 0.0 = Maximum compression (lowest quality)
  ///   - 0.5 = Balanced compression
  ///   - 1.0 = Minimum compression (highest quality)
  /// 
  /// Returns compressed PDF bytes
  Future<Uint8List> compressPDF({
    required Uint8List pdfBytes,
    double compressionLevel = 0.5,
    Function(double)? onProgress,
  }) async {
    try {
      // Clamp compression level between 0.0 and 1.0
      compressionLevel = compressionLevel.clamp(0.0, 1.0);

      onProgress?.call(0.1);

      // Load the PDF document to get page count
      final originalDocument = syncfusion_pdf.PdfDocument(inputBytes: pdfBytes);
      
      if (originalDocument.pages.count == 0) {
        originalDocument.dispose();
        return pdfBytes;
      }

      final totalPages = originalDocument.pages.count;
      originalDocument.dispose();

      onProgress?.call(0.2);

      // Calculate image quality and DPI based on compression level
      // Lower compression level = lower quality = smaller file size
      final imageQuality = (85 - (compressionLevel * 35)).round().clamp(50, 85);
      final imageDpi = (200.0 - (compressionLevel * 50.0)).clamp(150.0, 200.0);

      // Create a new PDF document using pdf package
      final pdf = pw.Document();

      // Process each page
      for (int i = 0; i < totalPages; i++) {
        final progress = 0.2 + (0.6 * (i / totalPages));
        onProgress?.call(progress);

        try {
          // Render page as image with compression using Printing package
          final pageImageStream = Printing.raster(
            pdfBytes,
            pages: [i],
            dpi: imageDpi,
          );
          
          await for (final pageImage in pageImageStream) {
            // Convert to PNG first
            final pngBytes = await pageImage.toPng();
            final decodedImage = img.decodeImage(pngBytes);
            
            if (decodedImage != null) {
              // Compress image to JPEG with specified quality
              final compressedImageBytes = Uint8List.fromList(
                img.encodeJpg(decodedImage, quality: imageQuality),
              );
              
              // Get page dimensions from original PDF
              final tempDoc = syncfusion_pdf.PdfDocument(inputBytes: pdfBytes);
              final pageSize = tempDoc.pages[i].size;
              final pageWidth = pageSize.width;
              final pageHeight = pageSize.height;
              tempDoc.dispose();
              
              // Add compressed image to new PDF
              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat(pageWidth, pageHeight),
                  build: (pw.Context context) {
                    return pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(compressedImageBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    );
                  },
                ),
              );
            }
            break; // Only process first image from stream
          }
        } catch (e) {
          print('Warning: Could not compress page ${i + 1}: $e');
          // If compression fails for a page, try to add a blank page to maintain structure
          try {
            final tempDoc = syncfusion_pdf.PdfDocument(inputBytes: pdfBytes);
            final pageSize = tempDoc.pages[i].size;
            tempDoc.dispose();
            
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat(pageSize.width, pageSize.height),
                build: (pw.Context context) {
                  return pw.SizedBox();
                },
              ),
            );
          } catch (e2) {
            print('Error adding blank page ${i + 1}: $e2');
          }
        }
      }

      onProgress?.call(0.8);

      // Save compressed PDF
      final compressedBytes = await pdf.save();

      onProgress?.call(0.9);

      // Return the smaller of the two files
      if (compressedBytes.length < pdfBytes.length) {
        onProgress?.call(1.0);
        return Uint8List.fromList(compressedBytes);
      } else {
        // If compression didn't help, return original
        onProgress?.call(1.0);
        return pdfBytes;
      }
    } catch (e) {
      print('PDF compression error: $e');
      // Return original if compression fails
      return pdfBytes;
    }
  }

  /// Alternative compression method: Optimize PDF structure
  /// This method preserves text and vector graphics better
  Future<Uint8List> optimizePDFStructure({
    required Uint8List pdfBytes,
    Function(double)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);

      // Load PDF
      final document = syncfusion_pdf.PdfDocument(inputBytes: pdfBytes);
      
      if (document.pages.count == 0) {
        document.dispose();
        return pdfBytes;
      }

      onProgress?.call(0.3);

      // Note: syncfusion_pdf doesn't have a direct compress property
      // We'll use the compression method instead which renders pages as images
      // This method is kept for potential future use with different PDF libraries

      // Process each page to optimize
      final totalPages = document.pages.count;
      for (int i = 0; i < totalPages; i++) {
        final progress = 0.3 + (0.5 * (i / totalPages));
        onProgress?.call(progress);

        try {
          // Process page for optimization
          // Note: Direct image extraction and replacement requires more complex PDF manipulation
          // This is a placeholder for future enhancement
          // Accessing page to ensure it exists
          document.pages[i];
        } catch (e) {
          print('Error optimizing page ${i + 1}: $e');
        }
      }

      onProgress?.call(0.8);

      // Save optimized document
      final optimizedBytes = document.saveSync();
      document.dispose();

      onProgress?.call(0.9);

      // Return the smaller file
      if (optimizedBytes.length < pdfBytes.length) {
        onProgress?.call(1.0);
        return Uint8List.fromList(optimizedBytes);
      } else {
        onProgress?.call(1.0);
        return pdfBytes;
      }
    } catch (e) {
      print('PDF optimization error: $e');
      return pdfBytes;
    }
  }

  /// Get file size in human-readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Calculate compression percentage
  double calculateCompressionPercentage(int originalSize, int compressedSize) {
    if (originalSize == 0) return 0.0;
    final percentage = ((originalSize - compressedSize) / originalSize) * 100;
    return percentage.clamp(0.0, 100.0);
  }
}

