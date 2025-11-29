class Tag {
  final int? id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDefault; // Indicates if this is a default tag

  Tag({
    this.id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDefault = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert Tag to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_default': isDefault ? 1 : 0,
    };
  }

  // Create Tag from Map
  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as int?,
      title: map['title'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }

  // Create a copy with updated fields
  Tag copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
  }) {
    return Tag(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  String toString() {
    return 'Tag{id: $id, title: $title, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}

