import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:path/path.dart' as path;
import 'database_helper.dart';
import 'file_storage_service.dart';

class DocumentScanService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Scan document and save all images using FileStorageService
  Future<void> scanAndSaveDocument({
    required DocumentScanningResult result,
  }) async {
    try {
      if (result.images.isEmpty) {
        log('No images found in scan result');
        return;
      }

      log('Scanned images: ${result.images.toString()}');

      // Use FileStorageService to save images and create database entries
      final fileStorageService = FileStorageService.instance;
      int successCount = 0;

      for (int i = 0; i < result.images.length; i++) {
        try {
          final imagePath = result.images[i];
          final imageFile = File(imagePath);

          if (!await imageFile.exists()) {
            log('Image file does not exist: $imagePath');
            continue;
          }

          // Read image bytes
          final imageBytes = await imageFile.readAsBytes();
          
          // Generate filename
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'scanned_${timestamp}_$i.jpg';
          final title = 'Scanned Document ${i + 1}';

          // Save using FileStorageService
          final docId = await fileStorageService.saveImageFile(
            imageBytes: imageBytes,
            fileName: fileName,
            title: title,
          );

          if (docId != null) {
            successCount++;
            log('Saved scanned image ${i + 1}/${result.images.length} with ID: $docId');
          } else {
            log('Failed to save scanned image ${i + 1} to database');
          }
        } catch (e) {
          log('Error saving scanned image ${i + 1}: $e');
        }
      }

      log('Successfully saved ${successCount}/${result.images.length} scanned images');
      
      if (successCount == 0) {
        throw Exception('Failed to save any scanned images');
      }
    } catch (e) {
      log('Error in scanAndSaveDocument: $e');
      rethrow;
    }
  }

  /// Scan additional pages and save as new documents using FileStorageService
  Future<void> scanAndAddPagesToDocument({
    required int documentId,
    required DocumentScanningResult result,
  }) async {
    try {
      if (result.images.isEmpty) {
        log('No images found in scan result');
        return;
      }

      // Get document to get context (optional, for naming)
      final document = await _dbHelper.getDocumentById(documentId);
      final baseTitle = document?.title ?? 'Scanned Document';

      // Use FileStorageService to save images and create database entries
      final fileStorageService = FileStorageService.instance;
      int successCount = 0;

      for (int i = 0; i < result.images.length; i++) {
        try {
          final imagePath = result.images[i];
          final imageFile = File(imagePath);

          if (!await imageFile.exists()) {
            log('Image file does not exist: $imagePath');
            continue;
          }

          // Read image bytes
          final imageBytes = await imageFile.readAsBytes();
          
          // Generate filename
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'scanned_${timestamp}_$i.jpg';
          final title = '$baseTitle - Page ${i + 1}';

          // Save using FileStorageService
          final docId = await fileStorageService.saveImageFile(
            imageBytes: imageBytes,
            fileName: fileName,
            title: title,
          );

          if (docId != null) {
            successCount++;
            log('Saved additional page ${i + 1}/${result.images.length} with ID: $docId');
          } else {
            log('Failed to save additional page ${i + 1} to database');
          }
        } catch (e) {
          log('Error saving additional page ${i + 1}: $e');
        }
      }

      log('Successfully saved ${successCount}/${result.images.length} additional pages');
      
      if (successCount == 0) {
        throw Exception('Failed to save any additional pages');
      }
    } catch (e) {
      log('Error in scanAndAddPagesToDocument: $e');
      rethrow;
    }
  }



  /// Delete document and all its images
  Future<void> deleteDocumentWithImages(int documentId) async {
    try {
      // Get document and its details
      final document = await _dbHelper.getDocumentById(documentId);
      final details = await _dbHelper.getDocumentDetailsByDocumentId(documentId);

      // Delete image files
      if (document != null) {
        await _deleteImageFile(document.imagePath);
        if (document.thumbnailPath != null) {
          await _deleteImageFile(document.thumbnailPath!);
        }
      }

      // Delete detail image files
      for (final detail in details) {
        await _deleteImageFile(detail.imagePath);
        if (detail.thumbnailPath != null) {
          await _deleteImageFile(detail.thumbnailPath!);
        }
      }

      // Delete from database (CASCADE will handle DocumentDetail)
      await _dbHelper.deleteDocument(documentId);
      log('Document and all images deleted successfully');
    } catch (e) {
      log('Error deleting document with images: $e');
      rethrow;
    }
  }

  /// Delete a single image file
  Future<void> _deleteImageFile(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        log('Deleted file: $imagePath');
      }
    } catch (e) {
      log('Error deleting file $imagePath: $e');
    }
  }

  /// Import images from files and save to database (similar to scanAndSaveDocument flow)
  Future<void> importAndSaveImages({
    required List<File> imageFiles,
  }) async {
    try {
      if (imageFiles.isEmpty) {
        log('No files to import');
        return;
      }

      log('Importing ${imageFiles.length} file(s)');

      // Use FileStorageService to properly save files and create database entries
      final fileStorageService = FileStorageService.instance;
      int successCount = 0;
      int failureCount = 0;

      for (int i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];
        
        if (!await file.exists()) {
          log('File does not exist: ${file.path}');
          failureCount++;
          continue;
        }

        try {
          // Get file extension to determine type
          final extension = path.extension(file.path).toLowerCase();
          final fileName = file.path.split('/').last;
          final fileNameWithoutExt = _getFileNameWithoutExtension(fileName);

          // Read file bytes
          final fileBytes = await file.readAsBytes();

          int? docId;

          // Determine file type and save accordingly
          if (extension == '.pdf') {
            // Save PDF file
            docId = await fileStorageService.savePDFFile(
              pdfBytes: fileBytes,
              fileName: fileName,
              title: fileNameWithoutExt,
            );
            log('Saved PDF file: $fileName with ID: $docId');
          } else if (['.jpg', '.jpeg', '.png', '.bmp', '.webp', '.heic'].contains(extension)) {
            // Save image file
            docId = await fileStorageService.saveImageFile(
              imageBytes: fileBytes,
              fileName: fileName,
              title: fileNameWithoutExt,
            );
            log('Saved image file: $fileName with ID: $docId');
          } else {
            log('Unsupported file type: $extension for file: $fileName');
            failureCount++;
            continue;
          }

          if (docId != null) {
            successCount++;
            log('Successfully imported file ${i + 1}/${imageFiles.length}: $fileName (ID: $docId)');
          } else {
            failureCount++;
            log('Failed to save file to database: $fileName');
          }
        } catch (e) {
          failureCount++;
          log('Error importing file ${file.path}: $e');
        }
      }

      log('Import completed: $successCount successful, $failureCount failed');

      if (successCount == 0 && failureCount > 0) {
        throw Exception('Failed to import any files. Please check file formats.');
      }
    } catch (e) {
      log('Error in importAndSaveImages: $e');
      rethrow;
    }
  }


  /// Save edited image using FileStorageService
  Future<void> saveEditedImage({
    required Uint8List imageBytes,
    required String originalFileName,
  }) async {
    try {
      // Use FileStorageService to save image and create database entry
      final fileStorageService = FileStorageService.instance;
      
      // Generate filename from original
      final fileNameWithoutExt = _getFileNameWithoutExtension(originalFileName);
      final extension = path.extension(originalFileName);
      final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}${extension.isEmpty ? '.jpg' : extension}';
      final title = 'Edited $fileNameWithoutExt';

      // Save using FileStorageService
      final docId = await fileStorageService.saveImageFile(
        imageBytes: imageBytes,
        fileName: fileName,
        title: title,
      );

      if (docId != null) {
        log('Successfully saved edited image with ID: $docId');
      } else {
        throw Exception('Failed to save edited image to database');
      }
    } catch (e) {
      log('Error in saveEditedImage: $e');
      rethrow;
    }
  }

  /// Helper to get filename without extension
  String _getFileNameWithoutExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.sublist(0, parts.length - 1).join('.');
    }
    return fileName;
  }
}