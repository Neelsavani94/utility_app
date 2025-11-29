// Example usage of DatabaseHelper
// This file shows how to use the database in your app

import '../Models/tag_model.dart';
import '../Models/document_model.dart';
import 'database_helper.dart';

class DatabaseExample {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ==================== Tag Examples ====================

  // Create a new tag
  Future<int> createTag(String title) async {
    final tag = Tag(title: title);
    return await _db.insertTag(tag);
  }

  // Get all tags
  Future<List<Tag>> getAllTags() async {
    return await _db.getAllTags();
  }

  // Get a tag by ID
  Future<Tag?> getTag(int id) async {
    return await _db.getTagById(id);
  }

  // Update a tag
  Future<int> updateTag(Tag tag) async {
    return await _db.updateTag(tag);
  }

  // Delete a tag
  Future<int> deleteTag(int id) async {
    return await _db.deleteTag(id);
  }

  // ==================== Document Examples ====================

  // Create a new document
  Future<int> createDocument({
    required String title,
    required String type,
    required String imagePath,
    String? thumbnailPath,
    int? tagId,
    bool isFavourite = false,
  }) async {
    final document = Document(
      title: title,
      type: type,
      imagePath: imagePath,
      thumbnailPath: thumbnailPath,
      tagId: tagId,
      isFavourite: isFavourite,
    );
    return await _db.insertDocument(document);
  }

  // Get all documents
  Future<List<Document>> getAllDocuments() async {
    return await _db.getAllDocuments();
  }

  // Get documents by tag
  Future<List<Document>> getDocumentsByTag(int? tagId) async {
    return await _db.getDocumentsByTagId(tagId);
  }

  // Get favourite documents
  Future<List<Document>> getFavouriteDocuments() async {
    return await _db.getFavouriteDocuments();
  }

  // Get documents by type
  Future<List<Document>> getDocumentsByType(String type) async {
    return await _db.getDocumentsByType(type);
  }

  // Get a document by ID
  Future<Document?> getDocument(int id) async {
    return await _db.getDocumentById(id);
  }

  // Update a document
  Future<int> updateDocument(Document document) async {
    return await _db.updateDocument(document);
  }

  // Delete a document
  Future<int> deleteDocument(int id) async {
    return await _db.deleteDocument(id);
  }

  // Toggle favourite status
  Future<int> toggleFavourite(int id, bool isFavourite) async {
    return await _db.toggleFavourite(id, isFavourite);
  }

  // Search documents
  Future<List<Document>> searchDocuments(String query) async {
    return await _db.searchDocuments(query);
  }

  // ==================== Statistics ====================

  Future<Map<String, int>> getStatistics() async {
    return {
      'totalDocuments': await _db.getDocumentCount(),
      'totalTags': await _db.getTagCount(),
      'favouriteDocuments': await _db.getFavouriteCount(),
    };
  }
}

