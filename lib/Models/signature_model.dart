class SignatureModel {
  final String id;
  final String name;
  final String? imagePath;
  final String? textContent;
  final String? textStyle;
  final DateTime createdAt;
  final bool isTextSignature;

  SignatureModel({
    required this.id,
    required this.name,
    this.imagePath,
    this.textContent,
    this.textStyle,
    required this.createdAt,
    required this.isTextSignature,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'textContent': textContent,
      'textStyle': textStyle,
      'createdAt': createdAt.toIso8601String(),
      'isTextSignature': isTextSignature ? 1 : 0,
    };
  }

  factory SignatureModel.fromMap(Map<String, dynamic> map) {
    return SignatureModel(
      id: map['id'] as String,
      name: map['name'] as String,
      imagePath: map['imagePath'] as String?,
      textContent: map['textContent'] as String?,
      textStyle: map['textStyle'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isTextSignature: (map['isTextSignature'] as int) == 1,
    );
  }
}



