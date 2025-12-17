# Database Usage Guide

## Overview

The database has been converted to match the Kotlin structure:
- **Main Table**: `alldocs` - Stores groups/folders
- **Dynamic Tables**: One per group - Stores documents within that group
- **Bin Table**: Special table for deleted documents

## Database Structure

### Main Table: `alldocs`
Columns:
- `id` - Primary key
- `name` - Group/folder name
- `date` - Creation date
- `tag` - Tag/category
- `firstimage` - First image path (for thumbnail)
- `pin` - PIN for security
- `biometric` - Biometric security flag

### Dynamic Tables (One per group)
Table name: Sanitized group name (spaces removed, alphanumeric + underscore)
Columns:
- `id` - Primary key
- `imgname` - Document/page name
- `imgnote` - Notes
- `imgpath` - Image file path
- `old_folder_names` - Original folder (for bin)
- `tag` - Tag
- `key_is_first_image_available` - First image flag
- `datev` - Date
- `pin` - PIN
- `biometric` - Biometric flag

## Usage in Services

### DocumentScanService

**Creating a new document group:**
```dart
// Create group table
await _dbHelper.createDocTable(groupName);

// Add group to alldocs
await _dbHelper.addGroup(
  groupName: groupName,
  groupDate: DateTime.now().toString(),
  groupTag: '1',
  groupFirstImg: firstImagePath,
);

// Add documents to group table
await _dbHelper.addGroupDoc(
  groupName: groupName,
  imgPath: imagePath,
  imgName: pageTitle,
  imgNote: '',
);
```

## Usage in Screens

### Home Screen (`home_screen.dart`)

**Loading documents:**
```dart
// Use compatibility method - automatically converts from new structure
final documents = await _db.getAllDocuments();
```

**Creating new document:**
```dart
// Use compatibility method
await _db.insertDocument(document);
```

**Getting document by ID:**
```dart
// Use compatibility method
final doc = await _db.getDocumentById(documentId);
```

**Updating document:**
```dart
// Use compatibility method
await _db.updateDocument(document);
```

**Moving to trash:**
```dart
// Use compatibility method
await _db.moveToTrash(documentId);
```

### Document Detail Screen (`document_detail_screen.dart`)

**Loading document details:**
```dart
// Use compatibility method
final details = await _dbHelper.getDocumentDetailsByDocumentId(documentId);
```

**Updating document detail:**
```dart
// Use compatibility method
await _dbHelper.updateDocumentDetail(detail);
```

### Trash Screen (`trash_screen.dart`)

**Loading deleted documents:**
```dart
// Use compatibility method
final deletedDocs = await _db.getDeletedDocuments();
```

**Permanently deleting:**
```dart
// Use compatibility method
await _db.deleteDocument(docId);
```

### Move/Copy Screen (`move_copy_screen.dart`)

**Copying document:**
```dart
// Use compatibility method
final newDocId = await _db.copyDocumentWithDetails(sourceDocId, targetTagId);
```

**Moving document:**
```dart
// Use compatibility method
await _db.moveDocumentToFolder(sourceDocId, targetTagId);
```

## Direct Database Methods (New Structure)

### Group Operations

```dart
// Create group table
await _db.createDocTable(groupName);

// Add group to alldocs
await _db.addGroup(
  groupName: 'My Document',
  groupDate: DateTime.now().toString(),
  groupTag: '1',
  groupFirstImg: '/path/to/image.jpg',
);

// Get all groups
final groups = await _db.getAllGroups();

// Get groups by tag
final groups = await _db.getGroupsByTag('1');

// Get single group by name
final group = await _db.getSingleGroupsByName('My Document');

// Update group name
await _db.updateGroupName('Old Name', 'New Name');

// Update group tag
await _db.updateTagName('My Document', '2');

// Delete group
await _db.deleteGroup('My Document');
```

### Document Operations (within groups)

```dart
// Add document to group
final docId = await _db.addGroupDoc(
  groupName: 'My Document',
  imgPath: '/path/to/image.jpg',
  imgName: 'Page 1',
  imgNote: 'Notes here',
);

// Get documents from group
final docs = await _db.getGroupDocs('My Document');

// Rename document in group
await _db.renameGroupListDocNote('My Document', 'Old Name', 'New Name');

// Update document path
await _db.updateGroupListDoc('My Document', 'Page 1', '/new/path.jpg');

// Update document note
await _db.updateGroupListDocNote('My Document', 'Page 1', 'New notes');

// Delete document from group
await _db.deleteSingleDoc('My Document', 'Page 1');
```

### Bin Operations

```dart
// Create bin table
await _db.createBinTable();

// Move document to bin
await _db.moveToBin(
  oldFolderName: 'My Document',
  docData: {
    'imgpath': '/path/to/image.jpg',
    'imgname': 'Page 1',
    'imgnote': 'Notes',
  },
);

// Get bin documents
final binDocs = await _db.getBinDocs();

// Move document from bin
await _db.moveFromBin(binDoc);
```

## Compatibility Methods

The database helper includes compatibility methods that convert between the new structure and the old `Document`/`DocumentDetail` models:

- `insertDocument(Document)` - Creates group and adds document
- `getAllDocuments()` - Converts all groups to Document list
- `getDocumentById(int)` - Finds document across all groups
- `updateDocument(Document)` - Updates document in its group
- `deleteDocument(int)` - Deletes document from its group
- `moveToTrash(int)` - Moves document to bin
- `getDeletedDocuments()` - Gets documents from bin
- `insertDocumentDetail(DocumentDetail)` - Adds to group table
- `getDocumentDetailsByDocumentId(int)` - Gets all pages from group
- `copyDocumentWithDetails(int, int?)` - Copies group and all pages
- `moveDocumentToFolder(int, int?)` - Moves group to new tag

## Best Practices

1. **Use Compatibility Methods**: For existing screens, use the compatibility methods to maintain code compatibility.

2. **Direct Methods for New Features**: For new features, use the direct database methods for better performance and clarity.

3. **Group Names**: Group names are sanitized (spaces removed, alphanumeric + underscore only). The database helper handles this automatically.

4. **Error Handling**: Always wrap database operations in try-catch blocks.

5. **Transactions**: For multiple related operations, consider using database transactions.

## Migration Notes

- Existing code using `Document` and `DocumentDetail` models will continue to work through compatibility methods.
- The new structure is more efficient for group-based operations.
- All screens should continue to work without changes due to compatibility layer.

