import 'dart:io';
import 'dart:typed_data';
import 'dart:core';

class ImageItem {
  final File originalFile;
  final int index;
  Uint8List? editedBytes;
  final String id;

  ImageItem({
    required this.originalFile,
    required this.index,
    this.editedBytes,
    String? id,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_$index';

  bool get isEdited => editedBytes != null;

  Future<Uint8List> loadBytes() async {
    if (editedBytes != null) return editedBytes!;
    return await originalFile.readAsBytes();
  }
}

