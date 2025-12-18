import 'dart:developer';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../Models/tag_model.dart';
import '../Models/document_model.dart';
import '../Models/document_detail_model.dart';

/// Database Helper matching Kotlin structure
/// Main table: alldocs (id, name, date, tag, firstimage, pin, biometric)
/// Dynamic tables: One per group/folder with columns:
///   id, imgname, imgnote, imgpath, old_folder_names, tag, key_is_first_image_available, datev, pin, biometric
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Constants matching Kotlin code
  static const String _databaseName = 'DocumentDB';
  static const int _databaseVersion = 2; // Incremented to add Documents table
  static const String _tableAllDocs = 'alldocs';
  static const String _tableDocuments = 'Documents'; // New table for individual documents
  static const String _binFolder = 'bin123trash679abcsdcdfsd';

  // Column names
  static const String _keyId = 'id';
  static const String _keyName = 'name';
  static const String _keyDate = 'date';
  static const String _keyTag = 'tag';
  static const String _keyFirstImage = 'firstimage';
  static const String _keyPin = 'pin';
  static const String _keyBiometric = 'biometric';
  static const String _keyImgName = 'imgname';
  static const String _keyImgNote = 'imgnote';
  static const String _keyImgPath = 'imgpath';
  static const String _oldFolderNames = 'old_folder_names';
  static const String _keyIsFirstImageAvailable = 'key_is_first_image_available';
  static const String _keyTableDate = 'datev';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('$_databaseName.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create Tags table for tag management
    await db.execute('''
      CREATE TABLE Tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL UNIQUE,
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

    // Create main alldocs table matching Kotlin structure
    await db.execute('''
      CREATE TABLE $_tableAllDocs(
        $_keyId INTEGER PRIMARY KEY,
        $_keyName TEXT,
        $_keyDate TEXT,
        $_keyTag TEXT,
        $_keyFirstImage TEXT,
        $_keyPin TEXT,
        $_keyBiometric TEXT
      )
    ''');

    // Create Documents table for individual documents (new structure)
    await db.execute('''
      CREATE TABLE $_tableDocuments(
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
        deleted_at TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add Tags table if it doesn't exist
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS Tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_default INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Insert default tags if they don't exist
        final existingTags = await db.query('Tags');
        if (existingTags.isEmpty) {
          final defaultTags = [
            'All Docs',
            'Business Card',
            'ID Card',
            'Academic',
            'Personal',
          ];

          final now = DateTime.now().toIso8601String();
          for (final tagTitle in defaultTags) {
            try {
              await db.insert('Tags', {
                'title': tagTitle,
                'created_at': now,
                'updated_at': now,
                'is_default': 1,
              });
            } catch (e) {
              // Tag might already exist, ignore
              log('Tag $tagTitle might already exist: $e');
            }
          }
        }
      } catch (e) {
        log('Error creating Tags table: $e');
      }

      // Add Documents table for new structure
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_tableDocuments(
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
            deleted_at TEXT
          )
        ''');
        log('Documents table created successfully');
      } catch (e) {
        log('Error creating Documents table: $e');
      }
    }
    
    if (oldVersion < newVersion && oldVersion == 1) {
      // Only drop and recreate if this is a major version change
      // For minor updates, use migrations above
    }
  }

  /// Validate table name (alphanumeric and underscore, 1-30 chars)
  String _validateTableName(String name) {
    final sanitized = name.replaceAll(' ', '');
    final regex = RegExp(r'^[a-zA-Z0-9_]{1,30}$');
    if (!regex.hasMatch(sanitized)) {
      throw ArgumentError('Invalid table name: $name');
    }
    return sanitized;
  }

  /// Check if group name exists (case-insensitive)
  Future<bool> isGroupNameExist(String groupName) async {
    final db = await database;
    final result = await db.query(
      _tableAllDocs,
      where: 'LOWER($_keyName) = LOWER(?)',
      whereArgs: [groupName],
    );
    return result.isNotEmpty;
  }

  /// Check if bin exists
  Future<bool> isBinExist(String groupName) async {
    final db = await database;
    final result = await db.query(
      _tableAllDocs,
      where: '$_keyName = ?',
      whereArgs: [groupName],
    );
    return result.isNotEmpty;
  }

  /// Create document table for a group
  Future<void> createDocTable(String groupName) async {
    final tableName = _validateTableName(groupName);
    
    if (await isGroupNameExist(groupName)) {
      return; // Table already exists
    }

    final db = await database;
    await db.execute('''
      CREATE TABLE '$tableName'(
        $_keyId INTEGER PRIMARY KEY,
        $_keyImgName TEXT,
        $_keyImgNote TEXT,
        $_keyImgPath TEXT,
        $_oldFolderNames TEXT,
        $_keyTag TEXT,
        $_keyIsFirstImageAvailable TEXT,
        $_keyTableDate TEXT,
        $_keyPin TEXT,
        $_keyBiometric TEXT
      )
    ''');
  }

  /// Create bin table
  Future<void> createBinTable() async {
    if (await isBinExist(_binFolder)) {
      return;
    }

    final db = await database;
    final tableName = _validateTableName(_binFolder);
    await db.execute('''
      CREATE TABLE '$tableName'(
        $_keyId INTEGER PRIMARY KEY,
        $_keyImgName TEXT,
        $_keyImgNote TEXT,
        $_keyImgPath TEXT,
        $_oldFolderNames TEXT,
        $_keyTag TEXT,
        $_keyIsFirstImageAvailable TEXT,
        $_keyTableDate TEXT,
        $_keyPin TEXT,
        $_keyBiometric TEXT
      )
    ''');
  }

  /// Add group to alldocs table
  Future<int> addGroup({
    required String groupName,
    required String groupDate,
    String? groupTag,
    String? groupFirstImg,
    String? groupPin,
    String? biometric,
  }) async {
    if (await isGroupNameExist(groupName)) {
      throw Exception('Document Name Already Exist');
    }

    final db = await database;
    return await db.insert(_tableAllDocs, {
      _keyName: groupName,
      _keyDate: groupDate,
      _keyTag: groupTag ?? '',
      _keyFirstImage: groupFirstImg ?? '',
      _keyPin: groupPin ?? '',
      _keyBiometric: biometric ?? '',
    });
  }

  /// Add bin group
  Future<int> addBinGroup({
    required String groupName,
    required String groupDate,
    String? groupTag,
    String? groupFirstImg,
    String? groupPin,
    String? biometric,
  }) async {
    if (await isBinExist(groupName)) {
      return 0;
    }

    final db = await database;
    return await db.insert(_tableAllDocs, {
      _keyName: groupName,
      _keyDate: groupDate,
      _keyTag: groupTag ?? '',
      _keyFirstImage: groupFirstImg ?? '',
      _keyPin: groupPin ?? '',
      _keyBiometric: biometric ?? '',
    });
  }

  /// Add document to a group table
  Future<int> addGroupDoc({
    required String groupName,
    String? imgPath,
    String? imgName,
    String? imgNote,
  }) async {
    final tableName = _validateTableName(groupName);
    final db = await database;

    return await db.insert(tableName, {
      _keyImgPath: imgPath ?? '',
      _keyImgName: imgName ?? '',
      _keyImgNote: imgNote ?? '',
    });
  }

  /// Move document to another group
  Future<int> moveGroupDoc({
    required String targetGroupName,
    String? imgPath,
    String? imgName,
    String? imgNote,
  }) async {
    final tableName = _validateTableName(targetGroupName);
    final db = await database;

    final result = await db.insert(tableName, {
      _keyImgPath: imgPath ?? '',
      _keyImgName: imgName ?? '',
      _keyImgNote: imgNote ?? '',
    });
    
    return result;
  }

  /// Get all groups
  Future<List<Map<String, dynamic>>> getAllGroups() async {
    final db = await database;
    return await db.query(_tableAllDocs);
  }

  /// Get only groups without first image
  Future<List<Map<String, dynamic>>> getOnlyAllGroups() async {
    final db = await database;
    final allGroups = await db.query(_tableAllDocs);
    return allGroups.where((group) {
      final firstImage = group[_keyFirstImage]?.toString() ?? '';
      return firstImage.isEmpty;
    }).toList();
  }

  /// Get groups by tag
  Future<List<Map<String, dynamic>>> getGroupsByTag(String tag) async {
    final db = await database;
    return await db.query(
      _tableAllDocs,
      where: '$_keyTag = ?',
      whereArgs: [tag],
    );
  }

  /// Get single group by name
  Future<List<Map<String, dynamic>>> getSingleGroupsByName(String groupName) async {
    final db = await database;
    return await db.query(
      _tableAllDocs,
      where: '$_keyName = ?',
      whereArgs: [groupName],
    );
  }

  /// Get documents from a group table
  Future<List<Map<String, dynamic>>> getGroupDocs(String groupName) async {
    final tableName = _validateTableName(groupName);
    final db = await database;
    
    try {
      return await db.query(tableName);
    } catch (e) {
      log('Error getting group docs: $e');
      return [];
    }
  }

  /// Get bin documents
  Future<List<Map<String, dynamic>>> getBinDocs() async {
    final tableName = _validateTableName(_binFolder);
    final db = await database;
    
    try {
      return await db.query(tableName);
    } catch (e) {
      log('Error getting bin docs: $e');
      return [];
    }
  }

  /// Get share group documents (filtered)
  Future<List<Map<String, dynamic>>> getShareGroupDocs(String groupName) async {
    final tableName = _validateTableName(groupName);
    final db = await database;
    
    try {
      final allDocs = await db.query(tableName);
      return allDocs.where((doc) {
        return doc[_keyImgName] != null && doc[_keyImgName].toString().isNotEmpty;
      }).toList();
    } catch (e) {
      log('Error getting share group docs: $e');
      return [];
    }
  }

  /// Rename group
  Future<void> updateGroupName(String oldName, String newName) async {
    if (await isGroupNameExist(newName)) {
      throw Exception('Document Name Already Exist');
    }

    final db = await database;
    await db.update(
      _tableAllDocs,
      {_keyName: newName},
      where: '$_keyName = ?',
      whereArgs: [oldName],
    );

    // Rename the table
    final oldTableName = _validateTableName(oldName);
    final newTableName = _validateTableName(newName);
    await db.execute('ALTER TABLE $oldTableName RENAME TO $newTableName');
  }

  /// Update tag name
  Future<void> updateTagName(String groupName, String newTag) async {
    final db = await database;
    await db.update(
      _tableAllDocs,
      {_keyTag: newTag},
      where: '$_keyName = ?',
      whereArgs: [groupName],
    );
  }

  /// Update pin
  Future<void> updatePin(String groupName, String pin) async {
    final db = await database;
    await db.update(
      _tableAllDocs,
      {_keyPin: pin},
      where: '$_keyName = ?',
      whereArgs: [groupName],
    );
  }

  /// Update biometric
  Future<void> updateBioMetric(String groupName, String biometric) async {
    final db = await database;
    await db.update(
      _tableAllDocs,
      {_keyBiometric: biometric},
      where: '$_keyName = ?',
      whereArgs: [groupName],
    );
  }

  /// Update group first image
  Future<void> updateGroupFirstImg(String groupName, String? firstImage) async {
    final db = await database;
    await db.update(
      _tableAllDocs,
      {_keyFirstImage: firstImage ?? ''},
      where: '$_keyName = ?',
      whereArgs: [groupName],
    );
  }

  /// Rename document in group
  Future<void> renameGroupListDocNote(String groupName, String oldName, String newName) async {
    if (await isDocNameExist(groupName, newName)) {
      throw Exception('Document Name Already Exist');
    }

    final tableName = _validateTableName(groupName);
    final db = await database;
    await db.update(
      tableName,
      {_keyImgName: newName},
      where: '$_keyImgName = ?',
      whereArgs: [oldName],
    );
  }

  /// Check if document name exists in group
  Future<bool> isDocNameExist(String groupName, String docName) async {
    final tableName = _validateTableName(groupName);
    final db = await database;
    final result = await db.query(
      tableName,
      where: 'LOWER($_keyImgName) = LOWER(?)',
      whereArgs: [docName],
    );
    return result.isNotEmpty;
  }

  /// Update document path in group
  Future<void> updateGroupListDoc(String groupName, String docName, String? newPath) async {
    final tableName = _validateTableName(groupName);
    final db = await database;
    await db.update(
      tableName,
      {_keyImgPath: newPath ?? ''},
      where: '$_keyImgName = ?',
      whereArgs: [docName],
    );
  }

  /// Update document note in group
  Future<void> updateGroupListDocNote(String groupName, String docName, String? note) async {
    final tableName = _validateTableName(groupName);
    final db = await database;
    await db.update(
      tableName,
      {_keyImgNote: note ?? ''},
      where: '$_keyImgName = ?',
      whereArgs: [docName],
    );
  }

  /// Delete group
  Future<void> deleteGroup(String groupName) async {
    final db = await database;
    await db.delete(
      _tableAllDocs,
      where: '$_keyName = ?',
      whereArgs: [groupName],
    );
    
    final tableName = _validateTableName(groupName);
    await db.execute('DROP TABLE IF EXISTS $tableName');
  }

  /// Delete single document from group
  Future<void> deleteSingleDoc(String groupName, String docName) async {
    final tableName = _validateTableName(groupName);
    final db = await database;
    await db.delete(
      tableName,
      where: '$_keyImgName = ?',
      whereArgs: [docName],
    );
  }

  /// Move document to bin
  Future<int> moveToBin({
    required String oldFolderName,
    required Map<String, dynamic> docData,
  }) async {
    final db = await database;
    
    // Get original group info
    final groupInfo = await getSingleGroupsByName(oldFolderName);
    if (groupInfo.isEmpty) {
      throw Exception('Group not found');
    }

    final firstImage = (groupInfo.first[_keyFirstImage]?.toString() ?? '').isNotEmpty
        ? 'YES'
        : 'NO';

    final date = DateTime.now().toString();

    // Create bin table if not exists
    await createBinTable();
    
    // Add bin group if not exists
    await addBinGroup(
      groupName: _binFolder,
      groupDate: date,
      groupTag: groupInfo.first[_keyTag]?.toString(),
      groupFirstImg: groupInfo.first[_keyFirstImage]?.toString(),
    );

    // Insert into bin table
    final tableName = _validateTableName(_binFolder);
    return await db.insert(tableName, {
      _oldFolderNames: oldFolderName,
      _keyImgPath: docData['imgpath'] ?? docData[_keyImgPath] ?? '',
      _keyImgName: docData['imgname'] ?? docData[_keyImgName] ?? '',
      _keyImgNote: docData['imgnote'] ?? docData[_keyImgNote] ?? '',
      _keyTag: groupInfo.first[_keyTag] ?? '',
      _keyPin: docData['pin'] ?? docData[_keyPin] ?? '',
      _keyBiometric: docData['biometric'] ?? docData[_keyBiometric] ?? '',
      _keyIsFirstImageAvailable: firstImage,
      _keyTableDate: groupInfo.first[_keyDate] ?? '',
    });
  }

  /// Move document from bin back to original folder
  Future<int> moveFromBin(Map<String, dynamic> binDoc) async {
    final db = await database;
    final oldFolderName = binDoc[_oldFolderNames]?.toString() ?? '';
    
    if (oldFolderName.isEmpty) {
      throw Exception('Original folder name not found');
    }

    // Check if original folder exists, create if not
    if (!await isGroupNameExist(oldFolderName)) {
      await createDocTable(oldFolderName);
      await addGroup(
        groupName: oldFolderName,
        groupDate: binDoc[_keyTableDate]?.toString() ?? DateTime.now().toString(),
        groupTag: binDoc[_keyTag]?.toString(),
        groupFirstImg: (binDoc[_keyIsFirstImageAvailable]?.toString() == 'YES')
            ? (binDoc[_keyImgPath]?.toString() ?? '')
            : '',
      );
    }

    // Insert into original folder table
    final tableName = _validateTableName(oldFolderName);
    return await db.insert(tableName, {
      _keyImgPath: binDoc[_keyImgPath] ?? '',
      _keyImgName: binDoc[_keyImgName] ?? '',
      _keyImgNote: binDoc[_keyImgNote] ?? '',
      _keyTag: binDoc[_keyTag] ?? '',
      _keyPin: binDoc[_keyPin] ?? '',
      _keyBiometric: binDoc[_keyBiometric] ?? '',
    });
  }

  /// Get single note from document
  Future<String> getSingleNote(String groupName, String docName) async {
    final tableName = _validateTableName(groupName);
    final db = await database;
    final result = await db.query(
      tableName,
      where: '$_keyImgName = ?',
      whereArgs: [docName],
      limit: 1,
    );
    
    if (result.isEmpty) return '';
    return result.first[_keyImgNote]?.toString() ?? '';
  }

  // ==================== Compatibility Methods (for existing code) ====================
  // These methods provide compatibility with existing Document/DocumentDetail models

  /// Insert document (converts to group structure)
  Future<int> insertDocument(Document document) async {
    try {
      final db = await database;
      
      // Insert into Documents table (new structure)
      final result = await db.insert(
        _tableDocuments,
        document.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      log('Document inserted with ID: $result');
      return result;
    } catch (e) {
      log('Error inserting document: $e');
      rethrow;
    }
  }

  /// Get all documents from Documents table
  Future<List<Document>> getAllDocuments() async {
    try {
      final db = await database;
      
      // Query from new Documents table
      final List<Map<String, dynamic>> maps = await db.query(
        _tableDocuments,
        where: 'isDeleted = ?',
        whereArgs: [0], // Only get non-deleted documents
        orderBy: 'created_at DESC',
      );

      // Also get documents from old group structure for backward compatibility
      final groups = await getAllGroups();
      final List<Document> documents = [];

      // First, add documents from new Documents table
      for (final map in maps) {
        try {
          documents.add(Document.fromMap(map));
        } catch (e) {
          log('Error parsing document from Documents table: $e');
        }
      }

      // Then, add documents from old group structure (for backward compatibility)
      for (final group in groups) {
        if (group[_keyName]?.toString() == _binFolder) continue;
        
        final groupName = group[_keyName]?.toString() ?? '';
        final docs = await getGroupDocs(groupName);
        
        for (final doc in docs) {
          try {
            documents.add(Document(
              id: doc[_keyId] as int?,
              title: doc[_keyImgName]?.toString() ?? '',
              type: 'Document',
              imagePath: doc[_keyImgPath]?.toString() ?? '',
              createdAt: group[_keyDate] != null 
                  ? DateTime.tryParse(group[_keyDate].toString()) ?? DateTime.now()
                  : DateTime.now(),
              tagId: group[_keyTag]?.toString().isNotEmpty == true
                  ? int.tryParse(group[_keyTag].toString())
                  : null,
            ));
          } catch (e) {
            log('Error converting doc: $e');
          }
        }
      }

      return documents;
    } catch (e) {
      log('Error getting all documents: $e');
      return [];
    }
  }

  /// Get document by ID from Documents table
  Future<Document?> getDocumentById(int id) async {
    try {
      final db = await database;
      
      // First try to get from new Documents table
      final List<Map<String, dynamic>> maps = await db.query(
        _tableDocuments,
        where: 'id = ? AND isDeleted = ?',
        whereArgs: [id, 0],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return Document.fromMap(maps.first);
      }

      // Fallback to old group structure for backward compatibility
      final groups = await getAllGroups();
      
      for (final group in groups) {
        if (group[_keyName]?.toString() == _binFolder) continue;
        
        final groupName = group[_keyName]?.toString() ?? '';
        final docs = await getGroupDocs(groupName);
        
        for (final doc in docs) {
          if (doc[_keyId] == id) {
            return Document(
              id: doc[_keyId] as int?,
              title: doc[_keyImgName]?.toString() ?? '',
              type: 'Document',
              imagePath: doc[_keyImgPath]?.toString() ?? '',
              createdAt: group[_keyDate] != null 
                  ? DateTime.tryParse(group[_keyDate].toString()) ?? DateTime.now()
                  : DateTime.now(),
              tagId: group[_keyTag]?.toString().isNotEmpty == true
                  ? int.tryParse(group[_keyTag].toString())
                  : null,
            );
          }
        }
      }
      
      return null;
    } catch (e) {
      log('Error getting document by ID: $e');
      return null;
    }
  }

  /// Update document (converts to group structure)
  Future<int> updateDocument(Document document) async {
    if (document.id == null) return 0;
    
    // Find which group contains this document
    final groups = await getAllGroups();
    
    for (final group in groups) {
      if (group[_keyName]?.toString() == _binFolder) continue;
      
      final groupName = group[_keyName]?.toString() ?? '';
      final docs = await getGroupDocs(groupName);
      
      for (final doc in docs) {
        if (doc[_keyId] == document.id) {
          // Update document in group
          await updateGroupListDoc(
            groupName,
            doc[_keyImgName]?.toString() ?? '',
            document.imagePath,
          );
          
          if (document.title != doc[_keyImgName]?.toString()) {
            await renameGroupListDocNote(
              groupName,
              doc[_keyImgName]?.toString() ?? '',
              document.title,
            );
          }
          
          return 1;
        }
      }
    }
    
    return 0;
  }

  /// Delete document
  Future<int> deleteDocument(int id) async {
    final groups = await getAllGroups();
    
    for (final group in groups) {
      if (group[_keyName]?.toString() == _binFolder) continue;
      
      final groupName = group[_keyName]?.toString() ?? '';
      final docs = await getGroupDocs(groupName);
      
      for (final doc in docs) {
        if (doc[_keyId] == id) {
          await deleteSingleDoc(
            groupName,
            doc[_keyImgName]?.toString() ?? '',
          );
          return 1;
        }
      }
    }
    
    return 0;
  }

  /// Move document to trash (converts to bin structure)
  Future<int> moveToTrash(int id) async {
    final groups = await getAllGroups();
    
    for (final group in groups) {
      if (group[_keyName]?.toString() == _binFolder) continue;
      
      final groupName = group[_keyName]?.toString() ?? '';
      final docs = await getGroupDocs(groupName);
      
      for (final doc in docs) {
        if (doc[_keyId] == id) {
          await moveToBin(
            oldFolderName: groupName,
            docData: doc,
          );
          
          // Delete from original group
          await deleteSingleDoc(
            groupName,
            doc[_keyImgName]?.toString() ?? '',
          );
          
          return 1;
        }
      }
    }
    
    return 0;
  }

  /// Get deleted documents (from bin)
  Future<List<Document>> getDeletedDocuments() async {
    final binDocs = await getBinDocs();
    final List<Document> documents = [];

    for (final doc in binDocs) {
      try {
        documents.add(Document(
          id: doc[_keyId] as int?,
          title: doc[_keyImgName]?.toString() ?? '',
          type: 'Document',
          imagePath: doc[_keyImgPath]?.toString() ?? '',
          createdAt: doc[_keyTableDate] != null
              ? DateTime.tryParse(doc[_keyTableDate].toString()) ?? DateTime.now()
              : DateTime.now(),
          isDeleted: true,
          deletedAt: DateTime.now(),
        ));
      } catch (e) {
        log('Error converting bin doc: $e');
      }
    }

    return documents;
  }

  /// Get documents by tag ID (converts from group structure)
  Future<List<Document>> getDocumentsByTagId(int? tagId) async {
    final allDocs = await getAllDocuments();
    if (tagId == null) {
      return allDocs.where((doc) => doc.tagId == null).toList();
    }
    return allDocs.where((doc) => doc.tagId == tagId).toList();
  }

  /// Insert document detail (converts to group structure)
  Future<int> insertDocumentDetail(DocumentDetail detail) async {
    // Get parent document to find group
    final parentDoc = await getDocumentById(detail.documentId);
    if (parentDoc == null) {
      throw Exception('Parent document not found');
    }

    // Use parent document title as group name
    final groupName = parentDoc.title;
    
    return await addGroupDoc(
      groupName: groupName,
      imgPath: detail.imagePath,
      imgName: detail.title,
      imgNote: '',
    );
  }

  /// Get document details by document ID
  Future<List<DocumentDetail>> getDocumentDetailsByDocumentId(int documentId) async {
    final parentDoc = await getDocumentById(documentId);
    if (parentDoc == null) {
      return [];
    }

    final groupName = parentDoc.title;
    final docs = await getGroupDocs(groupName);
    
    return docs.map((doc) {
      return DocumentDetail(
        id: doc[_keyId] as int?,
        documentId: documentId,
        title: doc[_keyImgName]?.toString() ?? '',
        type: 'Document',
        imagePath: doc[_keyImgPath]?.toString() ?? '',
        createdAt: parentDoc.createdAt,
        updatedAt: parentDoc.updatedAt,
      );
    }).toList();
  }

  /// Update document detail
  Future<int> updateDocumentDetail(DocumentDetail detail) async {
    if (detail.id == null) {
      throw Exception('Document detail ID is required');
    }

    // Get parent document to find group
    final parentDoc = await getDocumentById(detail.documentId);
    if (parentDoc == null) {
      throw Exception('Parent document not found');
    }

    final groupName = parentDoc.title;
    final docs = await getGroupDocs(groupName);
    
    // Find the document detail by ID to get old name
    String? oldName;
    for (final doc in docs) {
      if (doc[_keyId] == detail.id) {
        oldName = doc[_keyImgName]?.toString();
        break;
      }
    }
    
    if (oldName == null) {
      throw Exception('Document detail not found');
    }
    
    // Update document path if changed
    if (detail.imagePath.isNotEmpty) {
      await updateGroupListDoc(groupName, oldName, detail.imagePath);
    }
    
    // Update document name if changed
    if (detail.title != oldName) {
      await renameGroupListDocNote(groupName, oldName, detail.title);
    }
    
    // Update document note if needed (if we add note support)
    // await updateGroupListDocNote(groupName, detail.title, detail.note);
    
    return 1;
  }

  /// Move document detail to trash
  Future<int> moveDocumentDetailToTrash(int id) async {
    // Find which group contains this document detail
    final groups = await getAllGroups();
    
    for (final group in groups) {
      if (group[_keyName]?.toString() == _binFolder) continue;
      
      final groupName = group[_keyName]?.toString() ?? '';
      final docs = await getGroupDocs(groupName);
      
      for (final doc in docs) {
        if (doc[_keyId] == id) {
          await moveToBin(
            oldFolderName: groupName,
            docData: doc,
          );
          
          // Delete from original group
          await deleteSingleDoc(
            groupName,
            doc[_keyImgName]?.toString() ?? '',
          );
          
          return 1;
        }
      }
    }
    
    return 0;
  }

  /// Toggle favourite status
  Future<int> toggleFavourite(int id, bool isFavourite) async {
    // In the new structure, favourites are not directly supported
    // This is a compatibility method that does nothing for now
    // You can implement this by adding a favourite column to group tables if needed
    return 0;
  }

  /// Get favourite documents
  Future<List<Document>> getFavouriteDocuments() async {
    // In the new structure, favourites are not directly supported
    // Return empty list for now
    // You can implement this by adding a favourite column to group tables if needed
    return [];
  }

  /// Copy document with details
  Future<int> copyDocumentWithDetails(int documentId, int? targetTagId) async {
    final originalDoc = await getDocumentById(documentId);
    if (originalDoc == null) {
      throw Exception('Document not found');
    }

    // Create new group for copied document
    final newGroupName = '${originalDoc.title}_copy';
    final date = DateTime.now().toString();
    
    await createDocTable(newGroupName);
    await addGroup(
      groupName: newGroupName,
      groupDate: date,
      groupTag: targetTagId?.toString(),
      groupFirstImg: originalDoc.imagePath,
    );

    // Copy all documents from original group
    final originalGroupName = originalDoc.title;
    final originalDocs = await getGroupDocs(originalGroupName);
    
    for (final doc in originalDocs) {
      await addGroupDoc(
        groupName: newGroupName,
        imgPath: doc[_keyImgPath]?.toString(),
        imgName: doc[_keyImgName]?.toString(),
        imgNote: doc[_keyImgNote]?.toString(),
      );
    }

    // Return the first document ID from new group
    final newDocs = await getGroupDocs(newGroupName);
    return newDocs.isNotEmpty ? (newDocs.first[_keyId] as int? ?? 0) : 0;
  }

  /// Move document to folder
  Future<int> moveDocumentToFolder(int documentId, int? targetTagId) async {
    final doc = await getDocumentById(documentId);
    if (doc == null) {
      throw Exception('Document not found');
    }

    // Update tag in group
    final groupName = doc.title;
    if (targetTagId != null) {
      await updateTagName(groupName, targetTagId.toString());
    }
    
    return 1;
  }

  /// Tags CRUD Operations
  Future<int> insertTag(Tag tag) async {
    final db = await database;
    
    // Check if tag already exists (case-insensitive)
    final existing = await tagExists(tag.title);
    if (existing) {
      throw Exception('Tag "${tag.title}" already exists');
    }

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

  /// Check if a tag with the given name already exists (case-insensitive)
  Future<bool> tagExists(String tagName) async {
    final db = await database;
    final result = await db.query(
      'Tags',
      where: 'LOWER(title) = LOWER(?)',
      whereArgs: [tagName.trim()],
    );
    return result.isNotEmpty;
  }

  /// Get tag by name (case-insensitive)
  Future<Tag?> getTagByName(String tagName) async {
    final db = await database;
    final result = await db.query(
      'Tags',
      where: 'LOWER(title) = LOWER(?)',
      whereArgs: [tagName.trim()],
    );
    if (result.isEmpty) return null;
    return Tag.fromMap(result.first);
  }

  Future<int> updateTag(Tag tag) async {
    final db = await database;
    
    // Prevent updating default tags
    if (tag.isDefault) {
      throw Exception('Cannot update default tags');
    }

    // Check if new name already exists (excluding current tag)
    final existingTag = await getTagByName(tag.title);
    if (existingTag != null && existingTag.id != tag.id) {
      throw Exception('Tag "${tag.title}" already exists');
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

    // Update all groups that use this tag to remove the tag reference
    final tagString = id.toString();
    await db.update(
      _tableAllDocs,
      {_keyTag: ''},
      where: '$_keyTag = ?',
      whereArgs: [tagString],
    );

    // Delete the tag (only if not default)
    return await db.delete(
      'Tags',
      where: 'id = ? AND is_default = 0',
      whereArgs: [id],
    );
  }

  /// Search documents
  Future<List<Document>> searchDocuments(String query) async {
    final allDocs = await getAllDocuments();
    return allDocs.where((doc) {
      return doc.title.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  /// Statistics
  Future<int> getDocumentCount() async {
    final groups = await getAllGroups();
    int count = 0;
    for (final group in groups) {
      if (group[_keyName]?.toString() == _binFolder) continue;
      final docs = await getGroupDocs(group[_keyName]?.toString() ?? '');
      count += docs.length;
    }
    return count;
  }

  Future<int> getTagCount() async {
    final tags = await getAllTags();
    return tags.length;
  }

  Future<int> getFavouriteCount() async {
    // Not directly supported in Kotlin structure
    return 0;
  }

  Future<int> getDocumentDetailCount(int documentId) async {
    final details = await getDocumentDetailsByDocumentId(documentId);
    return details.length;
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  /// Delete database
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, '$_databaseName.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
