import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:developer' as developer;
import '../Models/document_model.dart';
import '../Services/database_helper.dart';

class HomeProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final GetStorage _storage = GetStorage();
  static const String _viewModeKey = 'home_view_mode';
  
  String _selectedCategory = 'All Docs';
  String _searchQuery = '';
  String _sortBy = 'date_desc'; // Default: newest first
  String _viewMode = 'list'; // 'list' or 'grid'
  List<DocumentModel> _homeDocuments = []; // For Home Screen (groups)
  List<DocumentModel> _importDocuments = []; // For Import File Screen (individual documents)
  int _selectedBottomNavIndex = 0;
  bool _isLoading = false;

  HomeProvider() {
    // Load view mode from storage on initialization
    _loadViewMode();
  }

  void _loadViewMode() {
    final savedViewMode = _storage.read<String>(_viewModeKey);
    if (savedViewMode != null && (savedViewMode == 'list' || savedViewMode == 'grid')) {
      _viewMode = savedViewMode;
      notifyListeners();
    }
  }

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  String get viewMode => _viewMode;
  List<DocumentModel> get documents => _homeDocuments; // For backward compatibility
  List<DocumentModel> get homeDocuments => _homeDocuments; // For Home Screen
  List<DocumentModel> get importDocuments => _importDocuments; // For Import File Screen
  int get selectedBottomNavIndex => _selectedBottomNavIndex;

  bool get hasDocuments => _homeDocuments.isNotEmpty;
  bool get hasImportDocuments => _importDocuments.isNotEmpty;

  bool get isLoading => _isLoading;

  // Filtered documents for Home Screen (groups)
  List<DocumentModel> get filteredDocuments {
    // Documents are already filtered to exclude folders in loadDocuments()
    // Just exclude deleted items from the main view
    var filtered = _homeDocuments.where((doc) => !doc.isDeleted).toList();

    // Filter by category/tag
    if (_selectedCategory != 'All Docs') {
      filtered = filtered
          .where((doc) => doc.category == _selectedCategory)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (doc) =>
                doc.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'name_asc':
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'name_desc':
        filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'date_asc':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'date_desc':
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return filtered;
  }

  // Filtered documents for Import File Screen (individual documents)
  List<DocumentModel> get filteredImportDocuments {
    var filtered = _importDocuments.where((doc) => !doc.isDeleted).toList();

    // Filter by category/tag
    if (_selectedCategory != 'All Docs') {
      filtered = filtered
          .where((doc) => doc.category == _selectedCategory)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (doc) =>
                doc.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'name_asc':
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'name_desc':
        filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'date_asc':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'date_desc':
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return filtered;
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void setViewMode(String viewMode) {
    _viewMode = viewMode;
    // Save to storage
    _storage.write(_viewModeKey, viewMode);
    notifyListeners();
  }

  void setSelectedBottomNavIndex(int index) {
    _selectedBottomNavIndex = index;
    notifyListeners();
  }

  Future<void> toggleFavorite(String documentId) async {
    // Check in home documents first (groups)
    var index = _homeDocuments.indexWhere((doc) => doc.id == documentId);
    List<DocumentModel>? targetList = index != -1 ? _homeDocuments : null;
    
    // If not found, check in import documents
    if (index == -1) {
      index = _importDocuments.indexWhere((doc) => doc.id == documentId);
      targetList = index != -1 ? _importDocuments : null;
    }
    
    if (index != -1 && targetList != null) {
      final document = targetList[index];
      final newFavoriteStatus = !document.isFavorite;
      
      try {
        // Update in database
        final docId = int.tryParse(documentId);
        if (docId != null) {
          // Update Document table
          await _db.updateDocument(docId, {
            'favourite': newFavoriteStatus ? 1 : 0,
            'updated_date': DateTime.now().toIso8601String(),
          });
          
          // Manage FavouriteDocuments table
          if (newFavoriteStatus) {
            // Add to FavouriteDocuments table
            // Check if already exists
            final existingFavs = await _db.getFavouriteDocumentsByDocumentId(docId);
            if (existingFavs.isEmpty) {
              // Get document data to create FavouriteDocuments entry
              final docData = await _db.getDocument(docId);
              if (docData != null) {
                final timestamp = DateTime.now();
                await _db.createFavouriteDocument({
                  'document_id': docId,
                  'title': docData['title']?.toString() ?? document.name,
                  'Image_path': docData['Image_path']?.toString() ?? document.imagePath ?? '',
                  'image_thumbnail': docData['image_thumbnail']?.toString() ?? document.thumbnailPath ?? '',
                  'created_date': timestamp.toIso8601String(),
                  'updated_date': timestamp.toIso8601String(),
                });
                developer.log('✓ Added to FavouriteDocuments table');
              }
            }
          } else {
            // Remove from FavouriteDocuments table
            final existingFavs = await _db.getFavouriteDocumentsByDocumentId(docId);
            for (var favDoc in existingFavs) {
              final favId = favDoc['id'] as int?;
              if (favId != null) {
                await _db.deleteFavouriteDocument(favId);
                developer.log('✓ Removed from FavouriteDocuments table');
              }
            }
          }
        }
        
        // Update local state
        targetList[index] = DocumentModel(
          id: document.id,
          name: document.name,
          createdAt: document.createdAt,
          location: document.location,
          category: document.category,
          isFavorite: newFavoriteStatus,
          thumbnailPath: document.thumbnailPath,
          imagePath: document.imagePath,
          isDeleted: document.isDeleted,
          deletedAt: document.deletedAt,
        );
        notifyListeners();
      } catch (e) {
        developer.log('Error toggling favorite: $e');
        // Revert on error
        notifyListeners();
      }
    }
  }

  Future<void> loadDocuments() async {
    developer.log('=== loadDocuments START ===');
    _isLoading = true;
    notifyListeners();

    try {
      // Load all documents from Document table (non-deleted only)
      developer.log('Loading all documents from Document table...');
      final dbDocuments = await _db.getDocumentsNotDeleted();
      developer.log('✓ Retrieved ${dbDocuments.length} documents from Document table');
      
      // Load all tags to map tag IDs to tag titles
      final tags = await _db.getAllTags();
      final tagMap = <int, String>{};
      for (var tagMapData in tags) {
        final tagId = tagMapData['id'] as int?;
        final tagTitle = tagMapData['title'] as String?;
        if (tagId != null && tagTitle != null) {
          tagMap[tagId] = tagTitle;
        }
      }
      developer.log('✓ Loaded ${tags.length} tags');

      // Convert database documents to UI DocumentModels
      _homeDocuments = dbDocuments.map((docMap) {
        // Map database field names to Document model fields
        final docId = docMap['id'] as int?;
        final title = docMap['title']?.toString() ?? '';
        final type = docMap['type']?.toString() ?? '';
        final favourite = (docMap['favourite'] as int? ?? 0) == 1;
        final imagePath = docMap['Image_path']?.toString() ?? '';
        final thumbnailPath = docMap['image_thumbnail']?.toString();
        final isDeleted = (docMap['is_deleted'] as int? ?? 0) == 1;
        
        // Parse dates
        DateTime createdAt;
        try {
          final createdDateStr = docMap['created_date']?.toString();
          if (createdDateStr != null && createdDateStr.isNotEmpty) {
            createdAt = DateTime.parse(createdDateStr);
          } else {
            createdAt = DateTime.now();
          }
        } catch (e) {
          developer.log('⚠ Error parsing created_date: $e');
          createdAt = DateTime.now();
        }

        // Get category from tag (if tag_id exists in future schema)
        // For now, use type as category
        final category = type.isNotEmpty ? type : 'All Docs';

        // Create DocumentModel from database document
        return DocumentModel(
          id: docId?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: title,
          createdAt: createdAt,
          location: 'In this device',
          category: category,
          isFavorite: favourite,
          thumbnailPath: thumbnailPath,
          imagePath: imagePath.isNotEmpty ? imagePath : thumbnailPath,
          isDeleted: isDeleted,
          deletedAt: null,
        );
      }).toList();

      developer.log('✓ Converted ${_homeDocuments.length} documents to DocumentModels');
      developer.log('=== loadDocuments COMPLETE ===');

      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      developer.log('✗ Error loading documents: $e');
      developer.log('Stack trace: $stackTrace');
      _isLoading = false;
      _homeDocuments = []; // Clear documents on error
      notifyListeners();
    }
  }

  /// Load documents from Documents table (for Import Files Screen)
  Future<void> loadDocumentsFromTable() async {
    developer.log('=== loadDocumentsFromTable START ===');
    _isLoading = true;
    notifyListeners();

    try {
      // Load all documents from Documents table
      developer.log('Loading all documents from Documents table...');
      final dbDocuments = await _db.getAllDocuments();
      developer.log('✓ Retrieved ${dbDocuments.length} documents from Documents table');

      // Load all tags to map tag IDs to tag titles
      final tags = await _db.getAllTags();
      final tagMap = <int, String>{};
      for (var tagMapData in tags) {
        final tagId = tagMapData['id'] as int?;
        final tagTitle = tagMapData['title'] as String?;
        if (tagId != null && tagTitle != null) {
          tagMap[tagId] = tagTitle;
        }
      }
      developer.log('✓ Loaded ${tags.length} tags');

      // Convert database documents to UI DocumentModels
      _importDocuments = dbDocuments.map((docMap) {
        // Map database field names to Document model fields
        final docId = docMap['id'] as int?;
        final title = docMap['title']?.toString() ?? '';
        final type = docMap['type']?.toString() ?? '';
        final favourite = (docMap['favourite'] as int? ?? 0) == 1;
        final imagePath = docMap['Image_path']?.toString() ?? '';
        final thumbnailPath = docMap['image_thumbnail']?.toString();
        final isDeleted = (docMap['is_deleted'] as int? ?? 0) == 1;
        
        // Parse dates
        DateTime createdAt;
        try {
          final createdDateStr = docMap['created_date']?.toString();
          if (createdDateStr != null && createdDateStr.isNotEmpty) {
            createdAt = DateTime.parse(createdDateStr);
          } else {
            createdAt = DateTime.now();
          }
        } catch (e) {
          developer.log('⚠ Error parsing created_date: $e');
          createdAt = DateTime.now();
        }

        // Get category from type (tag_id not in Document table schema)
        final category = type.isNotEmpty ? type : 'All Docs';

        // Create DocumentModel from database document
        return DocumentModel(
          id: docId?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: title,
          createdAt: createdAt,
          location: 'In this device',
          category: category,
          isFavorite: favourite,
          thumbnailPath: thumbnailPath,
          imagePath: imagePath.isNotEmpty ? imagePath : thumbnailPath,
          isDeleted: isDeleted,
          deletedAt: null,
        );
      }).toList();

      developer.log('✓ Converted ${_importDocuments.length} documents to DocumentModels');
      developer.log('=== loadDocumentsFromTable COMPLETE ===');

      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      developer.log('✗ Error loading documents from table: $e');
      developer.log('Stack trace: $stackTrace');
      _isLoading = false;
      _importDocuments = []; // Clear documents on error
      notifyListeners();
    }
  }

  void addDocument(DocumentModel document) {
    _homeDocuments.insert(0, document);
    notifyListeners();
  }

  void addImportDocument(DocumentModel document) {
    _importDocuments.insert(0, document);
    notifyListeners();
  }

  void deleteDocument(String documentId) {
    _homeDocuments.removeWhere((doc) => doc.id == documentId);
    notifyListeners();
  }

  void deleteImportDocument(String documentId) {
    _importDocuments.removeWhere((doc) => doc.id == documentId);
    notifyListeners();
  }

  Future<void> moveToTrash(String documentId) async {
    try {
      // Update in database
      final docId = int.tryParse(documentId);
      if (docId != null) {
        // Get document details before moving to trash
        final document = await _db.getDocument(docId);
        if (document != null) {
          // Add entry to TrashDocuments table
          await _db.createTrashDocument({
            'document_id': docId,
            'title': document['title'] ?? '',
            'created_date': document['created_date'] ?? DateTime.now().toIso8601String(),
            'updated_date': DateTime.now().toIso8601String(),
            'Image_path': document['Image_path'] ?? '',
            'image_thumbnail': document['image_thumbnail'] ?? '',
          });

          // Set is_deleted to true in Document table
          await _db.softDeleteDocument(docId);
        }
        
        // Reload documents to get updated list without deleted items
        await loadDocuments();
      }
    } catch (e) {
      developer.log('Error moving to trash: $e');
      notifyListeners();
    }
  }

  void restoreDocument(String documentId) {
    // Check in home documents first
    var index = _homeDocuments.indexWhere((doc) => doc.id == documentId);
    List<DocumentModel>? targetList = index != -1 ? _homeDocuments : null;
    
    // If not found, check in import documents
    if (index == -1) {
      index = _importDocuments.indexWhere((doc) => doc.id == documentId);
      targetList = index != -1 ? _importDocuments : null;
    }
    
    if (index != -1 && targetList != null) {
      targetList[index] = DocumentModel(
        id: targetList[index].id,
        name: targetList[index].name,
        createdAt: targetList[index].createdAt,
        location: targetList[index].location,
        category: targetList[index].category,
        isFavorite: targetList[index].isFavorite,
        thumbnailPath: targetList[index].thumbnailPath,
        isDeleted: false,
        deletedAt: null,
      );
      notifyListeners();
    }
  }

  void permanentlyDeleteDocument(String documentId) {
    _homeDocuments.removeWhere((doc) => doc.id == documentId);
    _importDocuments.removeWhere((doc) => doc.id == documentId);
    notifyListeners();
  }
}
