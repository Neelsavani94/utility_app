import '../Models/tag_model.dart';
import 'database_helper.dart';

class TagService {
  static final TagService instance = TagService._init();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  TagService._init();

  /// Create a new tag
  Future<Tag> createTag({
    required String title,
    bool isDefault = false,
  }) async {
    final tag = Tag(
      title: title,
      isDefault: isDefault,
    );

    final id = await _dbHelper.createTag(tag.toMap());
    return tag.copyWith(id: id);
  }

  /// Get all tags
  Future<List<Tag>> getAllTags() async {
    final tagsMap = await _dbHelper.getAllTags();
    return tagsMap.map((map) => Tag.fromMap(map)).toList();
  }

  /// Get tag by ID
  Future<Tag?> getTagById(int id) async {
    final tagMap = await _dbHelper.getTag(id);
    if (tagMap == null) return null;
    return Tag.fromMap(tagMap);
  }

  /// Find tag by title
  Future<Tag?> findTagByTitle(String title) async {
    final tagMap = await _dbHelper.findTagByTitle(title);
    if (tagMap == null) return null;
    return Tag.fromMap(tagMap);
  }

  /// Get all default tags
  Future<List<Tag>> getDefaultTags() async {
    final tagsMap = await _dbHelper.getDefaultTags();
    return tagsMap.map((map) => Tag.fromMap(map)).toList();
  }

  /// Get all non-default tags
  Future<List<Tag>> getNonDefaultTags() async {
    final tagsMap = await _dbHelper.getNonDefaultTags();
    return tagsMap.map((map) => Tag.fromMap(map)).toList();
  }

  /// Update tag
  Future<bool> updateTag(Tag tag) async {
    if (tag.id == null) return false;

    final updatedTag = tag.copyWith(
      updatedDate: DateTime.now(),
    );

    final result = await _dbHelper.updateTag(tag.id!, updatedTag.toMap());
    return result > 0;
  }

  /// Set tag as default
  Future<bool> setTagAsDefault(int id) async {
    final result = await _dbHelper.setTagAsDefault(id);
    return result > 0;
  }

  /// Unset tag as default
  Future<bool> unsetTagAsDefault(int id) async {
    final result = await _dbHelper.unsetTagAsDefault(id);
    return result > 0;
  }

  /// Delete tag
  Future<bool> deleteTag(int id) async {
    final result = await _dbHelper.deleteTag(id);
    return result > 0;
  }

  /// Create or get tag (useful for ensuring a tag exists)
  Future<Tag> createOrGetTag({
    required String title,
    bool isDefault = false,
  }) async {
    // First try to find existing tag
    final existingTag = await findTagByTitle(title);
    if (existingTag != null) {
      return existingTag;
    }

    // Create new tag if not found
    return await createTag(title: title, isDefault: isDefault);
  }

  /// Toggle default status of a tag
  Future<bool> toggleDefaultStatus(int id) async {
    final tag = await getTagById(id);
    if (tag == null) return false;

    if (tag.isDefault) {
      return await unsetTagAsDefault(id);
    } else {
      return await setTagAsDefault(id);
    }
  }
}

