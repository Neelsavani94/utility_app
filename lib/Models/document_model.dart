// Database Document model
class Document {
  final int? id;
  final String title;
  final String type;
  final bool isFavourite;
  final String imagePath;
  final String? thumbnailPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? tagId;
  final bool isDeleted;
  final DateTime? deletedAt;

  Document({
    this.id,
    required this.title,
    required this.type,
    this.isFavourite = false,
    required this.imagePath,
    this.thumbnailPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.tagId,
    this.isDeleted = false,
    this.deletedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert Document to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'isFavourite': isFavourite ? 1 : 0, // SQLite uses 0/1 for boolean
      'imagePath': imagePath,
      'thumbnailPath': thumbnailPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'tag_id': tagId,
      'isDeleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  // Create Document from Map
  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'] as int?,
      title: map['title'] as String,
      type: map['type'] as String,
      isFavourite: (map['isFavourite'] as int? ?? 0) == 1,
      imagePath: map['imagePath'] as String,
      thumbnailPath: map['thumbnailPath'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
      tagId: map['tag_id'] as int?,
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }

  // Create a copy with updated fields
  Document copyWith({
    int? id,
    String? title,
    String? type,
    bool? isFavourite,
    String? imagePath,
    String? thumbnailPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? tagId,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      isFavourite: isFavourite ?? this.isFavourite,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tagId: tagId ?? this.tagId,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  String toString() {
    return 'Document{id: $id, title: $title, type: $type, isFavourite: $isFavourite, tagId: $tagId}';
  }
}

// UI DocumentModel for compatibility with existing UI code
class DocumentModel {
  final String id;
  final String name;
  final DateTime createdAt;
  final String location;
  final String category;
  final bool isFavorite;
  final String? thumbnailPath;
  final String? imagePath;
  final bool isDeleted;
  final DateTime? deletedAt;

  DocumentModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.location,
    required this.category,
    this.isFavorite = false,
    this.thumbnailPath,
    this.imagePath,
    this.isDeleted = false,
    this.deletedAt,
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

  // Convert from database Document to UI DocumentModel
  factory DocumentModel.fromDocument(Document doc, {String? category, String? location}) {
    return DocumentModel(
      id: doc.id?.toString() ?? '',
      name: doc.title,
      createdAt: doc.createdAt,
      location: location ?? 'In this device',
      category: category ?? doc.type,
      isFavorite: doc.isFavourite,
      thumbnailPath: doc.thumbnailPath,
      imagePath: doc.imagePath,
      isDeleted: doc.isDeleted,
      deletedAt: doc.deletedAt,
    );
  }

  // Convert to database Document
  Document toDocument({int? tagId}) {
    return Document(
      id: int.tryParse(id),
      title: name,
      type: category,
      isFavourite: isFavorite,
      imagePath: imagePath ?? thumbnailPath ?? '',
      thumbnailPath: thumbnailPath,
      createdAt: createdAt,
      tagId: tagId,
    );
  }
}
