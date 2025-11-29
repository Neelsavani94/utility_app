import 'dart:developer';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../Models/tag_model.dart';
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

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create Tags table
    await db.execute('''
      CREATE TABLE Tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Insert default tags
    final defaultTags = [
      'All Docs',
      'Business Card',
      'ID Card',
      'Academic',
      'Personal',
    ];

    final now = DateTime.now().toIso8601String();
    for (final tagTitle in defaultTags) {
      await db.insert('Tags', {
        'title': tagTitle,
        'created_at': now,
        'updated_at': now,
        'is_default': 1,
      });
    }

    // Create Documents table
    await db.execute('''
      CREATE TABLE Documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        isFavourite INTEGER NOT NULL DEFAULT 0,
        imagePath TEXT NOT NULL,
        thumbnailPath TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        tag_id INTEGER,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        FOREIGN KEY (tag_id) REFERENCES Tags(id) ON DELETE SET NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_documents_tag_id ON Documents(tag_id)');
    await db.execute(
      'CREATE INDEX idx_documents_created_at ON Documents(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_documents_isFavourite ON Documents(isFavourite)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here if needed
    if (oldVersion < 3) {
      // Add isDeleted and deleted_at columns to Documents table
      try {
        await db.execute(
          'ALTER TABLE Documents ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE Documents ADD COLUMN deleted_at TEXT',
        );
      } catch (e) {
        // Columns might already exist, ignore error
      }
    }
    if (oldVersion < 2) {
      // Add is_default column to Tags table
      try {
        await db.execute(
          'ALTER TABLE Tags ADD COLUMN is_default INTEGER NOT NULL DEFAULT 0',
        );

        // Mark default tags
        final defaultTags = [
          'All Docs',
          'Business Card',
          'ID Card',
          'Academic',
          'Personal',
        ];

        for (final tagTitle in defaultTags) {
          await db.update(
            'Tags',
            {'is_default': 1},
            where: 'title = ?',
            whereArgs: [tagTitle],
          );
        }

        // If no default tags exist, insert them
        final existingTags = await db.query('Tags', where: 'is_default = 1');
        if (existingTags.isEmpty) {
          final now = DateTime.now().toIso8601String();
          for (final tagTitle in defaultTags) {
            await db.insert('Tags', {
              'title': tagTitle,
              'created_at': now,
              'updated_at': now,
              'is_default': 1,
            });
          }
        }
      } catch (e) {
        // Column might already exist, ignore error
      }
    }
  }

  // ==================== Tags CRUD Operations ====================

  Future<int> insertTag(Tag tag) async {
    final db = await database;
    final now = DateTime.now();
    final tagToInsert = tag.copyWith(createdAt: now, updatedAt: now);
    return await db.insert('Tags', tagToInsert.toMap());
  }

  Future<List<Tag>> getAllTags() async {
    final db = await database;
    // Order by is_default DESC (default tags first), then by created_at
    final result = await db.query(
      'Tags',
      orderBy: 'is_default DESC, created_at DESC',
    );
    return result.map((map) => Tag.fromMap(map)).toList();
  }

  Future<Tag?> getTagById(int id) async {
    final db = await database;
    final result = await db.query('Tags', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Tag.fromMap(result.first);
  }

  Future<int> updateTag(Tag tag) async {
    final db = await database;
    // Prevent updating default tags
    if (tag.isDefault) {
      throw Exception('Cannot update default tags');
    }
    final tagToUpdate = tag.copyWith(updatedAt: DateTime.now());
    return await db.update(
      'Tags',
      tagToUpdate.toMap(),
      where: 'id = ? AND is_default = 0',
      whereArgs: [tag.id],
    );
  }

  Future<int> deleteTag(int id) async {
    final db = await database;
    // Check if tag is default
    final tag = await getTagById(id);
    if (tag != null && tag.isDefault) {
      throw Exception('Cannot delete default tags');
    }
    // First, set tag_id to NULL for all documents with this tag
    await db.update(
      'Documents',
      {'tag_id': null},
      where: 'tag_id = ?',
      whereArgs: [id],
    );
    // Then delete the tag (only if not default)
    return await db.delete(
      'Tags',
      where: 'id = ? AND is_default = 0',
      whereArgs: [id],
    );
  }

  // ==================== Documents CRUD Operations ====================

  Future<int> insertDocument(Document document) async {
    final db = await database;
    final now = DateTime.now();
    final docToInsert = document.copyWith(createdAt: now, updatedAt: now);
    return await db.insert('Documents', docToInsert.toMap());
  }

  Future<List<Document>> getAllDocuments() async {
    final db = await database;
    final result = await db.query(
      'Documents',
      where: 'isDeleted = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    log(result.toString());
    return result.map((map) => Document.fromMap(map)).toList();
  }

  Future<List<Document>> getDocumentsByTagId(int? tagId) async {
    final db = await database;
    final result = await db.query(
      'Documents',
      where: tagId == null ? 'tag_id IS NULL' : 'tag_id = ?',
      whereArgs: tagId == null ? [] : [tagId],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Document.fromMap(map)).toList();
  }

  Future<List<Document>> getFavouriteDocuments() async {
    final db = await database;
    final result = await db.query(
      'Documents',
      where: 'isFavourite = ? AND isDeleted = ?',
      whereArgs: [1, 0],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Document.fromMap(map)).toList();
  }

  Future<List<Document>> getDeletedDocuments() async {
    final db = await database;
    final result = await db.query(
      'Documents',
      where: 'isDeleted = ?',
      whereArgs: [1],
      orderBy: 'deleted_at DESC, created_at DESC',
    );
    return result.map((map) => Document.fromMap(map)).toList();
  }

  Future<List<Document>> getDocumentsByType(String type) async {
    final db = await database;
    final result = await db.query(
      'Documents',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Document.fromMap(map)).toList();
  }

  Future<Document?> getDocumentById(int id) async {
    final db = await database;
    final result = await db.query(
      'Documents',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Document.fromMap(result.first);
  }

  Future<int> updateDocument(Document document) async {
    final db = await database;
    final docToUpdate = document.copyWith(updatedAt: DateTime.now());
    return await db.update(
      'Documents',
      docToUpdate.toMap(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  Future<int> deleteDocument(int id) async {
    final db = await database;
    return await db.delete('Documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> toggleFavourite(int id, bool isFavourite) async {
    final db = await database;
    return await db.update(
      'Documents',
      {
        'isFavourite': isFavourite ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> moveToTrash(int id) async {
    final db = await database;
    return await db.update(
      'Documents',
      {
        'isDeleted': 1,
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Search Operations ====================

  Future<List<Document>> searchDocuments(String query) async {
    final db = await database;
    final result = await db.query(
      'Documents',
      where: 'title LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Document.fromMap(map)).toList();
  }

  // ==================== Statistics ====================

  Future<int> getDocumentCount() async {
    final db = await database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM Documents'),
    );
    return result ?? 0;
  }

  Future<int> getTagCount() async {
    final db = await database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM Tags'),
    );
    return result ?? 0;
  }

  Future<int> getFavouriteCount() async {
    final db = await database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM Documents WHERE isFavourite = 1'),
    );
    return result ?? 0;
  }

  // ==================== Database Management ====================

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'utility_app.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
