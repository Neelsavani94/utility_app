import '../Models/document_model.dart';

/// Service to manage document clipboard for copy/paste operations
class ClipboardService {
  static final ClipboardService instance = ClipboardService._init();
  
  ClipboardService._init();

  Document? _copiedDocument;
  bool _hasCopiedDocument = false;

  /// Copy a document to clipboard
  void copyDocument(Document document) {
    _copiedDocument = document;
    _hasCopiedDocument = true;
  }

  /// Get the copied document
  Document? getCopiedDocument() {
    return _copiedDocument;
  }

  /// Check if there's a document in clipboard
  bool hasCopiedDocument() {
    return _hasCopiedDocument && _copiedDocument != null;
  }

  /// Clear the clipboard
  void clearClipboard() {
    _copiedDocument = null;
    _hasCopiedDocument = false;
  }

  /// Get clipboard status message
  String getClipboardStatus() {
    if (hasCopiedDocument()) {
      return 'Copied: ${_copiedDocument!.title}';
    }
    return 'No document copied';
  }
}

