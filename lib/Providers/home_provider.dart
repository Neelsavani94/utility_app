import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
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
  List<DocumentModel> _documents = [];
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
  List<DocumentModel> get documents => _documents;
  int get selectedBottomNavIndex => _selectedBottomNavIndex;

  bool get hasDocuments => _documents.isNotEmpty;

  bool get isLoading => _isLoading;

  List<DocumentModel> get filteredDocuments {
    // Documents are already filtered to exclude folders in loadDocuments()
    // Just exclude deleted items from the main view
    var filtered = _documents.where((doc) => !doc.isDeleted).toList();

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
    final index = _documents.indexWhere((doc) => doc.id == documentId);
    if (index != -1) {
      final document = _documents[index];
      final newFavoriteStatus = !document.isFavorite;
      
      try {
        // Update in database
        final docId = int.tryParse(documentId);
        if (docId != null) {
          await _db.toggleFavourite(docId, newFavoriteStatus);
        }
        
        // Update local state
        _documents[index] = DocumentModel(
          id: document.id,
          name: document.name,
          createdAt: document.createdAt,
          location: document.location,
          category: document.category,
          isFavorite: newFavoriteStatus,
          thumbnailPath: document.thumbnailPath,
          isDeleted: document.isDeleted,
          deletedAt: document.deletedAt,
        );
        notifyListeners();
      } catch (e) {
        print('Error toggling favorite: $e');
        // Revert on error
        notifyListeners();
      }
    }
  }

  Future<void> loadDocuments() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load all documents from database (excluding folders)
      final dbDocuments = await _db.getAllDocuments();

      // Load all tags to map tag IDs to tag titles
      final tags = await _db.getAllTags();
      final tagMap = {for (var tag in tags) tag.id: tag.title};

      // Convert database Documents to UI DocumentModels
      // Filter out folders (type = 'Folder') from the main documents list
      _documents = dbDocuments.map((doc) {
        // Get tag title for category, or use document type
        final category = doc.tagId != null && tagMap.containsKey(doc.tagId)
            ? tagMap[doc.tagId]!
            : doc.type;

        return DocumentModel.fromDocument(
          doc,
          category: category,
          location: 'In this device',
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      // Handle error - could show a snackbar or log
      print('Error loading documents: $e');
    }
  }

  void addDocument(DocumentModel document) {
    _documents.insert(0, document);
    notifyListeners();
  }

  void deleteDocument(String documentId) {
    _documents.removeWhere((doc) => doc.id == documentId);
    notifyListeners();
  }

  Future<void> moveToTrash(String documentId) async {
    try {
      // Update in database
      final docId = int.tryParse(documentId);
      if (docId != null) {
        await _db.moveToTrash(docId);
        // Reload documents to get updated list without deleted items
        await loadDocuments();
      }
    } catch (e) {
      print('Error moving to trash: $e');
      notifyListeners();
    }
  }

  void restoreDocument(String documentId) {
    final index = _documents.indexWhere((doc) => doc.id == documentId);
    if (index != -1) {
      _documents[index] = DocumentModel(
        id: _documents[index].id,
        name: _documents[index].name,
        createdAt: _documents[index].createdAt,
        location: _documents[index].location,
        category: _documents[index].category,
        isFavorite: _documents[index].isFavorite,
        thumbnailPath: _documents[index].thumbnailPath,
        isDeleted: false,
        deletedAt: null,
      );
      notifyListeners();
    }
  }

  void permanentlyDeleteDocument(String documentId) {
    _documents.removeWhere((doc) => doc.id == documentId);
    notifyListeners();
  }
}
