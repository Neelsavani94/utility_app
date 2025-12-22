class Tag {
  final int? id;
  final String title;
  final DateTime createdDate;
  final DateTime updatedDate;
  final bool isDefault; // Indicates if this is a default tag

  Tag({
    this.id,
    required this.title,
    DateTime? createdDate,
    DateTime? updatedDate,
    this.isDefault = false,
  })  : createdDate = createdDate ?? DateTime.now(),
        updatedDate = updatedDate ?? DateTime.now();

  // Convert Tag to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_date': createdDate.toIso8601String(),
      'updated_date': updatedDate.toIso8601String(),
      'default_tag': isDefault ? 1 : 0,
    };
  }

  // Create Tag from Map
  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as int?,
      title: map['title'] as String,
      createdDate: map['created_date'] != null
          ? DateTime.parse(map['created_date'] as String)
          : DateTime.now(),
      updatedDate: map['updated_date'] != null
          ? DateTime.parse(map['updated_date'] as String)
          : DateTime.now(),
      isDefault: (map['default_tag'] as int? ?? 0) == 1,
    );
  }

  // Create a copy with updated fields
  Tag copyWith({
    int? id,
    String? title,
    DateTime? createdDate,
    DateTime? updatedDate,
    bool? isDefault,
  }) {
    return Tag(
      id: id ?? this.id,
      title: title ?? this.title,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  String toString() {
    return 'Tag{id: $id, title: $title, createdDate: $createdDate, updatedDate: $updatedDate, isDefault: $isDefault}';
  }
}

