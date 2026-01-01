class DocumentDetail {
  final int? id;
  final int documentId;
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

  DocumentDetail({
    this.id,
    required this.documentId,
    required this.title,
    required this.type,
    this.isFavourite = false,
    required this.imagePath,
    this.thumbnailPath,
    required this.createdAt,
    required this.updatedAt,
    this.tagId,
    this.isDeleted = false,
    this.deletedAt,
  });

  // Convert DocumentDetail object to Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'title': title,
      'type': type,
      'favourite': isFavourite ? 1 : 0,
      'Image_path': imagePath,
      'image_thumbnail': thumbnailPath,
      'created_date': createdAt.toIso8601String(),
      'updated_date': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  // Create DocumentDetail object from Map (database query result)
  factory DocumentDetail.fromMap(Map<String, dynamic> map) {
    return DocumentDetail(
      id: map['id'] as int?,
      documentId: map['document_id'] as int,
      title: map['title'] as String,
      type: map['type'] as String,
      isFavourite: (map['favourite'] as int? ?? 0) == 1,
      imagePath: map['Image_path'] as String? ?? '',
      thumbnailPath: map['image_thumbnail'] as String?,
      createdAt: map['created_date'] != null
          ? DateTime.parse(map['created_date'] as String)
          : DateTime.now(),
      updatedAt: map['updated_date'] != null
          ? DateTime.parse(map['updated_date'] as String)
          : DateTime.now(),
      tagId: null, // tag_id column doesn't exist in DocumentDetail table
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      deletedAt: null, // deleted_at column doesn't exist in DocumentDetail table
    );
  }

  // Create a copy of DocumentDetail with updated fields
  DocumentDetail copyWith({
    int? id,
    int? documentId,
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
    return DocumentDetail(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
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

  // Convert DocumentDetail to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'document_id': documentId,
      'title': title,
      'type': type,
      'isFavourite': isFavourite,
      'imagePath': imagePath,
      'thumbnailPath': thumbnailPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'tag_id': tagId,
      'isDeleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  // Create DocumentDetail from JSON
  factory DocumentDetail.fromJson(Map<String, dynamic> json) {
    return DocumentDetail(
      id: json['id'] as int?,
      documentId: json['document_id'] as int,
      title: json['title'] as String,
      type: json['type'] as String,
      isFavourite: json['isFavourite'] as bool? ?? false,
      imagePath: json['imagePath'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      tagId: json['tag_id'] as int?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'DocumentDetail{id: $id, documentId: $documentId, title: $title, type: $type, isFavourite: $isFavourite, imagePath: $imagePath, thumbnailPath: $thumbnailPath, createdAt: $createdAt, updatedAt: $updatedAt, tagId: $tagId, isDeleted: $isDeleted, deletedAt: $deletedAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DocumentDetail &&
        other.id == id &&
        other.documentId == documentId &&
        other.title == title &&
        other.type == type &&
        other.isFavourite == isFavourite &&
        other.imagePath == imagePath &&
        other.thumbnailPath == thumbnailPath &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.tagId == tagId &&
        other.isDeleted == isDeleted &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    documentId.hashCode ^
    title.hashCode ^
    type.hashCode ^
    isFavourite.hashCode ^
    imagePath.hashCode ^
    thumbnailPath.hashCode ^
    createdAt.hashCode ^
    updatedAt.hashCode ^
    tagId.hashCode ^
    isDeleted.hashCode ^
    deletedAt.hashCode;
  }
}