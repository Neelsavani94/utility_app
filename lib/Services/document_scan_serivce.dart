import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'database_helper.dart';

class DocumentScanService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Scan document and save all images
  Future<void> scanAndSaveDocument({
    required DocumentScanningResult result,
  }) async {
    try {
      if (result.images.isEmpty) {
        log('No images found in scan result');
        return;
      }

      log('Scanned images: ${result.images.toString()}');

      // Save all images to local storage
      final savedImagePaths = await _saveImagesToLocal(result.images);

      if (savedImagePaths.isEmpty) {
        log('Failed to save images');
        return;
      }

      // First image for group first image
      final firstImagePath = savedImagePaths[0];

      String finalFileName = firstImagePath.split("/").last;
      if (!firstImagePath.split("/").last.toLowerCase().endsWith('.jpg') &&
          !firstImagePath.split("/").last.toLowerCase().endsWith('.jpeg') &&
          !firstImagePath.split("/").last.toLowerCase().endsWith('.png')) {
        finalFileName = '${firstImagePath.split("/").last}.jpg';
      }

      // Create group name from filename
      final groupName = _getFileNameWithoutExtension(finalFileName);
      final date = DateTime.now().toString();

      // Create group table if not exists
      await _dbHelper.createDocTable(groupName);
      
      // Add group to alldocs table
      await _dbHelper.addGroup(
        groupName: groupName,
        groupDate: date,
        groupTag: '1', // Default tag
        groupFirstImg: firstImagePath,
      );

      log('Group created: $groupName');

      // Insert all images into the group table
      for (int i = 0; i < savedImagePaths.length; i++) {
        final imagePath = savedImagePaths[i];

        String finalAllFileName = imagePath.split("/").last;
        if (!imagePath.split("/").last.toLowerCase().endsWith('.jpg') &&
            !imagePath.split("/").last.toLowerCase().endsWith('.jpeg') &&
            !imagePath.split("/").last.toLowerCase().endsWith('.png')) {
          finalAllFileName = '${imagePath.split("/").last}.jpg';
        }

        final pageTitle = '${_getFileNameWithoutExtension(finalAllFileName)} - Page ${i + 1}';

        final docId = await _dbHelper.addGroupDoc(
          groupName: groupName,
          imgPath: imagePath,
          imgName: pageTitle,
          imgNote: '',
        );

        log('Document page inserted with ID: $docId for page ${i + 1}');
      }

      log('Successfully saved document with ${savedImagePaths.length} images');
    } catch (e) {
      log('Error in scanAndSaveDocument: $e');
      rethrow;
    }
  }

  /// Scan additional pages and attach them to an existing document
  ///
  /// This will ONLY create entries in the DocumentDetail table
  /// and will NOT create a new row in the Documents table.
  Future<void> scanAndAddPagesToDocument({
    required int documentId,
    required DocumentScanningResult result,
  }) async {
    try {
      if (result.images.isEmpty) {
        log('No images found in scan result');
        return;
      }

      // Get document to find its group name
      final document = await _dbHelper.getDocumentById(documentId);
      if (document == null) {
        log('Document with ID $documentId not found');
        return;
      }

      // Document title is the group name in new structure
      final groupName = document.title;

      // Save all images to local storage
      final savedImagePaths = await _saveImagesToLocal(result.images);
      if (savedImagePaths.isEmpty) {
        log('Failed to save images');
        return;
      }

      // Get current number of pages to continue page numbering
      final existingDocs = await _dbHelper.getGroupDocs(groupName);
      final existingCount = existingDocs.length;

      for (int i = 0; i < savedImagePaths.length; i++) {
        final imagePath = savedImagePaths[i];

        String finalAllFileName = imagePath.split("/").last;
        if (!imagePath.split("/").last.toLowerCase().endsWith('.jpg') &&
            !imagePath.split("/").last.toLowerCase().endsWith('.jpeg') &&
            !imagePath.split("/").last.toLowerCase().endsWith('.png')) {
          finalAllFileName = '${imagePath.split("/").last}.jpg';
        }

        final pageNumber = existingCount + i + 1;
        final pageTitle = '${_getFileNameWithoutExtension(finalAllFileName)} - Page $pageNumber';

        final docId = await _dbHelper.addGroupDoc(
          groupName: groupName,
          imgPath: imagePath,
          imgName: pageTitle,
          imgNote: '',
        );

        log(
          'Document page inserted with ID: $docId for existing group $groupName, page $pageNumber',
        );
      }

      log(
        'Successfully added ${savedImagePaths.length} pages to document $documentId',
      );
    } catch (e) {
      log('Error in scanAndAddPagesToDocument: $e');
      rethrow;
    }
  }

  /// Save scanned images to local storage
  Future<List<String>> _saveImagesToLocal(List<String> imagePaths) async {
    final List<String> savedPaths = [];

    try {
      // Get app directory for storing images
      final directory = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${directory.path}/documents');

      // Create directory if it doesn't exist
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }

      // Copy each image to local storage
      for (int i = 0; i < imagePaths.length; i++) {
        final originalFile = File(imagePaths[i]);

        if (await originalFile.exists()) {
          // Generate unique filename
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = path.extension(imagePaths[i]);
          final newFileName = 'doc_${timestamp}_$i$extension';
          final newPath = path.join(documentsDir.path, newFileName);

          // Copy file to new location
          final savedFile = await originalFile.copy(newPath);
          savedPaths.add(savedFile.path);

          log('Saved image ${i + 1}: $newPath');
        } else {
          log('Original file does not exist: ${imagePaths[i]}');
        }
      }
    } catch (e) {
      log('Error saving images to local: $e');
    }

    return savedPaths;
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
        log('No images to import');
        return;
      }

      log('Importing ${imageFiles.length} image(s)');

      // Save all images to local storage
      final savedImagePaths = await _saveImageFilesToLocal(imageFiles);

      if (savedImagePaths.isEmpty) {
        log('Failed to save images');
        return;
      }

      // First image for group first image
      final firstImagePath = savedImagePaths[0];

      String finalFileName = firstImagePath.split("/").last;
      if (!firstImagePath.split("/").last.toLowerCase().endsWith('.jpg') &&
          !firstImagePath.split("/").last.toLowerCase().endsWith('.jpeg') &&
          !firstImagePath.split("/").last.toLowerCase().endsWith('.png')) {
        finalFileName = '${firstImagePath.split("/").last}.jpg';
      }

      // Create group name from filename
      final groupName = _getFileNameWithoutExtension(finalFileName);
      final date = DateTime.now().toString();

      // Create group table if not exists
      await _dbHelper.createDocTable(groupName);
      
      // Add group to alldocs table
      await _dbHelper.addGroup(
        groupName: groupName,
        groupDate: date,
        groupTag: '1', // Default tag
        groupFirstImg: firstImagePath,
      );

      log('Group created: $groupName');

      // Insert all images into the group table
      for (int i = 0; i < savedImagePaths.length; i++) {
        final imagePath = savedImagePaths[i];

        String finalAllFileName = imagePath.split("/").last;
        if (!imagePath.split("/").last.toLowerCase().endsWith('.jpg') &&
            !imagePath.split("/").last.toLowerCase().endsWith('.jpeg') &&
            !imagePath.split("/").last.toLowerCase().endsWith('.png')) {
          finalAllFileName = '${imagePath.split("/").last}.jpg';
        }

        final pageTitle = '${_getFileNameWithoutExtension(finalAllFileName)} - Page ${i + 1}';

        final docId = await _dbHelper.addGroupDoc(
          groupName: groupName,
          imgPath: imagePath,
          imgName: pageTitle,
          imgNote: '',
        );

        log('Document page inserted with ID: $docId for page ${i + 1}');
      }

      log('Successfully imported and saved ${savedImagePaths.length} image(s)');
    } catch (e) {
      log('Error in importAndSaveImages: $e');
      rethrow;
    }
  }

  /// Save image files to local storage
  Future<List<String>> _saveImageFilesToLocal(List<File> imageFiles) async {
    final List<String> savedPaths = [];

    try {
      // Get app directory for storing images
      final directory = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${directory.path}/documents');

      // Create directory if it doesn't exist
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }

      // Copy each image to local storage
      for (int i = 0; i < imageFiles.length; i++) {
        final originalFile = imageFiles[i];

        if (await originalFile.exists()) {
          // Generate unique filename
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = path.extension(originalFile.path);
          final newFileName = 'imported_${timestamp}_$i${extension.isEmpty ? '.jpg' : extension}';
          final newPath = path.join(documentsDir.path, newFileName);

          // Copy file to new location
          final savedFile = await originalFile.copy(newPath);
          savedPaths.add(savedFile.path);

          log('Saved imported image ${i + 1}: $newPath');
        } else {
          log('Original file does not exist: ${originalFile.path}');
        }
      }
    } catch (e) {
      log('Error saving imported images to local: $e');
    }

    return savedPaths;
  }

  /// Save edited image to database (similar to scanAndSaveDocument flow)
  Future<void> saveEditedImage({
    required Uint8List imageBytes,
    required String originalFileName,
  }) async {
    try {
      // Save image to local storage
      final directory = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${directory.path}/documents');

      // Create directory if it doesn't exist
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(originalFileName);
      final newFileName = 'edited_${timestamp}${extension.isEmpty ? '.jpg' : extension}';
      final imagePath = path.join(documentsDir.path, newFileName);

      // Save image bytes to file
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);

      log('Saved edited image: $imagePath');

      String finalFileName = imagePath.split("/").last;
      if (!imagePath.split("/").last.toLowerCase().endsWith('.jpg') &&
          !imagePath.split("/").last.toLowerCase().endsWith('.jpeg') &&
          !imagePath.split("/").last.toLowerCase().endsWith('.png')) {
        finalFileName = '${imagePath.split("/").last}.jpg';
      }

      // Create group name from filename
      final groupName = _getFileNameWithoutExtension(finalFileName);
      final date = DateTime.now().toString();

      // Create group table if not exists
      await _dbHelper.createDocTable(groupName);
      
      // Add group to alldocs table
      await _dbHelper.addGroup(
        groupName: groupName,
        groupDate: date,
        groupTag: '1', // Default tag
        groupFirstImg: imagePath,
      );

      log('Group created: $groupName');

      // Insert image into the group table
      final pageTitle = '${_getFileNameWithoutExtension(finalFileName)} - Page 1';
      final docId = await _dbHelper.addGroupDoc(
        groupName: groupName,
        imgPath: imagePath,
        imgName: pageTitle,
        imgNote: '',
      );

      log('Document page inserted with ID: $docId');

      log('Successfully saved edited image');
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