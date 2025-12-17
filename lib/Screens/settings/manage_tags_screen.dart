import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../Constants/app_constants.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/database_helper.dart';
import '../../Models/tag_model.dart';

class ManageTagsScreen extends StatefulWidget {
  const ManageTagsScreen({super.key});

  @override
  State<ManageTagsScreen> createState() => _ManageTagsScreenState();
}

class _ManageTagsScreenState extends State<ManageTagsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Tag> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final tags = await _db.getAllTags();
      if (mounted) {
        setState(() {
          _tags = tags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showToast('Error loading tags: $e', isError: true);
      }
    }
  }

  Color _getTagColor(int index) {
    final colors = [
      const Color(0xFF6C5CE7), // Primary - All Docs
      const Color(0xFFFF5722), // Orange - Business Card
      const Color(0xFF03A9F4), // Blue - ID Card
      const Color(0xFF9C27B0), // Purple - Academic
      const Color(0xFF00E676), // Green - Personal
    ];
    return colors[index % colors.length];
  }

  IconData _getTagIcon(String title) {
    final index = AppConstants.documentCategories.indexOf(title);
    if (index >= 0 && index < AppConstants.categoryIcons.length) {
      return AppConstants.categoryIcons[index];
    }
    return Icons.label_rounded;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  void _showToast(String message, {bool isError = false, bool isWarning = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: isError
          ? Colors.red
          : isWarning
              ? Colors.orange
              : Colors.green,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  Future<void> _showAddTagDialog() async {
    final nameController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? colorScheme.surface.withOpacity(0.95)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add New Tag',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Tag name',
            hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
          style: TextStyle(color: colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final tagName = nameController.text.trim();
              if (tagName.isEmpty) {
                _showToast('Please enter a tag name', isWarning: true);
                return;
              }

              try {
                // Check for duplicate tag names in database
                final tagExists = await _db.tagExists(tagName);
                if (tagExists) {
                  if (mounted) {
                    _showToast('Tag "$tagName" already exists', isWarning: true);
                  }
                  return;
                }

                final tag = Tag(title: tagName);
                await _db.insertTag(tag);
                
                if (mounted) {
                  Navigator.pop(context);
                  // Reload tags from database
                  await _loadTags();
                  
                  _showToast('Tag "$tagName" added successfully');
                }
              } catch (e) {
                if (mounted) {
                  final errorMsg = e.toString().replaceAll('Exception: ', '');
                  _showToast(errorMsg.isNotEmpty ? errorMsg : 'Error adding tag', isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tag = _tags[index];
    final tagName = tag.title;

    // Prevent deleting default tags
    if (tag.isDefault) {
      _showToast('Default tags cannot be deleted', isWarning: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? colorScheme.surface.withOpacity(0.95)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Tag',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$tagName"?',
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tag.id == null) {
                Navigator.pop(context);
                if (mounted) {
                  _showToast('Invalid tag ID', isError: true);
                }
                return;
              }

              try {
                final rowsAffected = await _db.deleteTag(tag.id!);
                
                if (mounted) {
                  Navigator.pop(context);
                  
                  if (rowsAffected > 0) {
                    // Reload tags from database
                    await _loadTags();
                    
                    _showToast('Tag "$tagName" deleted successfully');
                  } else {
                    _showToast('Failed to delete tag', isError: true);
                  }
                }
              } catch (e) {
                Navigator.pop(context);
                if (mounted) {
                  final errorMsg = e.toString().replaceAll('Exception: ', '');
                  _showToast(errorMsg.isNotEmpty ? errorMsg : 'Error deleting tag', isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.2)
                : colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () => NavigationService.goBack(),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          'Manage Tags',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppConstants.spacingM),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showAddTagDialog,
                borderRadius: BorderRadius.circular(8),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          : _tags.isEmpty
              ? _buildEmptyState(context, colorScheme, isDark)
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingM,
                    vertical: AppConstants.spacingL,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Info
                      Text(
                        '${_tags.length} ${_tags.length == 1 ? 'Tag' : 'Tags'}',
                        style: TextStyle(
                          color: colorScheme.onBackground.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingM),
                      // Tags List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _tags.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppConstants.spacingS),
                        itemBuilder: (context, index) {
                          return _buildTagCard(
                            context,
                            _tags[index],
                            index,
                            colorScheme,
                            isDark,
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.label_outline_rounded,
              size: 60,
              color: colorScheme.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: AppConstants.spacingXL),
          Text(
            'No Tags Yet',
            style: TextStyle(
              color: colorScheme.onBackground,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Create your first tag to organize\nyour documents',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onBackground.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppConstants.spacingXL),
          ElevatedButton.icon(
            onPressed: _showAddTagDialog,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Tag'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingL,
                vertical: AppConstants.spacingM,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagCard(
    BuildContext context,
    Tag tag,
    int index,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final tagColor = _getTagColor(index);
    final tagIcon = _getTagIcon(tag.title);
    final tagName = tag.title;
    final createdAt = tag.createdAt;
    final isDefault = tag.isDefault;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface.withOpacity(0.6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDefault
                ? colorScheme.primary.withOpacity(0.3)
                : (isDark
                    ? colorScheme.outline.withOpacity(0.3)
                    : colorScheme.outline.withOpacity(0.08)),
            width: isDefault ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Handle tag tap - could navigate to filtered documents
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Row(
                children: [
                  // Tag Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [tagColor, tagColor.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: tagColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(tagIcon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  // Tag Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tagName,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 10,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Default',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: colorScheme.onSurface.withOpacity(0.4),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateTime(createdAt),
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Actions
                  if (!isDefault)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: colorScheme.onSurface.withOpacity(0.5),
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.red.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteConfirmation(index);
                        } else if (value == 'edit') {
                          _showEditTagDialog(index);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditTagDialog(int index) {
    final tag = _tags[index];
    
    // Prevent editing default tags
    if (tag.isDefault) {
      _showToast('Default tags cannot be edited', isWarning: true);
      return;
    }

    final nameController = TextEditingController(text: tag.title);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? colorScheme.surface.withOpacity(0.95)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Tag',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Tag name',
            hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
          style: TextStyle(color: colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTagName = nameController.text.trim();
              if (newTagName.isEmpty) {
                _showToast('Please enter a tag name', isWarning: true);
                return;
              }

              // Check if name changed
              if (newTagName == tag.title) {
                Navigator.pop(context);
                return;
              }

              try {
                // Check for duplicate tag names in database (excluding current tag)
                final existingTag = await _db.getTagByName(newTagName);
                if (existingTag != null && existingTag.id != tag.id) {
                  if (mounted) {
                    _showToast('Tag "$newTagName" already exists', isWarning: true);
                  }
                  return;
                }

                final updatedTag = tag.copyWith(
                  title: newTagName,
                  updatedAt: DateTime.now(),
                );
                final rowsAffected = await _db.updateTag(updatedTag);
                
                if (mounted) {
                  Navigator.pop(context);
                  
                  if (rowsAffected > 0) {
                    // Reload tags from database
                    await _loadTags();
                    
                    _showToast('Tag updated to "$newTagName"');
                  } else {
                    _showToast('Failed to update tag', isError: true);
                  }
                }
              } catch (e) {
                if (mounted) {
                  final errorMsg = e.toString().replaceAll('Exception: ', '');
                  _showToast(errorMsg.isNotEmpty ? errorMsg : 'Error updating tag', isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
