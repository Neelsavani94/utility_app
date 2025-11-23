class ExtractedTextPage {
  final int pageNumber;
  final String text;

  ExtractedTextPage({
    required this.pageNumber,
    required this.text,
  });
}

class ExtractedTextModel {
  final String id;
  final String fileName;
  final String extractedText; // Combined text for display
  final List<ExtractedTextPage>? pages; // Page-wise text for PDFs
  final DateTime createdAt;
  final String fileType; // 'document' or 'image'
  final String? filePath;

  ExtractedTextModel({
    required this.id,
    required this.fileName,
    required this.extractedText,
    this.pages,
    required this.createdAt,
    required this.fileType,
    this.filePath,
  });

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      final hour = createdAt.hour;
      final minute = createdAt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'pm' : 'am';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} $displayHour:$minute $period';
    }
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}

