import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../Models/document_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('utility_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
    
    // Initialize default tags after database is opened
    await _initializeDefaultTags(db);
    
    return db;
  }

  Future<void> _createDB(Database db, int version) async {
    // Create Tags table
    await db.execute('''
      CREATE TABLE Tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_date TEXT NOT NULL,
        updated_date TEXT NOT NULL,
        title TEXT NOT NULL,
        default_tag INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create Document table
    await db.execute('''
      CREATE TABLE Document (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_date TEXT NOT NULL,
        updated_date TEXT NOT NULL,
        type TEXT NOT NULL,
        favourite INTEGER NOT NULL DEFAULT 0,
        Image_path TEXT,
        image_thumbnail TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create DocumentDetail table
    await db.execute('''
      CREATE TABLE DocumentDetail (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        created_date TEXT NOT NULL,
        updated_date TEXT NOT NULL,
        type TEXT NOT NULL,
        favourite INTEGER NOT NULL DEFAULT 0,
        Image_path TEXT,
        image_thumbnail TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (document_id) REFERENCES Document(id)
      )
    ''');

    // Create TrashDocuments table
    await db.execute('''
      CREATE TABLE TrashDocuments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        created_date TEXT NOT NULL,
        updated_date TEXT NOT NULL,
        Image_path TEXT,
        image_thumbnail TEXT,
        FOREIGN KEY (document_id) REFERENCES Document(id)
      )
    ''');

    // Create FavouriteDocuments table
    await db.execute('''
      CREATE TABLE FavouriteDocuments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        created_date TEXT NOT NULL,
        updated_date TEXT NOT NULL,
        Image_path TEXT,
        image_thumbnail TEXT,
        FOREIGN KEY (document_id) REFERENCES Document(id)
      )
    ''');

    // Create ImportDocument table
    await db.execute('''
      CREATE TABLE ImportDocument (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        image_path TEXT,
        image_thumbnail TEXT,
        created_date TEXT NOT NULL,
        updated_date TEXT NOT NULL
      )
    ''');
  }

  /// Initialize default tags in the database
  Future<void> _initializeDefaultTags(Database db) async {
    try {
      final defaultTags = [
        'All Docs',
        'Business Card',
        'Id Card',
        'Academic',
        'Personal',
      ];

      final now = DateTime.now().toIso8601String();

      for (final tagTitle in defaultTags) {
        // Check if tag already exists
        final existingTag = await db.query(
          'Tags',
          where: 'title = ?',
          whereArgs: [tagTitle],
        );

        // Only insert if tag doesn't exist
        if (existingTag.isEmpty) {
          await db.insert('Tags', {
            'title': tagTitle,
            'created_date': now,
            'updated_date': now,
            'default_tag': 1, // Mark as default tag
          });
        }
      }
    } catch (e) {
      print('Error initializing default tags: $e');
    }
  }

  // ==================== Tags CRUD Operations ====================

  Future<int> createTag(Map<String, dynamic> tag) async {
    final db = await database;
    return await db.insert('Tags', tag);
  }

  Future<List<Map<String, dynamic>>> getAllTags() async {
    final db = await database;
    // Sort by default_tag DESC first (default tags first), then by created_date DESC
    return await db.query('Tags', orderBy: 'default_tag DESC, created_date DESC');
  }

  Future<Map<String, dynamic>?> getTag(int id) async {
    final db = await database;
    final result = await db.query(
      'Tags',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateTag(int id, Map<String, dynamic> tag) async {
    final db = await database;
    return await db.update(
      'Tags',
      tag,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTag(int id) async {
    final db = await database;
    return await db.delete(
      'Tags',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getDefaultTags() async {
    final db = await database;
    return await db.query(
      'Tags',
      where: 'default_tag = ?',
      whereArgs: [1],
      orderBy: 'created_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getNonDefaultTags() async {
    final db = await database;
    return await db.query(
      'Tags',
      where: 'default_tag = ?',
      whereArgs: [0],
      orderBy: 'created_date DESC',
    );
  }

  Future<int> setTagAsDefault(int id) async {
    final db = await database;
    return await db.update(
      'Tags',
      {
        'default_tag': 1,
        'updated_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> unsetTagAsDefault(int id) async {
    final db = await database;
    return await db.update(
      'Tags',
      {
        'default_tag': 0,
        'updated_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> findTagByTitle(String title) async {
    final db = await database;
    final result = await db.query(
      'Tags',
      where: 'title = ?',
      whereArgs: [title],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // ==================== Document CRUD Operations ====================

  Future<int> createDocument(Map<String, dynamic> document) async {
    final db = await database;
    return await db.insert('Document', document);
  }

  /// Insert a Document object into the database
  /// Checks for duplicate dates to prevent storing same date multiple times
  Future<int?> insertDocument(Document document) async {
    try {
      final db = await database;
      
      // Normalize date to just year-month-day for comparison
      final documentDate = DateTime(
        document.createdAt.year,
        document.createdAt.month,
        document.createdAt.day,
      );
      
      // Check if a document with the same date and title already exists
      final existingDocs = await db.query(
        'Document',
        where: 'is_deleted = ? AND title = ?',
        whereArgs: [0, document.title],
      );
      
      // Check for documents with the same date (year-month-day) and title
      for (var existingDoc in existingDocs) {
        if (existingDoc['created_date'] != null) {
          try {
            final existingDate = DateTime.parse(existingDoc['created_date'] as String);
            final existingDateNormalized = DateTime(
              existingDate.year,
              existingDate.month,
              existingDate.day,
            );
            
            // If same date and title found, update the existing document instead of creating new one
            if (existingDateNormalized.year == documentDate.year &&
                existingDateNormalized.month == documentDate.month &&
                existingDateNormalized.day == documentDate.day) {
              // Update existing document
              final existingId = existingDoc['id'] as int;
              final documentMap = document.toMap();
              // Map Document model fields to database fields
              final dbMap = {
                'title': documentMap['title'],
                'created_date': documentMap['created_at'],
                'updated_date': DateTime.now().toIso8601String(),
                'type': documentMap['type'],
                'favourite': documentMap['isFavourite'],
                'Image_path': documentMap['imagePath'],
                'image_thumbnail': documentMap['thumbnailPath'],
                'is_deleted': documentMap['isDeleted'],
              };
              
              await db.update(
                'Document',
                dbMap,
                where: 'id = ?',
                whereArgs: [existingId],
              );
              
              return existingId;
            }
          } catch (e) {
            // Skip invalid date formats
            continue;
          }
        }
      }
      
      // No duplicate date found, insert new document
      final documentMap = document.toMap();
      // Map Document model fields to database fields
      final dbMap = {
        'title': documentMap['title'],
        'created_date': documentMap['created_at'],
        'updated_date': documentMap['updated_at'],
        'type': documentMap['type'],
        'favourite': documentMap['isFavourite'],
        'Image_path': documentMap['imagePath'],
        'image_thumbnail': documentMap['thumbnailPath'],
        'is_deleted': documentMap['isDeleted'],
      };
      
      return await db.insert('Document', dbMap);
    } catch (e) {
      print('Error inserting document: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllDocuments() async {
    final db = await database;
    return await db.query('Document', orderBy: 'created_date DESC');
  }

  Future<List<Map<String, dynamic>>> getDocumentsNotDeleted() async {
    final db = await database;
    return await db.query(
      'Document',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getFavouriteDocuments() async {
    final db = await database;
    return await db.query(
      'Document',
      where: 'favourite = ? AND is_deleted = ?',
      whereArgs: [1, 0],
      orderBy: 'created_date DESC',
    );
  }

  Future<Map<String, dynamic>?> getDocument(int id) async {
    final db = await database;
    final result = await db.query(
      'Document',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateDocument(int id, Map<String, dynamic> document) async {
    final db = await database;
    return await db.update(
      'Document',
      document,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDocument(int id) async {
    final db = await database;
    return await db.delete(
      'Document',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> softDeleteDocument(int id) async {
    final db = await database;
    return await db.update(
      'Document',
      {'is_deleted': 1, 'updated_date': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== DocumentDetail CRUD Operations ====================

  Future<int> createDocumentDetail(Map<String, dynamic> documentDetail) async {
    final db = await database;
    return await db.insert('DocumentDetail', documentDetail);
  }

  Future<List<Map<String, dynamic>>> getAllDocumentDetails() async {
    final db = await database;
    return await db.query('DocumentDetail', orderBy: 'created_date DESC');
  }

  Future<List<Map<String, dynamic>>> getDocumentDetailsNotDeleted() async {
    final db = await database;
    return await db.query(
      'DocumentDetail',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getFavouriteDocumentDetails() async {
    final db = await database;
    return await db.query(
      'DocumentDetail',
      where: 'favourite = ? AND is_deleted = ?',
      whereArgs: [1, 0],
      orderBy: 'created_date DESC',
    );
  }

  Future<Map<String, dynamic>?> getDocumentDetail(int id) async {
    final db = await database;
    final result = await db.query(
      'DocumentDetail',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getDocumentDetailsByDocumentId(int documentId) async {
    final db = await database;
    return await db.query(
      'DocumentDetail',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'created_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getDocumentDetailsByDocumentIdNotDeleted(int documentId) async {
    final db = await database;
    return await db.query(
      'DocumentDetail',
      where: 'document_id = ? AND is_deleted = ?',
      whereArgs: [documentId, 0],
      orderBy: 'created_date DESC',
    );
  }

  Future<int> updateDocumentDetail(int id, Map<String, dynamic> documentDetail) async {
    final db = await database;
    return await db.update(
      'DocumentDetail',
      documentDetail,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDocumentDetail(int id) async {
    final db = await database;
    return await db.delete(
      'DocumentDetail',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> softDeleteDocumentDetail(int id) async {
    final db = await database;
    return await db.update(
      'DocumentDetail',
      {'is_deleted': 1, 'updated_date': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== TrashDocuments CRUD Operations ====================

  Future<int> createTrashDocument(Map<String, dynamic> trashDocument) async {
    final db = await database;
    return await db.insert('TrashDocuments', trashDocument);
  }

  Future<List<Map<String, dynamic>>> getAllTrashDocuments() async {
    final db = await database;
    return await db.query('TrashDocuments', orderBy: 'created_date DESC');
  }

  Future<Map<String, dynamic>?> getTrashDocument(int id) async {
    final db = await database;
    final result = await db.query(
      'TrashDocuments',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateTrashDocument(int id, Map<String, dynamic> trashDocument) async {
    final db = await database;
    return await db.update(
      'TrashDocuments',
      trashDocument,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTrashDocument(int id) async {
    final db = await database;
    return await db.delete(
      'TrashDocuments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearAllTrashDocuments() async {
    final db = await database;
    return await db.delete('TrashDocuments');
  }

  Future<List<Map<String, dynamic>>> getTrashDocumentsByDocumentId(int documentId) async {
    final db = await database;
    return await db.query(
      'TrashDocuments',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'created_date DESC',
    );
  }

  // ==================== FavouriteDocuments CRUD Operations ====================

  Future<int> createFavouriteDocument(Map<String, dynamic> favouriteDocument) async {
    final db = await database;
    return await db.insert('FavouriteDocuments', favouriteDocument);
  }

  Future<List<Map<String, dynamic>>> getAllFavouriteDocuments() async {
    final db = await database;
    return await db.query('FavouriteDocuments', orderBy: 'created_date DESC');
  }

  Future<Map<String, dynamic>?> getFavouriteDocument(int id) async {
    final db = await database;
    final result = await db.query(
      'FavouriteDocuments',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateFavouriteDocument(int id, Map<String, dynamic> favouriteDocument) async {
    final db = await database;
    return await db.update(
      'FavouriteDocuments',
      favouriteDocument,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteFavouriteDocument(int id) async {
    final db = await database;
    return await db.delete(
      'FavouriteDocuments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getFavouriteDocumentsByDocumentId(int documentId) async {
    final db = await database;
    return await db.query(
      'FavouriteDocuments',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'created_date DESC',
    );
  }

  // ==================== ImportDocument CRUD Operations ====================

  Future<int> createImportDocument(Map<String, dynamic> importDocument) async {
    final db = await database;
    return await db.insert('ImportDocument', importDocument);
  }

  Future<List<Map<String, dynamic>>> getAllImportDocuments() async {
    final db = await database;
    return await db.query('ImportDocument', orderBy: 'created_date DESC');
  }

  Future<Map<String, dynamic>?> getImportDocument(int id) async {
    final db = await database;
    final result = await db.query(
      'ImportDocument',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // ==================== Utility Methods ====================

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<int> getCount(String tableName) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

