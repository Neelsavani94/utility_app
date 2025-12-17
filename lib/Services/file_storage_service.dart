import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_pdf;
import '../Models/document_model.dart';
import '../Services/database_helper.dart';

class FileStorageService {
  static final FileStorageService instance = FileStorageService._init();
  static const String appName = 'ScanifyAI';

  FileStorageService._init();

  /// Get the base directory for the app
  Future<Directory> getAppBaseDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final appDir = Directory('${documentsDir.path}/$appName');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  /// Get the Images directory
  Future<Directory> getImagesDirectory() async {
    final appDir = await getAppBaseDirectory();
    final imagesDir = Directory('${appDir.path}/Images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// Get the PDF directory
  Future<Directory> getPDFDirectory() async {
    final appDir = await getAppBaseDirectory();
    final pdfDir = Directory('${appDir.path}/PDF');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  /// Generate thumbnail from image bytes
  Future<Uint8List?> generateImageThumbnail(
    Uint8List imageBytes, {
    int maxWidth = 200,
    int maxHeight = 200,
    int quality = 85,
  }) async {
    try {
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return null;

      // Calculate thumbnail dimensions maintaining aspect ratio
      int thumbWidth = originalImage.width;
      int thumbHeight = originalImage.height;

      if (thumbWidth > maxWidth || thumbHeight > maxHeight) {
        final ratio = (thumbWidth / thumbHeight).clamp(0.1, 10.0);
        if (thumbWidth > thumbHeight) {
          thumbWidth = maxWidth;
          thumbHeight = (maxWidth / ratio).round();
        } else {
          thumbHeight = maxHeight;
          thumbWidth = (maxHeight * ratio).round();
        }
      }

      // Resize image
      final thumbnail = img.copyResize(
        originalImage,
        width: thumbWidth,
        height: thumbHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode as JPEG
      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: quality));
    } catch (e) {
      print('Error generating image thumbnail: $e');
      return null;
    }
  }

  /// Generate thumbnail from PDF (first page)
  Future<Uint8List?> generatePDFThumbnail(
    Uint8List pdfBytes, {
    int maxWidth = 200,
    int maxHeight = 200,
    double dpi = 150.0,
  }) async {
    try {
      // Use syncfusion to get first page as image
      final pdfDocument = syncfusion_pdf.PdfDocument(inputBytes: pdfBytes);
      
      if (pdfDocument.pages.count == 0) {
        pdfDocument.dispose();
        return null;
      }

      // Render first page
      final imageStream = Printing.raster(
        pdfBytes,
        pages: [0],
        dpi: dpi,
      );

      Uint8List? thumbnailBytes;
      await for (final image in imageStream) {
        final pngBytes = await image.toPng();
        
        // Resize thumbnail if needed
        final decodedImage = img.decodeImage(pngBytes);
        if (decodedImage != null) {
          int thumbWidth = decodedImage.width;
          int thumbHeight = decodedImage.height;

          if (thumbWidth > maxWidth || thumbHeight > maxHeight) {
            final ratio = (thumbWidth / thumbHeight).clamp(0.1, 10.0);
            if (thumbWidth > thumbHeight) {
              thumbWidth = maxWidth;
              thumbHeight = (maxWidth / ratio).round();
            } else {
              thumbHeight = maxHeight;
              thumbWidth = (maxHeight * ratio).round();
            }
          }

          final thumbnail = img.copyResize(
            decodedImage,
            width: thumbWidth,
            height: thumbHeight,
            interpolation: img.Interpolation.linear,
          );

          thumbnailBytes = Uint8List.fromList(
            img.encodeJpg(thumbnail, quality: 85),
          );
        } else {
          thumbnailBytes = pngBytes;
        }
        break; // Only need first page
      }

      pdfDocument.dispose();
      return thumbnailBytes;
    } catch (e) {
      print('Error generating PDF thumbnail: $e');
      return null;
    }
  }

  /// Save image file and create database entry
  Future<int?> saveImageFile({
    required Uint8List imageBytes,
    required String fileName,
    String? title,
    int? tagId,
    bool isFavourite = false,
  }) async {
    try {
      final imagesDir = await getImagesDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Ensure fileName has proper extension
      String finalFileName = fileName;
      if (!fileName.toLowerCase().endsWith('.jpg') &&
          !fileName.toLowerCase().endsWith('.jpeg') &&
          !fileName.toLowerCase().endsWith('.png')) {
        finalFileName = '$fileName.jpg';
      }
      
      final filePath = '${imagesDir.path}/img_$timestamp${_getExtension(finalFileName)}';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      // Generate thumbnail
      final thumbnailBytes = await generateImageThumbnail(imageBytes);
      String? thumbnailPath;
      
      if (thumbnailBytes != null) {
        final thumbPath = '${imagesDir.path}/thumb_$timestamp.jpg';
        final thumbFile = File(thumbPath);
        await thumbFile.writeAsBytes(thumbnailBytes);
        thumbnailPath = thumbPath;
      }

      // Create document entry
      final document = Document(
        title: title ?? _getFileNameWithoutExtension(finalFileName),
        type: 'image',
        imagePath: filePath,
        thumbnailPath: thumbnailPath,
        tagId: tagId,
        isFavourite: isFavourite,
      );

      return await DatabaseHelper.instance.insertDocument(document);
    } catch (e) {
      print('Error saving image file: $e');
      return null;
    }
  }

  /// Save PDF file and create database entry
  Future<int?> savePDFFile({
    required Uint8List pdfBytes,
    required String fileName,
    String? title,
    int? tagId,
    bool isFavourite = false,
  }) async {
    try {
      final pdfDir = await getPDFDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Ensure fileName has proper extension
      String finalFileName = fileName;
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        finalFileName = '$fileName.pdf';
      }
      
      final filePath = '${pdfDir.path}/pdf_$timestamp${_getExtension(finalFileName)}';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // Generate thumbnail from first page
      final thumbnailBytes = await generatePDFThumbnail(pdfBytes);
      String? thumbnailPath;
      
      if (thumbnailBytes != null) {
        final thumbPath = '${pdfDir.path}/thumb_$timestamp.jpg';
        final thumbFile = File(thumbPath);
        await thumbFile.writeAsBytes(thumbnailBytes);
        thumbnailPath = thumbPath;
      }

      // Create document entry
      final document = Document(
        title: title ?? _getFileNameWithoutExtension(finalFileName),
        type: 'pdf',
        imagePath: filePath,
        thumbnailPath: thumbnailPath,
        tagId: tagId,
        isFavourite: isFavourite,
      );

      return await DatabaseHelper.instance.insertDocument(document);
    } catch (e) {
      print('Error saving PDF file: $e');
      return null;
    }
  }

  /// Save image from File and create database entry
  Future<int?> saveImageFileFromFile({
    required File imageFile,
    String? title,
    int? tagId,
    bool isFavourite = false,
  }) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      return await saveImageFile(
        imageBytes: imageBytes,
        fileName: imageFile.path.split('/').last,
        title: title,
        tagId: tagId,
        isFavourite: isFavourite,
      );
    } catch (e) {
      print('Error saving image file from File: $e');
      return null;
    }
  }

  /// Helper to get file extension
  String _getExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return '.${parts.last}';
    }
    return '.jpg'; // Default extension
  }

  /// Helper to get filename without extension
  String _getFileNameWithoutExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.sublist(0, parts.length - 1).join('.');
    }
    return fileName;
  }

  /// Copy a file to a new location with a new name
  Future<String?> copyFile({
    required String sourcePath,
    required String newFileName,
    bool isPDF = false,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist');
      }

      final targetDir = isPDF ? await getPDFDirectory() : await getImagesDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Get file extension
      final extension = _getExtension(sourcePath);
      
      final targetPath = isPDF
          ? '${targetDir.path}/pdf_$timestamp$extension'
          : '${targetDir.path}/img_$timestamp$extension';
      
      await sourceFile.copy(targetPath);
      
      return targetPath;
    } catch (e) {
      print('Error copying file: $e');
      return null;
    }
  }

  /// Copy thumbnail file
  Future<String?> copyThumbnail({
    required String? sourceThumbnailPath,
    required String newThumbnailName,
  }) async {
    try {
      if (sourceThumbnailPath == null || sourceThumbnailPath.isEmpty) {
        return null;
      }

      final sourceFile = File(sourceThumbnailPath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final imagesDir = await getImagesDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '${imagesDir.path}/thumb_$timestamp.jpg';
      
      await sourceFile.copy(targetPath);
      return targetPath;
    } catch (e) {
      print('Error copying thumbnail: $e');
      return null;
    }
  }
}

