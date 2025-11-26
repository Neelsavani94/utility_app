import 'dart:io';
import 'dart:core';

class CompressFileItem {
  final File originalFile;
  final String fileName;
  final String fileExtension;
  final int originalSize;
  int? compressedSize;
  File? compressedFile;
  final String id;
  bool isCompressed = false;
  bool isCompressing = false;

  CompressFileItem({
    required this.originalFile,
    required this.fileName,
    required this.fileExtension,
    required this.originalSize,
    this.compressedSize,
    this.compressedFile,
    String? id,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_${originalFile.path.hashCode}';

  String get fileType {
    final ext = fileExtension.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)) {
      return 'image';
    } else if (ext == 'pdf') {
      return 'pdf';
    } else {
      return 'file';
    }
  }

  double get compressionRatio {
    if (compressedSize == null) return 0.0;
    return ((originalSize - compressedSize!) / originalSize) * 100;
  }

  String get formattedOriginalSize {
    if (originalSize < 1024) return '$originalSize B';
    if (originalSize < 1024 * 1024) return '${(originalSize / 1024).toStringAsFixed(2)} KB';
    return '${(originalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedCompressedSize {
    if (compressedSize == null) return '-';
    if (compressedSize! < 1024) return '${compressedSize!} B';
    if (compressedSize! < 1024 * 1024) return '${(compressedSize! / 1024).toStringAsFixed(2)} KB';
    return '${(compressedSize! / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

