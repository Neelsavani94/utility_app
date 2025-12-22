import '../Models/document_model.dart';

/// Service to manage document clipboard for copy/paste operations
class ClipboardService {
  static final ClipboardService instance = ClipboardService._init();
  
  ClipboardService._init();

  Document? _copiedDocument;
  bool _hasCopiedDocument = false;
  String? _copiedGroupName;
  bool _hasCopiedGroup = false;

  /// Copy a document to clipboard
  void copyDocument(Document document) {
    _copiedDocument = document;
    _hasCopiedDocument = true;
    // Clear group clipboard when copying document
    _copiedGroupName = null;
    _hasCopiedGroup = false;
  }

  /// Copy a group to clipboard
  void copyGroup(String groupName) {
    _copiedGroupName = groupName;
    _hasCopiedGroup = true;
    // Clear document clipboard when copying group
    _copiedDocument = null;
    _hasCopiedDocument = false;
  }

  /// Get the copied document
  Document? getCopiedDocument() {
    return _copiedDocument;
  }

  /// Get the copied group name
  String? getCopiedGroupName() {
    return _copiedGroupName;
  }

  /// Check if there's a document in clipboard
  bool hasCopiedDocument() {
    return _hasCopiedDocument && _copiedDocument != null;
  }

  /// Check if there's a group in clipboard
  bool hasCopiedGroup() {
    return _hasCopiedGroup && _copiedGroupName != null && _copiedGroupName!.isNotEmpty;
  }

  /// Clear the clipboard
  void clearClipboard() {
    _copiedDocument = null;
    _hasCopiedDocument = false;
    _copiedGroupName = null;
    _hasCopiedGroup = false;
  }

  /// Get clipboard status message
  String getClipboardStatus() {
    if (hasCopiedDocument()) {
      return 'Copied: ${_copiedDocument!.title}';
    }
    if (hasCopiedGroup()) {
      return 'Copied: $_copiedGroupName';
    }
    return 'No document copied';
  }
}

