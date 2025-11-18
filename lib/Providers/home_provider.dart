import 'package:flutter/material.dart';
import '../Models/document_model.dart';

class HomeProvider extends ChangeNotifier {
  String _selectedCategory = 'All Docs';
  String _searchQuery = '';
  List<DocumentModel> _documents = [];
  int _selectedBottomNavIndex = 0;

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  List<DocumentModel> get documents => _documents;
  int get selectedBottomNavIndex => _selectedBottomNavIndex;

  bool get hasDocuments => _documents.isNotEmpty;

  List<DocumentModel> get filteredDocuments {
    var filtered = _documents;

    // Filter by category
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

  void setSelectedBottomNavIndex(int index) {
    _selectedBottomNavIndex = index;
    notifyListeners();
  }

  void toggleFavorite(String documentId) {
    final index = _documents.indexWhere((doc) => doc.id == documentId);
    if (index != -1) {
      _documents[index] = DocumentModel(
        id: _documents[index].id,
        name: _documents[index].name,
        createdAt: _documents[index].createdAt,
        location: _documents[index].location,
        category: _documents[index].category,
        isFavorite: !_documents[index].isFavorite,
        thumbnailPath: _documents[index].thumbnailPath,
      );
      notifyListeners();
    }
  }

  void loadDocuments() {
    // Mock data - replace with actual data loading
    _documents = [
      DocumentModel(
        id: '1',
        name: 'Doc_1811203927',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        location: 'In this device',
        category: 'All Docs',
        isFavorite: false,
      ),
      DocumentModel(
        id: '2',
        name: 'Doc_1811203927',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        location: 'In this device',
        category: 'All Docs',
        isFavorite: false,
      ),
      DocumentModel(
        id: '3',
        name: 'Doc_1811203927',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        location: 'In this device',
        category: 'All Docs',
        isFavorite: false,
      ),
      DocumentModel(
        id: '4',
        name: 'Doc_1811203927',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        location: 'In this device',
        category: 'All Docs',
        isFavorite: false,
      ),
    ];
    notifyListeners();
  }

  void addDocument(DocumentModel document) {
    _documents.insert(0, document);
    notifyListeners();
  }

  void deleteDocument(String documentId) {
    _documents.removeWhere((doc) => doc.id == documentId);
    notifyListeners();
  }
}
