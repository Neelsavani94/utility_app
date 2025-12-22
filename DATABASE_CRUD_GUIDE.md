# Database CRUD Operations Guide

This document provides a comprehensive guide to all CRUD (Create, Read, Update, Delete) operations available in the DatabaseHelper class.

## Overview

The DatabaseHelper class provides a complete database service with proper CRUD operations for all entities in the application. All operations include proper error handling, validation, and logging.

## Database Structure

- **Tags Table**: Tag management with default tags support
- **Documents Table**: Individual documents with modern structure
- **alldocs Table**: Main table for groups/folders
- **Dynamic Tables**: One per group/folder for storing group documents

## CRUD Operations

### Tags Operations

#### CREATE
```dart
// Create a new tag
final tag = Tag(title: 'My Tag');
final tagId = await DatabaseHelper.instance.createTag(tag);
```

#### READ
```dart
// Get all tags
final tags = await DatabaseHelper.instance.getAllTags();

// Get tag by ID
final tag = await DatabaseHelper.instance.getTagById(1);

// Get tag by name
final tag = await DatabaseHelper.instance.getTagByName('My Tag');

// Check if tag exists
final exists = await DatabaseHelper.instance.tagExists('My Tag');
```

#### UPDATE
```dart
// Update a tag
final updatedTag = tag.copyWith(title: 'Updated Tag');
await DatabaseHelper.instance.updateTag(updatedTag);
```

#### DELETE
```dart
// Delete a tag
await DatabaseHelper.instance.deleteTag(tagId);
```

### Documents Operations

#### CREATE
```dart
// Create a new document
final document = Document(
  title: 'My Document',
  type: 'PDF',
  imagePath: '/path/to/image.jpg',
  tagId: tagId,
);
final docId = await DatabaseHelper.instance.createDocument(document);
```

#### READ
```dart
// Get all documents
final documents = await DatabaseHelper.instance.getAllDocuments();

// Get document by ID
final document = await DatabaseHelper.instance.getDocumentById(1);

// Get documents by tag ID
final documents = await DatabaseHelper.instance.getDocumentsByTagId(tagId);

// Get favourite documents
final favourites = await DatabaseHelper.instance.getFavouriteDocuments();

// Search documents
final results = await DatabaseHelper.instance.searchDocuments('query');
```

#### UPDATE
```dart
// Update a document
final updatedDoc = document.copyWith(title: 'Updated Title');
await DatabaseHelper.instance.updateDocument(updatedDoc);

// Toggle favourite status
await DatabaseHelper.instance.toggleFavourite(docId, true);
```

#### DELETE
```dart
// Permanently delete a document
await DatabaseHelper.instance.deleteDocument(docId);

// Soft delete (move to trash)
await DatabaseHelper.instance.softDeleteDocument(docId);

// Restore from trash
await DatabaseHelper.instance.restoreDocument(docId);
```

### Document Details Operations

#### CREATE
```dart
// Create a new document detail
final detail = DocumentDetail(
  documentId: docId,
  title: 'Detail Title',
  type: 'Image',
  imagePath: '/path/to/image.jpg',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
final detailId = await DatabaseHelper.instance.createDocumentDetail(detail);
```

#### READ
```dart
// Get all details for a document
final details = await DatabaseHelper.instance.getDocumentDetailsByDocumentId(docId);

// Get document detail by ID
final detail = await DatabaseHelper.instance.getDocumentDetailById(detailId);
```

#### UPDATE
```dart
// Update a document detail
final updatedDetail = detail.copyWith(title: 'Updated Title');
await DatabaseHelper.instance.updateDocumentDetail(updatedDetail);
```

#### DELETE
```dart
// Permanently delete a document detail
await DatabaseHelper.instance.deleteDocumentDetail(detailId);

// Soft delete (move to trash)
await DatabaseHelper.instance.softDeleteDocumentDetail(detailId);
```

### Groups Operations

#### CREATE
```dart
// Create a new group
final groupId = await DatabaseHelper.instance.createGroup(
  groupName: 'My Group',
  groupDate: DateTime.now().toString(),
  groupTag: tagId.toString(),
  groupFirstImg: '/path/to/first/image.jpg',
);
```

#### READ
```dart
// Get all groups
final groups = await DatabaseHelper.instance.getAllGroups();

// Get groups by tag
final groups = await DatabaseHelper.instance.getGroupsByTag(tagId.toString());

// Get group by name
final group = await DatabaseHelper.instance.getSingleGroupsByName('My Group');

// Get group by ID
final group = await DatabaseHelper.instance.getGroupById(groupId);

// Get groups without first image
final groups = await DatabaseHelper.instance.getOnlyAllGroups();
```

#### UPDATE
```dart
// Rename a group
await DatabaseHelper.instance.updateGroupName('Old Name', 'New Name');

// Update group information
await DatabaseHelper.instance.updateGroup(
  groupName: 'My Group',
  groupTag: newTagId.toString(),
  groupFirstImg: '/path/to/new/image.jpg',
);
```

#### DELETE
```dart
// Delete a group permanently
await DatabaseHelper.instance.deleteGroup('My Group');
```

### Group Documents Operations

#### CREATE
```dart
// Add document to a group
final docId = await DatabaseHelper.instance.addGroupDoc(
  groupName: 'My Group',
  imgPath: '/path/to/image.jpg',
  imgName: 'Document Name',
  imgNote: 'Optional note',
);
```

#### READ
```dart
// Get all documents in a group
final docs = await DatabaseHelper.instance.getGroupDocs('My Group');

// Get shareable documents from a group
final shareDocs = await DatabaseHelper.instance.getShareGroupDocs('My Group');
```

#### UPDATE
```dart
// Update document in group
await DatabaseHelper.instance.updateGroupListDoc(
  'My Group',
  'Document Name',
  '/new/path/to/image.jpg',
);

// Update document note
await DatabaseHelper.instance.updateGroupListDocNote(
  'My Group',
  'Document Name',
  'New note',
);

// Rename document in group
await DatabaseHelper.instance.renameGroupListDocNote(
  'My Group',
  'Old Name',
  'New Name',
);
```

#### DELETE
```dart
// Delete document from group
await DatabaseHelper.instance.deleteSingleDoc('My Group', 'Document Name');

// Move document to trash
await DatabaseHelper.instance.moveToBin(
  oldFolderName: 'My Group',
  docData: docData,
);

// Restore document from trash
await DatabaseHelper.instance.moveFromBin(binDoc);
```

## Statistics

```dart
// Get document count
final docCount = await DatabaseHelper.instance.getDocumentCount();

// Get tag count
final tagCount = await DatabaseHelper.instance.getTagCount();

// Get favourite count
final favCount = await DatabaseHelper.instance.getFavouriteCount();

// Get document detail count
final detailCount = await DatabaseHelper.instance.getDocumentDetailCount(docId);
```

## Error Handling

All CRUD operations include proper error handling:

- **Validation**: Input validation before database operations
- **Error Logging**: All errors are logged using `log()`
- **Exception Throwing**: Meaningful exceptions are thrown for error cases
- **Null Safety**: Proper null checking throughout

## Best Practices

1. **Always check for null**: Use null-aware operators when working with results
2. **Handle exceptions**: Wrap database operations in try-catch blocks
3. **Validate input**: Validate data before creating/updating records
4. **Use transactions**: For multiple related operations, consider using transactions
5. **Close database**: Always close the database when done (handled automatically in most cases)

## Example Usage

```dart
// Complete example: Create tag, document, and details
try {
  // Create tag
  final tag = Tag(title: 'Work');
  final tagId = await DatabaseHelper.instance.createTag(tag);
  
  // Create document
  final document = Document(
    title: 'Project Plan',
    type: 'PDF',
    imagePath: '/path/to/project.pdf',
    tagId: tagId,
  );
  final docId = await DatabaseHelper.instance.createDocument(document);
  
  // Create document detail
  final detail = DocumentDetail(
    documentId: docId,
    title: 'Page 1',
    type: 'Image',
    imagePath: '/path/to/page1.jpg',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  final detailId = await DatabaseHelper.instance.createDocumentDetail(detail);
  
  // Get all documents
  final allDocs = await DatabaseHelper.instance.getAllDocuments();
  
  // Update document
  final updated = document.copyWith(title: 'Updated Project Plan');
  await DatabaseHelper.instance.updateDocument(updated);
  
  // Delete document
  await DatabaseHelper.instance.deleteDocument(docId);
} catch (e) {
  print('Error: $e');
}
```

## Notes

- All operations are asynchronous and return `Future` types
- The database is initialized automatically on first access
- Legacy methods are maintained for backward compatibility
- The database supports both new structure (Documents table) and old structure (groups) for compatibility

