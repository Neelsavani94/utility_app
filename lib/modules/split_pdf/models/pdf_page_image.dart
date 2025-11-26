import 'dart:io';
import 'dart:typed_data';
import 'dart:core';

class PdfPageImage {
  final int pageNumber;
  final File? imageFile;
  final Uint8List? imageBytes;
  Uint8List? editedBytes;
  final String id;

  PdfPageImage({
    required this.pageNumber,
    this.imageFile,
    this.imageBytes,
    this.editedBytes,
    String? id,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_$pageNumber';

  bool get isEdited => editedBytes != null;

  Future<Uint8List> loadBytes() async {
    if (editedBytes != null) return editedBytes!;
    if (imageBytes != null) return imageBytes!;
    if (imageFile != null) return await imageFile!.readAsBytes();
    throw Exception('No image data available');
  }
}

