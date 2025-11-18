class DocumentModel {
  final String id;
  final String name;
  final DateTime createdAt;
  final String location;
  final String category;
  final bool isFavorite;
  final String? thumbnailPath;

  DocumentModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.location,
    required this.category,
    this.isFavorite = false,
    this.thumbnailPath,
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

