import 'dart:developer';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../Models/tag_model.dart';
import '../Models/document_model.dart';
import '../Models/document_detail_model.dart';

/// Database Helper with complete CRUD operations
/// 
/// This class provides a comprehensive database service with proper Create, Read, Update, Delete
/// operations for all entities in the application.
/// 
/// Database Structure:
/// - Main table: alldocs (id, name, date, tag, firstimage, pin, biometric)
/// - Documents table: Individual documents with modern structure
/// - Tags table: Tag management
/// - Dynamic tables: One per group/folder with columns:
///   id, imgname, imgnote, imgpath, old_folder_names, tag, key_is_first_image_available, datev, pin, biometric
/// 
/// CRUD Operations Available:
/// 
/// TAGS:
///   - createTag(Tag) - Create a new tag
///   - getAllTags() - Get all tags
///   - getTagById(int) - Get tag by ID
///   - getTagByName(String) - Get tag by name
///   - tagExists(String) - Check if tag exists
///   - updateTag(Tag) - Update an existing tag
///   - deleteTag(int) - Delete a tag
/// 
/// DOCUMENTS:
///   - createDocument(Document) - Create a new document
///   - getAllDocuments() - Get all non-deleted documents
///   - getDocumentById(int) - Get document by ID
///   - updateDocument(Document) - Update an existing document
///   - deleteDocument(int) - Permanently delete a document
///   - softDeleteDocument(int) - Soft delete (move to trash)
///   - restoreDocument(int) - Restore a soft-deleted document
///   - searchDocuments(String) - Search documents by title
/// 
/// DOCUMENT DETAILS:
///   - createDocumentDetail(DocumentDetail) - Create a new document detail
///   - getDocumentDetailsByDocumentId(int) - Get all details for a document
///   - getDocumentDetailById(int) - Get document detail by ID
///   - updateDocumentDetail(DocumentDetail) - Update an existing document detail
///   - deleteDocumentDetail(int) - Permanently delete a document detail
///   - softDeleteDocumentDetail(int) - Soft delete (move to trash)
/// 
/// GROUPS:
///   - createGroup(...) - Create a new group
///   - getAllGroups() - Get all groups
///   - getGroupsByTag(String) - Get groups by tag
///   - getSingleGroupsByName(String) - Get group by name
///   - getGroupById(int) - Get group by ID
///   - updateGroupName(String, String) - Rename a group
///   - updateGroup(...) - Update group information
///   - deleteGroup(String) - Permanently delete a group
/// 
/// GROUP DOCUMENTS:
///   - addGroupDoc(...) - Add document to a group
///   - getGroupDocs(String) - Get all documents in a group
///   - updateGroupListDoc(...) - Update document in group
///   - deleteSingleDoc(String, String) - Delete document from group
///   - moveToBin(...) - Move document to trash
///   - moveFromBin(...) - Restore document from trash
/// 
/// STATISTICS:
///   - getDocumentCount() - Get total document count
///   - getTagCount() - Get total tag count
///   - getFavouriteCount() - Get favourite count
///   - getDocumentDetailCount(int) - Get detail count for a document
/// 
/// Usage Example:
/// ```dart
/// // Create a tag
/// final tag = Tag(title: 'My Tag');
/// final tagId = await DatabaseHelper.instance.createTag(tag);
/// 
/// // Create a document
/// final document = Document(
///   title: 'My Document',
///   type: 'PDF',
///   imagePath: '/path/to/image.jpg',
///   tagId: tagId,
/// );
/// final docId = await DatabaseHelper.instance.createDocument(document);
/// 
/// // Get all documents
/// final documents = await DatabaseHelper.instance.getAllDocuments();
/// 
/// // Update document
/// final updatedDoc = document.copyWith(title: 'Updated Title');
/// await DatabaseHelper.instance.updateDocument(updatedDoc);
/// 
/// // Delete document
/// await DatabaseHelper.instance.deleteDocument(docId);
/// ```
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
    final db = await database;
    
    // Check if table actually exists in database
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    
    if (result.isNotEmpty) {
      return; // Table already exists
    }

    // Create the table
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

  // ==================== GROUPS CRUD OPERATIONS ====================
  
  /// CREATE: Add a new group to alldocs table
  /// @param groupName: Name of the group
  /// @param groupDate: Date string for the group
  /// @param groupTag: Optional tag ID
  /// @param groupFirstImg: Optional first image path
  /// @param groupPin: Optional PIN
  /// @param biometric: Optional biometric flag
  /// @returns: The ID of the inserted group
  /// @throws: Exception if group name already exists
  Future<int> createGroup({
    required String groupName,
    required String groupDate,
    String? groupTag,
    String? groupFirstImg,
    String? groupPin,
    String? biometric,
  }) async {
    try {
      // Validate group name
      if (groupName.trim().isEmpty) {
        throw Exception('Group name cannot be empty');
      }
      
      if (await isGroupNameExist(groupName)) {
        throw Exception('Document Name Already Exist');
      }

      final db = await database;
      
      // Create the group table first
      await createDocTable(groupName);
      
      // Insert into alldocs table
      final id = await db.insert(_tableAllDocs, {
        _keyName: groupName,
        _keyDate: groupDate,
        _keyTag: groupTag ?? '',
        _keyFirstImage: groupFirstImg ?? '',
        _keyPin: groupPin ?? '',
        _keyBiometric: biometric ?? '',
      });
      
      log('Group created with ID: $id');
      return id;
    } catch (e) {
      log('Error creating group: $e');
      rethrow;
    }
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

  /// READ: Get all groups
  /// @returns: List of all groups
  Future<List<Map<String, dynamic>>> getAllGroups() async {
    try {
      final db = await database;
      return await db.query(
        _tableAllDocs,
        orderBy: '$_keyDate DESC',
      );
    } catch (e) {
      log('Error getting all groups: $e');
      return [];
    }
  }

  /// READ: Get only groups without first image
  /// @returns: List of groups without first image
  Future<List<Map<String, dynamic>>> getOnlyAllGroups() async {
    try {
      final db = await database;
      final allGroups = await db.query(
        _tableAllDocs,
        orderBy: '$_keyDate DESC',
      );
      return allGroups.where((group) {
        final firstImage = group[_keyFirstImage]?.toString() ?? '';
        return firstImage.isEmpty;
      }).toList();
    } catch (e) {
      log('Error getting groups without first image: $e');
      return [];
    }
  }

  /// READ: Get groups by tag
  /// @param tag: Tag ID or tag name
  /// @returns: List of groups with the specified tag
  Future<List<Map<String, dynamic>>> getGroupsByTag(String tag) async {
    try {
      final db = await database;
      return await db.query(
        _tableAllDocs,
        where: '$_keyTag = ?',
        whereArgs: [tag],
        orderBy: '$_keyDate DESC',
      );
    } catch (e) {
      log('Error getting groups by tag: $e');
      return [];
    }
  }

  /// READ: Get single group by name
  /// @param groupName: Name of the group
  /// @returns: List containing the group (empty if not found)
  Future<List<Map<String, dynamic>>> getSingleGroupsByName(String groupName) async {
    try {
      final db = await database;
      return await db.query(
        _tableAllDocs,
        where: '$_keyName = ?',
        whereArgs: [groupName],
        limit: 1,
      );
    } catch (e) {
      log('Error getting group by name: $e');
      return [];
    }
  }
  
  /// READ: Get group by ID
  /// @param id: Group ID
  /// @returns: Group map or null if not found
  Future<Map<String, dynamic>?> getGroupById(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        _tableAllDocs,
        where: '$_keyId = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (result.isEmpty) return null;
      return result.first;
    } catch (e) {
      log('Error getting group by ID: $e');
      return null;
    }
  }

  /// Check if a table exists in the database
  Future<bool> _tableExists(String tableName) async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      return result.isNotEmpty;
    } catch (e) {
      log('Error checking if table exists: $e');
      return false;
    }
  }

  /// Get documents from a group table
  Future<List<Map<String, dynamic>>> getGroupDocs(String groupName) async {
    final tableName = _validateTableName(groupName);
    final db = await database;
    
    try {
      // Check if table exists before querying
      if (!await _tableExists(tableName)) {
        log('Table does not exist: $tableName');
        return [];
      }
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

  /// UPDATE: Update group name
  /// @param oldName: Current group name
  /// @param newName: New group name
  /// @throws: Exception if new name already exists
  Future<void> updateGroupName(String oldName, String newName) async {
    try {
      // Validate new name
      if (newName.trim().isEmpty) {
        throw Exception('Group name cannot be empty');
      }
      
      if (await isGroupNameExist(newName)) {
        throw Exception('Document Name Already Exist');
      }

      final db = await database;
      
      // Update in alldocs table
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
      
      log('Group renamed from $oldName to $newName');
    } catch (e) {
      log('Error updating group name: $e');
      rethrow;
    }
  }
  
  /// UPDATE: Update group information
  /// @param groupName: Name of the group to update
  /// @param groupTag: Optional new tag
  /// @param groupFirstImg: Optional new first image
  /// @param groupPin: Optional new PIN
  /// @param biometric: Optional new biometric flag
  /// @returns: Number of rows affected
  Future<int> updateGroup({
    required String groupName,
    String? groupTag,
    String? groupFirstImg,
    String? groupPin,
    String? biometric,
  }) async {
    try {
      final db = await database;
      
      final Map<String, dynamic> updates = {};
      if (groupTag != null) updates[_keyTag] = groupTag;
      if (groupFirstImg != null) updates[_keyFirstImage] = groupFirstImg;
      if (groupPin != null) updates[_keyPin] = groupPin;
      if (biometric != null) updates[_keyBiometric] = biometric;
      
      if (updates.isEmpty) {
        throw Exception('No fields to update');
      }
      
      final count = await db.update(
        _tableAllDocs,
        updates,
        where: '$_keyName = ?',
        whereArgs: [groupName],
      );
      
      log('Group updated: $groupName');
      return count;
    } catch (e) {
      log('Error updating group: $e');
      rethrow;
    }
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

  /// DELETE: Delete a group permanently
  /// @param groupName: Name of the group to delete
  /// @throws: Exception if group not found
  Future<void> deleteGroup(String groupName) async {
    try {
      final db = await database;
      
      // Check if group exists
      if (!await isGroupNameExist(groupName)) {
        throw Exception('Group not found');
      }
      
      // Delete from alldocs table
      await db.delete(
        _tableAllDocs,
        where: '$_keyName = ?',
        whereArgs: [groupName],
      );
      
      // Drop the group table
      final tableName = _validateTableName(groupName);
      await db.execute('DROP TABLE IF EXISTS $tableName');
      
      log('Group deleted: $groupName');
    } catch (e) {
      log('Error deleting group: $e');
      rethrow;
    }
  }
  
  // Legacy method for backward compatibility
  Future<int> addGroup({
    required String groupName,
    required String groupDate,
    String? groupTag,
    String? groupFirstImg,
    String? groupPin,
    String? biometric,
  }) => createGroup(
    groupName: groupName,
    groupDate: groupDate,
    groupTag: groupTag,
    groupFirstImg: groupFirstImg,
    groupPin: groupPin,
    biometric: biometric,
  );

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

  // ==================== DOCUMENTS CRUD OPERATIONS ====================
  
  /// CREATE: Insert a new document
  /// @param document: Document object to insert
  /// @returns: The ID of the inserted document
  Future<int> createDocument(Document document) async {
    try {
      final db = await database;
      
      // Validate document data
      if (document.title.trim().isEmpty) {
        throw Exception('Document title cannot be empty');
      }
      if (document.imagePath.trim().isEmpty) {
        throw Exception('Document image path cannot be empty');
      }
      
      // Prepare document with timestamps
      final now = DateTime.now();
      final docToInsert = document.copyWith(
        createdAt: document.createdAt == DateTime.now() ? now : document.createdAt,
        updatedAt: now,
      );
      
      // Insert into Documents table
      final id = await db.insert(
        _tableDocuments,
        docToInsert.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      log('Document created with ID: $id');
      return id;
    } catch (e) {
      log('Error creating document: $e');
      rethrow;
    }
  }

  /// READ: Get all documents
  /// @returns: List of all non-deleted documents
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
      final Set<int> processedDocumentIds = {}; // Track processed document IDs to avoid duplicates

      // First, add documents from new Documents table
      for (final map in maps) {
        try {
          final doc = Document.fromMap(map);
          documents.add(doc);
          if (doc.id != null) {
            processedDocumentIds.add(doc.id!);
          }
        } catch (e) {
          log('Error parsing document from Documents table: $e');
        }
      }

      // Then, add documents from old group structure (for backward compatibility)
      // Process all groups and add their files as documents
      // If a group has a corresponding document in Documents table, we still process it
      // because the group might have additional files that should be shown
      for (final group in groups) {
        if (group[_keyName]?.toString() == _binFolder) continue;
        
        final groupName = group[_keyName]?.toString() ?? '';
        if (groupName.isEmpty) continue;
        
        final tableName = _validateTableName(groupName);
        
        // Check if table exists before trying to get docs
        if (!await _tableExists(tableName)) {
          log('Skipping group $groupName - table does not exist');
          continue;
        }
        
        final docs = await getGroupDocs(groupName);
        
        // Check if there's a corresponding document in Documents table for this group
        final hasCorrespondingDocument = documents.any((doc) => 
          doc.title == groupName && doc.id != null
        );
        
        for (final doc in docs) {
          try {
            final docId = doc[_keyId] as int?;
            final docTitle = doc[_keyImgName]?.toString() ?? '';
            final docPath = doc[_keyImgPath]?.toString() ?? '';
            
            // If this group has a corresponding document, check if this file matches it
            // to avoid duplicates
            if (hasCorrespondingDocument) {
              final correspondingDoc = documents.firstWhere(
                (d) => d.title == groupName,
                orElse: () => Document(
                  title: '',
                  type: '',
                  imagePath: '',
                  createdAt: DateTime.now(),
                ),
              );
              
              // Skip if this file matches the corresponding document (same path)
              if (correspondingDoc.imagePath == docPath && 
                  correspondingDoc.title == docTitle) {
                continue;
              }
            }
            
            // Create document from group file
            documents.add(Document(
              id: docId,
              title: docTitle,
              type: 'Document',
              imagePath: docPath,
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

  /// READ: Get document by ID
  /// @param id: Document ID
  /// @returns: Document object or null if not found
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

  /// UPDATE: Update an existing document
  /// @param document: Document object with updated data
  /// @returns: Number of rows affected
  /// @throws: Exception if document ID is null or document not found
  Future<int> updateDocument(Document document) async {
    try {
      if (document.id == null) {
        throw Exception('Document ID is required for update');
      }
      
      final db = await database;
      
      // Validate document data
      if (document.title.trim().isEmpty) {
        throw Exception('Document title cannot be empty');
      }
      if (document.imagePath.trim().isEmpty) {
        throw Exception('Document image path cannot be empty');
      }
      
      // Check if document exists in Documents table
      final existingDoc = await getDocumentById(document.id!);
      if (existingDoc != null) {
        // Update in Documents table
        final docToUpdate = document.copyWith(updatedAt: DateTime.now());
        final count = await db.update(
          _tableDocuments,
          docToUpdate.toMap(),
          where: 'id = ?',
          whereArgs: [document.id],
        );
        log('Document updated: ${document.id}');
        return count;
      }
      
      // Fallback: Try to update in group structure (for backward compatibility)
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
            
            log('Document updated in group: ${document.id}');
            return 1;
          }
        }
      }
      
      throw Exception('Document not found');
    } catch (e) {
      log('Error updating document: $e');
      rethrow;
    }
  }

  /// DELETE: Delete a document permanently
  /// @param id: Document ID to delete
  /// @returns: Number of rows affected
  /// @throws: Exception if document not found
  Future<int> deleteDocument(int id) async {
    try {
      final db = await database;
      
      // Try to delete from Documents table first
      final existingDoc = await getDocumentById(id);
      if (existingDoc != null) {
        final count = await db.delete(
          _tableDocuments,
          where: 'id = ?',
          whereArgs: [id],
        );
        log('Document deleted: $id');
        return count;
      }
      
      // Fallback: Try to delete from group structure (for backward compatibility)
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
            log('Document deleted from group: $id');
            return 1;
          }
        }
      }
      
      throw Exception('Document not found');
    } catch (e) {
      log('Error deleting document: $e');
      rethrow;
    }
  }
  
  /// DELETE: Soft delete a document (move to trash)
  /// @param id: Document ID to soft delete
  /// @returns: Number of rows affected
  Future<int> softDeleteDocument(int id) async {
    try {
      final db = await database;
      
      // Try to soft delete from Documents table first
      final existingDoc = await getDocumentById(id);
      if (existingDoc != null) {
        final now = DateTime.now();
        final count = await db.update(
          _tableDocuments,
          {
            'isDeleted': 1,
            'deleted_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        log('Document soft deleted: $id');
        return count;
      }
      
      // Fallback: Use moveToTrash for group structure
      return await moveToTrash(id);
    } catch (e) {
      log('Error soft deleting document: $e');
      rethrow;
    }
  }
  
  /// RESTORE: Restore a soft-deleted document
  /// @param id: Document ID to restore
  /// @returns: Number of rows affected
  Future<int> restoreDocument(int id) async {
    try {
      final db = await database;
      final count = await db.update(
        _tableDocuments,
        {
          'isDeleted': 0,
          'deleted_at': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      log('Document restored: $id');
      return count;
    } catch (e) {
      log('Error restoring document: $e');
      rethrow;
    }
  }
  
  // Legacy method for backward compatibility
  Future<int> insertDocument(Document document) => createDocument(document);

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

  /// READ: Get documents by tag ID
  /// @param tagId: Tag ID to filter by (null for untagged documents)
  /// @returns: List of documents with the specified tag
  Future<List<Document>> getDocumentsByTagId(int? tagId) async {
    try {
      final db = await database;
      
      // Query from Documents table
      final List<Map<String, dynamic>> maps = await db.query(
        _tableDocuments,
        where: tagId == null 
            ? 'tag_id IS NULL AND isDeleted = ?'
            : 'tag_id = ? AND isDeleted = ?',
        whereArgs: tagId == null ? [0] : [tagId, 0],
        orderBy: 'created_at DESC',
      );
      
      final documents = maps.map((map) => Document.fromMap(map)).toList();
      
      // Also get from group structure for backward compatibility
      final allDocs = await getAllDocuments();
      final groupDocs = allDocs.where((doc) {
        if (tagId == null) {
          return doc.tagId == null && !documents.any((d) => d.id == doc.id);
        }
        return doc.tagId == tagId && !documents.any((d) => d.id == doc.id);
      }).toList();
      
      return [...documents, ...groupDocs];
    } catch (e) {
      log('Error getting documents by tag ID: $e');
      return [];
    }
  }
  
  /// READ: Get favourite documents
  /// @returns: List of favourite documents
  Future<List<Document>> getFavouriteDocuments() async {
    try {
      final db = await database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tableDocuments,
        where: 'isFavourite = ? AND isDeleted = ?',
        whereArgs: [1, 0],
        orderBy: 'created_at DESC',
      );
      
      return maps.map((map) => Document.fromMap(map)).toList();
    } catch (e) {
      log('Error getting favourite documents: $e');
      return [];
    }
  }
  
  /// UPDATE: Toggle favourite status of a document
  /// @param id: Document ID
  /// @param isFavourite: New favourite status
  /// @returns: Number of rows affected
  Future<int> toggleFavourite(int id, bool isFavourite) async {
    try {
      final db = await database;
      final count = await db.update(
        _tableDocuments,
        {'isFavourite': isFavourite ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      log('Document favourite toggled: $id -> $isFavourite');
      return count;
    } catch (e) {
      log('Error toggling favourite: $e');
      rethrow;
    }
  }

  // ==================== DOCUMENT DETAILS CRUD OPERATIONS ====================
  
  /// CREATE: Insert a new document detail
  /// @param detail: DocumentDetail object to insert
  /// @returns: The ID of the inserted document detail
  /// @throws: Exception if parent document not found
  Future<int> createDocumentDetail(DocumentDetail detail) async {
    try {
      // Validate document detail data
      if (detail.title.trim().isEmpty) {
        throw Exception('Document detail title cannot be empty');
      }
      if (detail.imagePath.trim().isEmpty) {
        throw Exception('Document detail image path cannot be empty');
      }
      
      // Get parent document to find group
      final parentDoc = await getDocumentById(detail.documentId);
      if (parentDoc == null) {
        throw Exception('Parent document not found');
      }

      // Use parent document title as group name
      final groupName = parentDoc.title;
      
      final id = await addGroupDoc(
        groupName: groupName,
        imgPath: detail.imagePath,
        imgName: detail.title,
        imgNote: '',
      );
      
      log('Document detail created with ID: $id');
      return id;
    } catch (e) {
      log('Error creating document detail: $e');
      rethrow;
    }
  }

  /// READ: Get document details by document ID
  /// @param documentId: Parent document ID
  /// @returns: List of document details for the given document
  Future<List<DocumentDetail>> getDocumentDetailsByDocumentId(int documentId) async {
    try {
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
    } catch (e) {
      log('Error getting document details: $e');
      return [];
    }
  }
  
  /// READ: Get document detail by ID
  /// @param id: Document detail ID
  /// @returns: DocumentDetail object or null if not found
  Future<DocumentDetail?> getDocumentDetailById(int id) async {
    try {
      final groups = await getAllGroups();
      
      for (final group in groups) {
        if (group[_keyName]?.toString() == _binFolder) continue;
        
        final groupName = group[_keyName]?.toString() ?? '';
        final docs = await getGroupDocs(groupName);
        
        for (final doc in docs) {
          if (doc[_keyId] == id) {
            // Find parent document
            final parentDoc = await getDocumentById(
              int.tryParse(group[_keyTag]?.toString() ?? '') ?? 0
            );
            
            return DocumentDetail(
              id: doc[_keyId] as int?,
              documentId: parentDoc?.id ?? 0,
              title: doc[_keyImgName]?.toString() ?? '',
              type: 'Document',
              imagePath: doc[_keyImgPath]?.toString() ?? '',
              createdAt: parentDoc?.createdAt ?? DateTime.now(),
              updatedAt: parentDoc?.updatedAt ?? DateTime.now(),
            );
          }
        }
      }
      
      return null;
    } catch (e) {
      log('Error getting document detail by ID: $e');
      return null;
    }
  }

  /// UPDATE: Update an existing document detail
  /// @param detail: DocumentDetail object with updated data
  /// @returns: Number of rows affected
  /// @throws: Exception if document detail ID is null or not found
  Future<int> updateDocumentDetail(DocumentDetail detail) async {
    try {
      if (detail.id == null) {
        throw Exception('Document detail ID is required for update');
      }
      
      // Validate document detail data
      if (detail.title.trim().isEmpty) {
        throw Exception('Document detail title cannot be empty');
      }
      if (detail.imagePath.trim().isEmpty) {
        throw Exception('Document detail image path cannot be empty');
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
      
      log('Document detail updated: ${detail.id}');
      return 1;
    } catch (e) {
      log('Error updating document detail: $e');
      rethrow;
    }
  }

  /// DELETE: Delete a document detail permanently
  /// @param id: Document detail ID to delete
  /// @returns: Number of rows affected
  /// @throws: Exception if document detail not found
  Future<int> deleteDocumentDetail(int id) async {
    try {
      // Find which group contains this document detail
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
            log('Document detail deleted: $id');
            return 1;
          }
        }
      }
      
      throw Exception('Document detail not found');
    } catch (e) {
      log('Error deleting document detail: $e');
      rethrow;
    }
  }
  
  /// DELETE: Soft delete a document detail (move to trash)
  /// @param id: Document detail ID to soft delete
  /// @returns: Number of rows affected
  Future<int> softDeleteDocumentDetail(int id) async {
    try {
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
            
            log('Document detail moved to trash: $id');
            return 1;
          }
        }
      }
      
      throw Exception('Document detail not found');
    } catch (e) {
      log('Error soft deleting document detail: $e');
      rethrow;
    }
  }
  
  // Legacy method for backward compatibility
  Future<int> insertDocumentDetail(DocumentDetail detail) => createDocumentDetail(detail);
  
  // Legacy method for backward compatibility
  Future<int> moveDocumentDetailToTrash(int id) => softDeleteDocumentDetail(id);


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

  // ==================== TAGS CRUD OPERATIONS ====================
  
  /// CREATE: Insert a new tag
  /// @param tag: Tag object to insert
  /// @returns: The ID of the inserted tag
  /// @throws: Exception if tag already exists
  Future<int> createTag(Tag tag) async {
    try {
      final db = await database;
      
      // Validate tag title
      if (tag.title.trim().isEmpty) {
        throw Exception('Tag title cannot be empty');
      }
      
      // Check if tag already exists (case-insensitive)
      final existing = await tagExists(tag.title);
      if (existing) {
        throw Exception('Tag "${tag.title}" already exists');
      }

      final now = DateTime.now();
      final tagToInsert = tag.copyWith(createdAt: now, updatedAt: now);
      final id = await db.insert('Tags', tagToInsert.toMap());
      log('Tag created with ID: $id');
      return id;
    } catch (e) {
      log('Error creating tag: $e');
      rethrow;
    }
  }

  /// READ: Get all tags
  /// @returns: List of all tags, ordered by default status and creation date
  Future<List<Tag>> getAllTags() async {
    try {
      final db = await database;
      final result = await db.query(
        'Tags',
        orderBy: 'is_default DESC, created_at DESC',
      );
      return result.map((map) => Tag.fromMap(map)).toList();
    } catch (e) {
      log('Error getting all tags: $e');
      return [];
    }
  }

  /// READ: Get tag by ID
  /// @param id: Tag ID
  /// @returns: Tag object or null if not found
  Future<Tag?> getTagById(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        'Tags',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (result.isEmpty) return null;
      return Tag.fromMap(result.first);
    } catch (e) {
      log('Error getting tag by ID: $e');
      return null;
    }
  }

  /// READ: Get tag by name (case-insensitive)
  /// @param tagName: Tag name to search for
  /// @returns: Tag object or null if not found
  Future<Tag?> getTagByName(String tagName) async {
    try {
      final db = await database;
      final result = await db.query(
        'Tags',
        where: 'LOWER(title) = LOWER(?)',
        whereArgs: [tagName.trim()],
        limit: 1,
      );
      if (result.isEmpty) return null;
      return Tag.fromMap(result.first);
    } catch (e) {
      log('Error getting tag by name: $e');
      return null;
    }
  }

  /// READ: Check if tag exists (case-insensitive)
  /// @param tagName: Tag name to check
  /// @returns: True if tag exists, false otherwise
  Future<bool> tagExists(String tagName) async {
    try {
      final db = await database;
      final result = await db.query(
        'Tags',
        where: 'LOWER(title) = LOWER(?)',
        whereArgs: [tagName.trim()],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      log('Error checking if tag exists: $e');
      return false;
    }
  }

  /// UPDATE: Update an existing tag
  /// @param tag: Tag object with updated data
  /// @returns: Number of rows affected
  /// @throws: Exception if tag is default or name already exists
  Future<int> updateTag(Tag tag) async {
    try {
      if (tag.id == null) {
        throw Exception('Tag ID is required for update');
      }
      
      final db = await database;
      
      // Prevent updating default tags
      final existingTag = await getTagById(tag.id!);
      if (existingTag == null) {
        throw Exception('Tag not found');
      }
      
      if (existingTag.isDefault) {
        throw Exception('Cannot update default tags');
      }

      // Validate new title
      if (tag.title.trim().isEmpty) {
        throw Exception('Tag title cannot be empty');
      }

      // Check if new name already exists (excluding current tag)
      final tagWithSameName = await getTagByName(tag.title);
      if (tagWithSameName != null && tagWithSameName.id != tag.id) {
        throw Exception('Tag "${tag.title}" already exists');
      }

      final tagToUpdate = tag.copyWith(updatedAt: DateTime.now());
      final count = await db.update(
        'Tags',
        tagToUpdate.toMap(),
        where: 'id = ? AND is_default = 0',
        whereArgs: [tag.id],
      );
      log('Tag updated: ${tag.id}');
      return count;
    } catch (e) {
      log('Error updating tag: $e');
      rethrow;
    }
  }

  /// DELETE: Delete a tag
  /// @param id: Tag ID to delete
  /// @returns: Number of rows affected
  /// @throws: Exception if tag is default
  Future<int> deleteTag(int id) async {
    try {
      final db = await database;
      
      // Check if tag exists and is default
      final tag = await getTagById(id);
      if (tag == null) {
        throw Exception('Tag not found');
      }
      
      if (tag.isDefault) {
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

      // Delete the tag
      final count = await db.delete(
        'Tags',
        where: 'id = ? AND is_default = 0',
        whereArgs: [id],
      );
      log('Tag deleted: $id');
      return count;
    } catch (e) {
      log('Error deleting tag: $e');
      rethrow;
    }
  }

  // Legacy method for backward compatibility
  Future<int> insertTag(Tag tag) => createTag(tag);

  /// Search documents
  Future<List<Document>> searchDocuments(String query) async {
    final allDocs = await getAllDocuments();
    return allDocs.where((doc) {
      return doc.title.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // ==================== STATISTICS METHODS ====================
  
  /// STATISTICS: Get total document count
  /// @returns: Total number of non-deleted documents
  Future<int> getDocumentCount() async {
    try {
      final db = await database;
      
      // Count from Documents table
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableDocuments WHERE isDeleted = ?',
        [0],
      );
      final docTableCount = Sqflite.firstIntValue(result) ?? 0;
      
      // Count from group structure (for backward compatibility)
      final groups = await getAllGroups();
      int groupCount = 0;
      for (final group in groups) {
        if (group[_keyName]?.toString() == _binFolder) continue;
        final docs = await getGroupDocs(group[_keyName]?.toString() ?? '');
        groupCount += docs.length;
      }
      
      return docTableCount + groupCount;
    } catch (e) {
      log('Error getting document count: $e');
      return 0;
    }
  }

  /// STATISTICS: Get total tag count
  /// @returns: Total number of tags
  Future<int> getTagCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM Tags',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      log('Error getting tag count: $e');
      return 0;
    }
  }

  /// STATISTICS: Get count of favourite documents
  /// @returns: Number of favourite documents
  Future<int> getFavouriteCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableDocuments WHERE isFavourite = ? AND isDeleted = ?',
        [1, 0],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      log('Error getting favourite count: $e');
      return 0;
    }
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
