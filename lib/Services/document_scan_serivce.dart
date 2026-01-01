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
  /// IMPORTANT: Every scan saves to BOTH Document table AND DocumentDetail table
  /// 
  /// Logic:
  /// - Single image: Store data in both Document Table & DocumentDetail Table
  /// - Multiple images: First image data stored in Document Table, all images stored in DocumentDetail Table
  Future<void> scanAndSaveDocument({
    required DocumentScanningResult result,
  }) async {
    try {
      if (result.images.isEmpty) {
        log('No images found in scan result');
        return;
      }

      final fileStorageService = FileStorageService.instance;
      final imagesDir = await fileStorageService.getImagesDirectory();
      final baseTimestamp = DateTime.now();
      int? documentId;
      String? baseTitle;

      // Check if single or multiple images
      final isSingleImage = result.images.length == 1;

      if (isSingleImage) {
        // Single image: Store in both Document and DocumentDetail tables
        final imagePath = result.images[0];
        final imageFile = File(imagePath);

        if (!await imageFile.exists()) {
          log('Image file does not exist: $imagePath');
          throw Exception('Image file does not exist');
        }

        // Read image bytes
        final imageBytes = await imageFile.readAsBytes();
        
        // Save image file
        final fileTimestamp = baseTimestamp;
        final fileTimestampMs = fileTimestamp.millisecondsSinceEpoch;
        final savedFilePath = '${imagesDir.path}/img_${fileTimestampMs}.jpg';
        
        final file = File(savedFilePath);
        await file.writeAsBytes(imageBytes);
        
        // Generate thumbnail
        String? savedThumbnailPath;
        final thumbnailBytes = await fileStorageService.generateImageThumbnail(imageBytes);
        if (thumbnailBytes != null) {
          savedThumbnailPath = '${imagesDir.path}/thumb_${fileTimestampMs}.jpg';
          final thumbFile = File(savedThumbnailPath);
          await thumbFile.writeAsBytes(thumbnailBytes);
        }

        // Create title
        baseTitle = 'Scanned Document ${fileTimestampMs}';

        // Save to Document table
        final documentMap = {
          'title': baseTitle,
          'type': 'image',
          'Image_path': savedFilePath,
          'image_thumbnail': savedThumbnailPath,
          'created_date': fileTimestamp.toIso8601String(),
          'updated_date': fileTimestamp.toIso8601String(),
          'favourite': 0,
          'is_deleted': 0,
        };
        
        documentId = await _dbHelper.createDocument(documentMap);
        log('✓ Saved single image to Document table with ID: $documentId');

        // Save to DocumentDetail table
        final documentDetailMap = {
          'document_id': documentId,
          'title': baseTitle,
          'type': 'image',
          'Image_path': savedFilePath,
          'image_thumbnail': savedThumbnailPath,
          'created_date': fileTimestamp.toIso8601String(),
          'updated_date': fileTimestamp.toIso8601String(),
          'favourite': 0,
          'is_deleted': 0,
        };
        
        await _dbHelper.createDocumentDetail(documentDetailMap);
        log('✓ Saved single image to DocumentDetail table');
      } else {
        // Multiple images: First image in Document table, all images in DocumentDetail table
        int successCount = 0;

        // Process first image for Document table
        final firstImagePath = result.images[0];
        final firstImageFile = File(firstImagePath);

        if (!await firstImageFile.exists()) {
          log('First image file does not exist: $firstImagePath');
          throw Exception('First image file does not exist');
        }

        // Read first image bytes
        final firstImageBytes = await firstImageFile.readAsBytes();
        
        // Save first image file
        final firstFileTimestamp = baseTimestamp;
        final firstFileTimestampMs = firstFileTimestamp.millisecondsSinceEpoch;
        final firstSavedFilePath = '${imagesDir.path}/img_${firstFileTimestampMs}.jpg';
        
        final firstFile = File(firstSavedFilePath);
        await firstFile.writeAsBytes(firstImageBytes);
        
        // Generate thumbnail for first image
        String? firstSavedThumbnailPath;
        final firstThumbnailBytes = await fileStorageService.generateImageThumbnail(firstImageBytes);
        if (firstThumbnailBytes != null) {
          firstSavedThumbnailPath = '${imagesDir.path}/thumb_${firstFileTimestampMs}.jpg';
          final firstThumbFile = File(firstSavedThumbnailPath);
          await firstThumbFile.writeAsBytes(firstThumbnailBytes);
        }

        // Create title for document
        baseTitle = 'Scanned Document ${firstFileTimestampMs}';

        // Save first image to Document table
        final documentMap = {
          'title': baseTitle,
          'type': 'image',
          'Image_path': firstSavedFilePath,
          'image_thumbnail': firstSavedThumbnailPath,
          'created_date': firstFileTimestamp.toIso8601String(),
          'updated_date': firstFileTimestamp.toIso8601String(),
          'favourite': 0,
          'is_deleted': 0,
        };
        
        documentId = await _dbHelper.createDocument(documentMap);
        log('✓ Saved first image to Document table with ID: $documentId');

        // Process all images for DocumentDetail table
        for (int i = 0; i < result.images.length; i++) {
          try {
            String savedFilePath;
            String? savedThumbnailPath;
            final fileTimestamp = baseTimestamp.add(Duration(milliseconds: i));

            if (i == 0) {
              // Reuse the first image file that was already saved to Document table
              savedFilePath = firstSavedFilePath;
              savedThumbnailPath = firstSavedThumbnailPath;
            } else {
              // Process remaining images
              final imagePath = result.images[i];
              final imageFile = File(imagePath);

              if (!await imageFile.exists()) {
                log('Image file does not exist: $imagePath');
                continue;
              }

              // Read image bytes
              final imageBytes = await imageFile.readAsBytes();
              
              // Save image file
              final fileTimestampMs = fileTimestamp.millisecondsSinceEpoch;
              savedFilePath = '${imagesDir.path}/img_${fileTimestampMs}_${i}.jpg';
              
              final file = File(savedFilePath);
              await file.writeAsBytes(imageBytes);
              
              // Generate thumbnail
              final thumbnailBytes = await fileStorageService.generateImageThumbnail(imageBytes);
              if (thumbnailBytes != null) {
                savedThumbnailPath = '${imagesDir.path}/thumb_${fileTimestampMs}_${i}.jpg';
                final thumbFile = File(savedThumbnailPath);
                await thumbFile.writeAsBytes(thumbnailBytes);
              }
            }

            // Create DocumentDetail entry
            final documentDetailMap = {
              'document_id': documentId,
              'title': '$baseTitle - Page ${i + 1}',
              'type': 'image',
              'Image_path': savedFilePath,
              'image_thumbnail': savedThumbnailPath,
              'created_date': fileTimestamp.toIso8601String(),
              'updated_date': fileTimestamp.toIso8601String(),
              'favourite': 0,
              'is_deleted': 0,
            };
            
            await _dbHelper.createDocumentDetail(documentDetailMap);
            successCount++;
            log('✓ Saved image ${i + 1}/${result.images.length} to DocumentDetail table');
          } catch (e) {
            log('Error saving image ${i + 1}: $e');
          }
        }

        log('Successfully saved ${successCount}/${result.images.length} images to DocumentDetail table');
        
        if (successCount == 0) {
          throw Exception('Failed to save any images to DocumentDetail table');
        }
      }

      log('Successfully completed scanAndSaveDocument');
    } catch (e) {
      log('Error in scanAndSaveDocument: $e');
      rethrow;
    }
  }
  
  /// Scan additional pages and save to DocumentDetail table
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
      final document = await _dbHelper.getDocument(documentId);
      final baseTitle = document?['title']?.toString() ?? 'Scanned Document';

      final fileStorageService = FileStorageService.instance;
      final imagesDir = await fileStorageService.getImagesDirectory();
      final baseTimestamp = DateTime.now();
      int successCount = 0;

      // Get existing DocumentDetail count to determine next index
      final existingDetails = await _dbHelper.getDocumentDetailsByDocumentId(documentId);
      final nextIndex = existingDetails.length;

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
          
          // Save image file
          final fileTimestamp = baseTimestamp.add(Duration(milliseconds: i));
          final fileTimestampMs = fileTimestamp.millisecondsSinceEpoch;
          final savedFilePath = '${imagesDir.path}/img_${fileTimestampMs}_${nextIndex + i}.jpg';
          
          final file = File(savedFilePath);
          await file.writeAsBytes(imageBytes);
          
          // Generate thumbnail
          String? savedThumbnailPath;
          final thumbnailBytes = await fileStorageService.generateImageThumbnail(imageBytes);
          if (thumbnailBytes != null) {
            savedThumbnailPath = '${imagesDir.path}/thumb_${fileTimestampMs}_${nextIndex + i}.jpg';
            final thumbFile = File(savedThumbnailPath);
            await thumbFile.writeAsBytes(thumbnailBytes);
          }

          // Create DocumentDetail entry
          final documentDetailMap = {
            'document_id': documentId,
            'title': '$baseTitle - Page ${nextIndex + i + 1}',
            'type': 'image',
            'Image_path': savedFilePath,
            'image_thumbnail': savedThumbnailPath,
            'created_date': fileTimestamp.toIso8601String(),
            'updated_date': fileTimestamp.toIso8601String(),
            'favourite': 0,
            'is_deleted': 0,
          };
          
          await _dbHelper.createDocumentDetail(documentDetailMap);
          successCount++;
          log('✓ Saved additional page ${i + 1}/${result.images.length} to DocumentDetail table');
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
      final document = await _dbHelper.getDocument(documentId);
      final details = await _dbHelper.getDocumentDetailsByDocumentId(documentId);

      // Delete image files from Document table
      if (document != null) {
        final imagePath = document['Image_path']?.toString();
        final thumbnailPath = document['image_thumbnail']?.toString();
        
        if (imagePath != null && imagePath.isNotEmpty) {
          await _deleteImageFile(imagePath);
        }
        if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
          await _deleteImageFile(thumbnailPath);
        }
      }

      // Delete detail image files from DocumentDetail table
      for (final detail in details) {
        final imagePath = detail['Image_path']?.toString();
        final thumbnailPath = detail['image_thumbnail']?.toString();
        
        if (imagePath != null && imagePath.isNotEmpty) {
          await _deleteImageFile(imagePath);
        }
        if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
          await _deleteImageFile(thumbnailPath);
        }
      }

      // Delete from database
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

  /// Save edited image to DocumentDetail table for an existing document
  Future<void> saveEditedImageToDocumentDetail({
    required int documentId,
    required Uint8List imageBytes,
    required String originalFileName,
  }) async {
    try {
      final fileStorageService = FileStorageService.instance;
      final imagesDir = await fileStorageService.getImagesDirectory();
      final fileTimestamp = DateTime.now();
      final fileTimestampMs = fileTimestamp.millisecondsSinceEpoch;

      // Get document to get context (for naming)
      final document = await _dbHelper.getDocument(documentId);
      final baseTitle = document?['title']?.toString() ?? 'Scanned Document';

      // Get existing DocumentDetail count to determine next index
      final existingDetails = await _dbHelper.getDocumentDetailsByDocumentId(documentId);
      final nextIndex = existingDetails.length;

      // Generate filename
      final extension = path.extension(originalFileName);
      final fileName = 'img_${fileTimestampMs}_${nextIndex}${extension.isEmpty ? '.jpg' : extension}';
      final savedFilePath = '${imagesDir.path}/$fileName';

      // Save image file
      final file = File(savedFilePath);
      await file.writeAsBytes(imageBytes);

      // Generate thumbnail
      String? savedThumbnailPath;
      final thumbnailBytes = await fileStorageService.generateImageThumbnail(imageBytes);
      if (thumbnailBytes != null) {
        savedThumbnailPath = '${imagesDir.path}/thumb_${fileTimestampMs}_${nextIndex}.jpg';
        final thumbFile = File(savedThumbnailPath);
        await thumbFile.writeAsBytes(thumbnailBytes);
      }

      // Create DocumentDetail entry
      final documentDetailMap = {
        'document_id': documentId,
        'title': '$baseTitle - Page ${nextIndex + 1}',
        'type': 'image',
        'Image_path': savedFilePath,
        'image_thumbnail': savedThumbnailPath,
        'created_date': fileTimestamp.toIso8601String(),
        'updated_date': fileTimestamp.toIso8601String(),
        'favourite': 0,
        'is_deleted': 0,
      };

      await _dbHelper.createDocumentDetail(documentDetailMap);
      log('✓ Saved edited image to DocumentDetail table for document ID: $documentId');
    } catch (e) {
      log('Error in saveEditedImageToDocumentDetail: $e');
      rethrow;
    }
  }

  /// Update existing DocumentDetail entry with edited image
  Future<void> updateEditedImageInDocumentDetail({
    required int documentDetailId,
    required Uint8List imageBytes,
    required String originalFileName,
  }) async {
    try {
      // Get existing document detail to preserve metadata
      final existingDetail = await _dbHelper.getDocumentDetail(documentDetailId);
      if (existingDetail == null) {
        throw Exception('Document detail not found with ID: $documentDetailId');
      }

      final fileStorageService = FileStorageService.instance;
      final imagesDir = await fileStorageService.getImagesDirectory();
      final fileTimestamp = DateTime.now();
      final fileTimestampMs = fileTimestamp.millisecondsSinceEpoch;

      // Delete old image files if they exist
      final oldImagePath = existingDetail['Image_path']?.toString();
      final oldThumbnailPath = existingDetail['image_thumbnail']?.toString();
      
      if (oldImagePath != null && oldImagePath.isNotEmpty) {
        try {
          final oldFile = File(oldImagePath);
          if (await oldFile.exists()) {
            await oldFile.delete();
            log('Deleted old image file: $oldImagePath');
          }
        } catch (e) {
          log('Error deleting old image file: $e');
        }
      }
      
      if (oldThumbnailPath != null && oldThumbnailPath.isNotEmpty) {
        try {
          final oldThumbFile = File(oldThumbnailPath);
          if (await oldThumbFile.exists()) {
            await oldThumbFile.delete();
            log('Deleted old thumbnail file: $oldThumbnailPath');
          }
        } catch (e) {
          log('Error deleting old thumbnail file: $e');
        }
      }

      // Generate new filename
      final extension = path.extension(originalFileName);
      final fileName = 'img_${fileTimestampMs}${extension.isEmpty ? '.jpg' : extension}';
      final savedFilePath = '${imagesDir.path}/$fileName';

      // Save new image file
      final file = File(savedFilePath);
      await file.writeAsBytes(imageBytes);

      // Generate new thumbnail
      String? savedThumbnailPath;
      final thumbnailBytes = await fileStorageService.generateImageThumbnail(imageBytes);
      if (thumbnailBytes != null) {
        savedThumbnailPath = '${imagesDir.path}/thumb_${fileTimestampMs}.jpg';
        final thumbFile = File(savedThumbnailPath);
        await thumbFile.writeAsBytes(thumbnailBytes);
      }

      // Update DocumentDetail entry (preserve existing metadata like title, document_id, created_date, etc.)
      final documentDetailMap = {
        'Image_path': savedFilePath,
        'image_thumbnail': savedThumbnailPath,
        'updated_date': fileTimestamp.toIso8601String(),
        // Preserve other fields from existing detail
        'document_id': existingDetail['document_id'],
        'title': existingDetail['title'],
        'type': existingDetail['type'] ?? 'image',
        'favourite': existingDetail['favourite'] ?? 0,
        'is_deleted': existingDetail['is_deleted'] ?? 0,
        'created_date': existingDetail['created_date'], // Preserve original creation date
      };

      await _dbHelper.updateDocumentDetail(documentDetailId, documentDetailMap);
      log('✓ Updated DocumentDetail entry with ID: $documentDetailId');
    } catch (e) {
      log('Error in updateEditedImageInDocumentDetail: $e');
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