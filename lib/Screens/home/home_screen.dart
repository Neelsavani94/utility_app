import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/services.dart';
import '../../Constants/app_constants.dart';
import '../../Providers/home_provider.dart';
import '../../Components/empty_state.dart';
import '../../Components/bottom_navigation_bar_custom.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/database_helper.dart';
import '../../Models/tag_model.dart';
import '../../Models/document_model.dart';
import '../settings/settings_screen.dart';
import '../scanner/scanner_mode_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Tag> _tags = [];
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().loadDocuments();
      _loadTags();
    });
  }

  Future<void> _loadTags() async {
    try {
      final tags = await _db.getAllTags();
      if (mounted) {
        setState(() {
          _tags = tags;
          _isLoadingTags = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<HomeProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: colorScheme.background,
          appBar: _buildAppBar(
            context,
            colorScheme,
            isDark,
            provider,
            provider.selectedBottomNavIndex == 4
                ? Text(
                    'Setting',
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  )
                : RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Scanify',
                          style: TextStyle(
                            color: colorScheme.secondary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'AI',
                          style: TextStyle(
                            color: colorScheme.onBackground,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          body: Builder(
            builder: (context) {
              // Show SettingsScreen when settings icon (index 4) is selected
              if (provider.selectedBottomNavIndex == 4) {
                return const SettingsScreen();
              }

              // Default home content
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Content Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spacingM,
                        AppConstants.spacingM,
                        AppConstants.spacingM,
                        100,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quick Tools Grid
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildToolsGrid(context, provider),
                          ),
                          const SizedBox(height: AppConstants.spacingXS),
                          _buildSearchBar(
                            context,
                            colorScheme,
                            isDark,
                            provider,
                          ),
                          // Category Filter Row
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildCategoryFilter(
                              context,
                              provider,
                              colorScheme,
                              isDark,
                            ),
                          ),

                          const SizedBox(height: AppConstants.spacingM),

                          // Documents Grid or Empty State
                          provider.isLoading
                              ? SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.3,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                )
                              : provider.filteredDocuments.isEmpty
                              ? SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.3,
                                  child: const EmptyState(
                                    title: 'Start Scanning!',
                                    subtitle: 'We don\'t see any files',
                                    icon: Icons.document_scanner_rounded,
                                  ),
                                )
                              : _buildDocumentsGrid(context, provider),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: _buildFloatingActionButton(
            context,
            colorScheme,
            isDark,
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomNavigationBarCustom(
            selectedIndex: provider.selectedBottomNavIndex,
            onItemSelected: (index) {
              // Handle QR Scan navigation (index 1)
              if (index == 1) {
                NavigationService.toQRReader();
              } else if (index == 3) {
                // Handle OCR Scan (index 3) - navigate to ExtractTextScreen and auto-trigger image picker
                NavigationService.toExtractText(autoPickImage: true);
              } else {
                // For other items, update the selected index
                provider.setSelectedBottomNavIndex(index);
              }
            },
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    HomeProvider provider,
    Widget title,
  ) {
    return AppBar(
      backgroundColor: isDark
          ? colorScheme.surface.withOpacity(0.3)
          : colorScheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colorScheme.surface.withOpacity(0.3),
                    colorScheme.surface.withOpacity(0.2),
                  ]
                : [colorScheme.surface, colorScheme.surface.withOpacity(0.95)],
          ),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: AppConstants.spacingM),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, colorScheme.secondary],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.description_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            title,
          ],
        ),
      ),
      leadingWidth: 220,
      actions: [
        _buildHeaderAction(
          context,
          Icons.bookmark_border_rounded,
          () {
            NavigationService.toFavorites();
          },
          colorScheme,
          isDark,
        ),
        _buildHeaderAction(
          context,
          Icons.refresh_rounded,
          () async {
            await context.read<HomeProvider>().loadDocuments();
          },
          colorScheme,
          isDark,
        ),
      ],
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    HomeProvider provider,
  ) {
    return Container(
      color: colorScheme.background,
      padding: const EdgeInsets.fromLTRB(
        0,
        AppConstants.spacingM,
        0,
        AppConstants.spacingM,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  provider.setSearchQuery(value);
                },
                decoration: InputDecoration(
                  hintText: 'Search documents...',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colorScheme.onSurface.withOpacity(0.5),
                    size: AppConstants.iconS,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingM,
                    vertical: AppConstants.spacingM,
                  ),
                ),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingS),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.tune_rounded,
                color: colorScheme.onSurface.withOpacity(0.7),
                size: AppConstants.iconM,
              ),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'create_folder',
                  child: _buildMenuItem(
                    context,
                    Icons.folder_rounded,
                    'Create Folder',
                    colorScheme,
                    false,
                  ),
                ),
                PopupMenuItem(
                  value: 'create_tag',
                  child: _buildMenuItem(
                    context,
                    Icons.label_rounded,
                    'Create Tag',
                    colorScheme,
                    false,
                  ),
                ),
                PopupMenuItem(
                  value: 'sort_by',
                  child: _buildMenuItem(
                    context,
                    Icons.sort_rounded,
                    'Sort By',
                    colorScheme,
                    false,
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'create_folder':
                    _showCreateFolderDialog(context, colorScheme, isDark);
                    break;
                  case 'create_tag':
                    _showCreateTagDialog(context, colorScheme, isDark);
                    break;
                  case 'sort_by':
                    _showSortByDialog(context, colorScheme, isDark, provider);
                    break;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colorScheme.surface.withOpacity(0.2),
                  colorScheme.surface.withOpacity(0.15),
                ]
              : [
                  colorScheme.surface.withOpacity(0.9),
                  colorScheme.surface.withOpacity(0.7),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1,
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
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolsGrid(BuildContext context, HomeProvider provider) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: AppConstants.spacingS,
        mainAxisSpacing: AppConstants.spacingS,
        childAspectRatio: 0.9,
      ),
      itemCount: AppConstants.toolLabels.length,
      itemBuilder: (context, index) {
        return _buildToolGridItem(
          context,
          AppConstants.toolLabels[index],
          AppConstants.toolIcons[index],
          AppConstants.toolColors[index],
          () {
            if (index == AppConstants.toolLabels.length - 1) {
              // Navigate to Tools Screen
              NavigationService.toTools();
            } else if (index == 0) {
              // Merge PDF tool
              _openPhotoEditor(context, Theme.of(context).colorScheme);
            } else if (index == 1) {
              // Split PDF tool
              NavigationService.toSplitPDF();
            } else if (index == 2) {
              // eSign tool
              NavigationService.toESignList();
            } else {
              // Other specific tools
            }
          },
        );
      },
    );
  }

  Future<void> _openPhotoEditor(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'webp'],
      );

      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No images selected'),
            backgroundColor: colorScheme.surfaceVariant,
          ),
        );
        return;
      }

      final files = result.files
          .where((file) => file.path != null)
          .map((file) => File(file.path!))
          .toList();

      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Selected files could not be read'),
            backgroundColor: colorScheme.surfaceVariant,
          ),
        );
        return;
      }

      if (files.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select at least 2 images to merge PDF'),
            backgroundColor: colorScheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      NavigationService.toPhotoEditor(imageFiles: files);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open gallery: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  Widget _buildToolGridItem(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withOpacity(0.8)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(
    BuildContext context,
    HomeProvider provider,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    // Combine "All Docs" with tags from database
    final List<Map<String, dynamic>> categories = [
      ..._tags.map(
        (tag) => {'title': tag.title, 'id': tag.id, 'isDefault': tag.isDefault},
      ),
    ];

    if (_isLoadingTags) {
      return SizedBox(
        height: 35,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 35,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppConstants.spacingS),
            itemBuilder: (context, index) {
              final category = categories[index];
              final categoryTitle = category['title'] as String;
              final isSelected = provider.selectedCategory == categoryTitle;

              return GestureDetector(
                onTap: () {
                  provider.setSelectedCategory(categoryTitle);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingM,
                    vertical: AppConstants.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline.withOpacity(0.08),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        categoryTitle,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : colorScheme.onSurface.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      if (category['isDefault'] == true &&
                          categoryTitle != 'All Docs')
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 10,
                            color: isSelected
                                ? Colors.white.withOpacity(0.8)
                                : colorScheme.primary.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsGrid(BuildContext context, HomeProvider provider) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: provider.filteredDocuments.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppConstants.spacingS),
      itemBuilder: (context, index) {
        final document = provider.filteredDocuments[index];
        return _buildDocumentCard(context, document, provider);
      },
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    dynamic document,
    HomeProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _handleDocumentTap(context, document),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface.withOpacity(0.6) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? colorScheme.outline.withOpacity(0.12)
                : colorScheme.outline.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.15)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail or Icon with subtle gradient
            _buildDocumentThumbnail(document, colorScheme, 52),
            const SizedBox(width: 14),
            // Content - Compact Vertical
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    document.name,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      document.category,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Time and Category in one line
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: colorScheme.onSurface.withOpacity(0.45),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        document.formattedDate,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Actions - Compact
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Favorite
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await provider.toggleFavorite(document.id);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: document.isFavorite
                            ? Colors.amber.withOpacity(0.12)
                            : colorScheme.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        document.isFavorite
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        size: 18,
                        color: document.isFavorite
                            ? Colors.amber.shade700
                            : colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                // Share
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleShareDocument(context, document),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.share_rounded,
                        size: 18,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                // More
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _showDocumentOptionsBottomSheet(
                        context,
                        document,
                        colorScheme,
                        isDark,
                        provider,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentThumbnail(dynamic document, ColorScheme colorScheme, double size) {
    final thumbnailPath = document.thumbnailPath;
    
    // If thumbnail exists and is not empty, show thumbnail
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      final thumbnailFile = File(thumbnailPath);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            thumbnailFile,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to icon if thumbnail fails to load
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: Colors.white,
                  size: size * 0.5,
                ),
              );
            },
          ),
        ),
      );
    }
    
    // Default icon with gradient
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.description_rounded,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }

  void _handleDocumentTap(BuildContext context, dynamic document) {
    final filePath = document.imagePath ?? document.thumbnailPath;
    if (filePath == null || filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('File path not available'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final category = document.category?.toLowerCase() ?? '';
    final isPDF = category == 'pdf' || 
                  filePath.toLowerCase().endsWith('.pdf') ||
                  document.name.toLowerCase().endsWith('.pdf');

    if (isPDF) {
      // Navigate to PDF viewer
      NavigationService.toScanPDFViewer(pdfPath: filePath);
    } else {
      // Navigate to image viewer
      NavigationService.toImageViewer(
        imagePath: filePath,
        imageName: document.name,
      );
    }
  }

  Future<void> _handleShareDocument(BuildContext context, dynamic document) async {
    // Check if it's a folder
    final category = document.category?.toLowerCase() ?? '';
    if (category == 'folder') {
      Fluttertoast.showToast(
        msg: 'Cannot share folder',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final filePath = document.imagePath ?? document.thumbnailPath;
    if (filePath == null || filePath.isEmpty) {
      Fluttertoast.showToast(
        msg: 'File path not available',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      Fluttertoast.showToast(
        msg: 'File not found',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final isPDF = category == 'pdf' || 
                    filePath.toLowerCase().endsWith('.pdf') ||
                    document.name.toLowerCase().endsWith('.pdf');

      await Share.shareXFiles(
        [XFile(filePath)],
        text: isPDF ? 'PDF Document' : 'Image',
      );
    } catch (e) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error sharing file: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Widget _buildFloatingActionButton(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.secondary],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showScannerModeBottomSheet(context);
          },
          borderRadius: BorderRadius.circular(32),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    ColorScheme colorScheme,
    bool isPremium,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurface.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (isPremium) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 2),
                Text(
                  'Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showCreateFolderDialog(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? colorScheme.surface.withOpacity(0.95)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Create Folder',
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
            hintText: 'Folder name',
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
              final folderName = nameController.text.trim();
              if (folderName.isEmpty) {
                Fluttertoast.showToast(
                  msg: 'Please enter a folder name',
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
                return;
              }

              try {
                // Check for duplicate folder names in Documents table
                final allDocuments = await _db.getAllDocuments();
                final existingFolder = allDocuments.firstWhere(
                  (doc) =>
                      doc.type.toLowerCase() == 'folder' &&
                      doc.title.toLowerCase() == folderName.toLowerCase(),
                  orElse: () => Document(title: '', type: '', imagePath: ''),
                );

                if (existingFolder.title.isNotEmpty) {
                  Fluttertoast.showToast(
                    msg: 'Folder "$folderName" already exists',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                  );
                  return;
                }

                // Create folder as a document with type "Folder"
                // Use a placeholder image path for folders
                final folderDocument = Document(
                  title: folderName,
                  type: 'Folder',
                  tagId: 1,
                  imagePath: '',
                  isFavourite: false,
                );

                await _db.insertDocument(folderDocument);
                context.read<HomeProvider>().loadDocuments();

                if (mounted) {
                  Navigator.pop(context);

                  Fluttertoast.showToast(
                    msg: 'Folder "$folderName" created successfully',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.green,
                    textColor: Colors.white,
                  );
                }
              } catch (e) {
                if (mounted) {
                  Fluttertoast.showToast(
                    msg: 'Error creating folder: $e',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                  );
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<int?> _showCreateTagDialog(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) async {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? colorScheme.surface.withOpacity(0.95)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Create Tag',
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
                Fluttertoast.showToast(
                  msg: 'Please enter a tag name',
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
                return;
              }

              // Check for duplicate tag names
              final existingTag = _tags.firstWhere(
                (tag) => tag.title.toLowerCase() == tagName.toLowerCase(),
                orElse: () => Tag(title: ''),
              );

              if (existingTag.title.isNotEmpty) {
                Fluttertoast.showToast(
                  msg: 'Tag "$tagName" already exists',
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
                return;
              }

              try {
                final tag = Tag(title: tagName);
                final tagId = await _db.insertTag(tag);

                if (mounted) {
                  Navigator.pop(context, tagId);
                  // Reload tags to show the new tag
                  await _loadTags();

                  Fluttertoast.showToast(
                    msg: 'Tag "$tagName" created successfully',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.green,
                    textColor: Colors.white,
                  );
                }
              } catch (e) {
                if (mounted) {
                  Fluttertoast.showToast(
                    msg: 'Error creating tag: $e',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                  );
                }
                return null;
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    return null;
  }

  void _showSortByDialog(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    HomeProvider provider,
  ) {
    final sortOptions = [
      {'label': 'Name (A-Z)', 'value': 'name_asc', 'icon': Icons.sort_by_alpha_rounded},
      {'label': 'Name (Z-A)', 'value': 'name_desc', 'icon': Icons.sort_by_alpha_rounded},
      {'label': 'Date (Newest)', 'value': 'date_desc', 'icon': Icons.access_time_rounded},
      {'label': 'Date (Oldest)', 'value': 'date_asc', 'icon': Icons.access_time_rounded},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? colorScheme.surface.withOpacity(0.95)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sort By',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: sortOptions.map((option) {
            final isSelected = provider.sortBy == option['value'];
            return ListTile(
              leading: Icon(
                option['icon'] as IconData,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                size: 20,
              ),
              title: Text(
                option['label'] as String,
                style: TextStyle(
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    )
                  : null,
              onTap: () {
                provider.setSortBy(option['value'] as String);
                Navigator.pop(context);
                Fluttertoast.showToast(
                  msg: 'Sorted by ${option['label']}',
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: colorScheme.primary,
                  textColor: Colors.white,
                );
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDocumentOptionsBottomSheet(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
    bool isDark,
    HomeProvider provider,
  ) {
    final options = [
      {
        'icon': Icons.drive_file_move_rounded,
        'title': 'Move',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.save_rounded,
        'title': 'Save',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.email_rounded,
        'title': 'Send Mail',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.document_scanner_rounded,
        'title': 'OCR',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.lock_rounded,
        'title': 'Lock',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.copy_rounded,
        'title': 'Copy',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.drive_file_rename_outline_rounded,
        'title': 'Rename',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.label_rounded,
        'title': 'Tags',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.delete_outline_rounded,
        'title': 'Move to Trash',
        'color': Colors.red,
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    colorScheme.surface.withOpacity(0.98),
                    colorScheme.surface.withOpacity(0.95),
                  ]
                : [Colors.white, Colors.white.withOpacity(0.98)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Document Info Header with Premium Design
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingM,
                ),
                padding: const EdgeInsets.all(AppConstants.spacingM),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withOpacity(0.1),
                      colorScheme.secondary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Document Icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.description_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    // Document Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document.name,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                                document.formattedDate,
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
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surface.withOpacity(0.3)
                            : colorScheme.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Icon(
                            Icons.close_rounded,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingM),
              // Options Grid with Premium Design
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingM,
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: AppConstants.spacingS,
                    mainAxisSpacing: AppConstants.spacingS,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 200 + (index * 30)),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.scale(
                            scale: 0.9 + (value * 0.1),
                            child: child,
                          ),
                        );
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _handleDocumentOption(
                              context,
                              option['title'] as String,
                              document,
                              colorScheme,
                              provider,
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? [colorScheme.surface, colorScheme.surface]
                                    : [
                                        Colors.white,
                                        colorScheme.surface.withOpacity(0.5),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (option['color'] as Color).withOpacity(
                                  0.15,
                                ),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        (option['color'] as Color),
                                        (option['color'] as Color).withOpacity(
                                          0.7,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    option['icon'] as IconData,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    option['title'] as String,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.1,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                height:
                    MediaQuery.of(context).viewInsets.bottom +
                    AppConstants.spacingM,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDocumentOption(
    BuildContext context,
    String option,
    dynamic document,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) {
    switch (option) {
      case 'Move':
        _handleMoveDocument(context, document, colorScheme, provider);
        break;
      case 'Save':
        _handleSaveDocument(context, document, colorScheme);
        break;
      case 'Send Mail':
        _handleSendMailDocument(context, document, colorScheme);
        break;
      case 'OCR':
        _handleOCRDocument(context, document);
        break;
      case 'Lock':
        _handleLockDocument(context, document, colorScheme);
        break;
      case 'Copy':
        _handleCopyDocument(context, document, colorScheme, provider);
        break;
      case 'Rename':
        _handleRenameDocument(context, document, colorScheme);
        break;
      case 'Tags':
        _handleChangeTagsDocument(context, document, colorScheme, provider);
        break;
      case 'Move to Trash':
        _handleMoveToTrashDocument(context, document, colorScheme, provider);
        break;
    }
  }

  // Move Document Function
  void _handleMoveDocument(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) {
    _showMoveCopyPage(context, document, colorScheme, provider, 'Move');
  }

  // Save Document Function
  void _handleSaveDocument(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
  ) {
    _showSaveDialog(context, document, colorScheme);
  }

  // Send Mail Document Function
  Future<void> _handleSendMailDocument(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
  ) async {
    final emailController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.98)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.email_rounded,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          'Send Mail',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Icon(
                            Icons.close_rounded,
                            color: colorScheme.primary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingXL),
                // Email Input
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter E-mail Id',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? colorScheme.surface.withOpacity(0.3)
                        : colorScheme.surface.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingM,
                      vertical: AppConstants.spacingM,
                    ),
                  ),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                const SizedBox(height: AppConstants.spacingXL),
                // OK Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final email = emailController.text.trim();
                      if (email.isNotEmpty) {
                        Navigator.pop(context, email);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null && result is String) {
      final filePath = document.imagePath ?? document.thumbnailPath;
      
      if (filePath == null || filePath.isEmpty) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: 'File path not available',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: 'File not found',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      try {
        // Use Share to send file via email (supports attachments)
        final isPDF = filePath.toLowerCase().endsWith('.pdf') ||
                     document.name.toLowerCase().endsWith('.pdf') ||
                     (document.category?.toLowerCase() ?? '') == 'pdf';
        
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Please find the attached ${isPDF ? 'PDF' : 'image'}: ${document.name}',
          subject: document.name,
        );
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sharing "${document.name}" via email'),
              backgroundColor: colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: 'Error sharing file: $e',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      }
    }
  }

  // OCR Document Function - Direct OCR Processing
  Future<void> _handleOCRDocument(
    BuildContext context,
    dynamic document,
  ) async {
    final filePath = document.imagePath ?? document.thumbnailPath;
    if (filePath == null || filePath.isEmpty) {
      Fluttertoast.showToast(
        msg: 'File path not available',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      Fluttertoast.showToast(
        msg: 'File not found',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isPDF = filePath.toLowerCase().endsWith('.pdf') ||
                 document.name.toLowerCase().endsWith('.pdf') ||
                 (document.category?.toLowerCase() ?? '') == 'pdf';

    // Show processing indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Processing OCR...',
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      String extractedText = '';
      
      if (isPDF) {
        // Process PDF
        final bytes = await file.readAsBytes();
        final pdfDocument = PdfDocument(inputBytes: bytes);
        final pageCount = pdfDocument.pages.count;

        for (int i = 0; i < pageCount; i++) {
          try {
            final textExtractor = PdfTextExtractor(pdfDocument);
            final pageText = textExtractor.extractText(startPageIndex: i, endPageIndex: i);
            if (pageText.isNotEmpty) {
              extractedText += 'Page ${i + 1}:\n$pageText\n\n';
            }
          } catch (e) {
            // Page might be scanned image, skip for now
            print('Error extracting text from page ${i + 1}: $e');
          }
        }
        pdfDocument.dispose();
      } else {
        // Process Image
        final textRecognizer = TextRecognizer();
        try {
          final inputImage = InputImage.fromFilePath(filePath);
          final recognizedText = await textRecognizer.processImage(inputImage);
          extractedText = recognizedText.text;
        } finally {
          textRecognizer.close();
        }
      }

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (extractedText.isEmpty) {
          Fluttertoast.showToast(
            msg: 'No text found in document',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
          return;
        }

        // Show extracted text in a dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Extracted Text from ${document.name}'),
            content: SingleChildScrollView(
              child: SelectableText(extractedText),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: extractedText));
                  Fluttertoast.showToast(
                    msg: 'Text copied to clipboard',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.green,
                    textColor: Colors.white,
                  );
                },
                child: const Text('Copy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        Fluttertoast.showToast(
          msg: 'Error processing OCR: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  // Lock Document Function
  void _handleLockDocument(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
  ) {
    _showLockFileDialog(context, document, colorScheme);
  }

  // Copy Document Function
  void _handleCopyDocument(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) {
    _showMoveCopyPage(context, document, colorScheme, provider, 'Copy');
  }

  // Rename Document Function
  void _handleRenameDocument(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
  ) {
    _showRenameBottomSheet(context, document, colorScheme);
  }

  // Change Tags Document Function
  void _handleChangeTagsDocument(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) {
    _showChangeTagBottomSheet(context, document, colorScheme, provider);
  }

  // Move to Trash Document Function
  void _handleMoveToTrashDocument(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) {
    _showMoveToTrashBottomSheet(context, document, colorScheme, provider);
  }

  // Lock File Dialog
  void _showLockFileDialog(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pinControllers = List.generate(4, (_) => TextEditingController());
    bool enableFingerprint = false;
    int currentPinIndex = 0;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surface.withOpacity(0.98)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lock File',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Icon(
                              Icons.close_rounded,
                              color: colorScheme.primary,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                  // Choose Pin Text
                  Text(
                    'Choose Pin',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  // PIN Input Fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark
                              ? colorScheme.surface.withOpacity(0.3)
                              : colorScheme.surface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: currentPinIndex == index
                                ? colorScheme.primary
                                : colorScheme.outline.withOpacity(0.2),
                            width: currentPinIndex == index ? 2 : 1,
                          ),
                        ),
                        child: TextField(
                          controller: pinControllers[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 3) {
                              setState(() {
                                currentPinIndex = index + 1;
                              });
                              FocusScope.of(context).nextFocus();
                            } else if (value.isEmpty && index > 0) {
                              setState(() {
                                currentPinIndex = index - 1;
                              });
                              FocusScope.of(context).previousFocus();
                            }
                          },
                          onTap: () {
                            setState(() {
                              currentPinIndex = index;
                            });
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppConstants.spacingXL),
                  // Fingerprint Toggle
                  Container(
                    padding: const EdgeInsets.all(AppConstants.spacingM),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.surface.withOpacity(0.2)
                          : colorScheme.surface.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.fingerprint_rounded,
                              color: colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: AppConstants.spacingS),
                            Text(
                              'Enable Fingerprint',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: enableFingerprint,
                          onChanged: (value) {
                            setState(() {
                              enableFingerprint = value;
                            });
                          },
                          activeColor: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingXL),
                  // Create Lock Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final pin = pinControllers.map((c) => c.text).join();
                        if (pin.length == 4) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('File "${document.name}" locked'),
                              backgroundColor: colorScheme.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Create Lock',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Save Dialog
  void _showSaveDialog(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedFormat = 'PDF';
    bool isLocked = false;
    bool isCompressed = true;
    String compressLevel = 'Good';

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surface.withOpacity(0.98)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          document.name,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Icon(
                              Icons.close_rounded,
                              color: colorScheme.primary,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingXL),
                  // Format Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Format',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedFormat = 'PDF';
                              });
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedFormat == 'PDF'
                                          ? colorScheme.primary
                                          : colorScheme.outline.withOpacity(
                                              0.3,
                                            ),
                                      width: 2,
                                    ),
                                    color: selectedFormat == 'PDF'
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                  ),
                                  child: selectedFormat == 'PDF'
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PDF',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingL),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedFormat = 'Photo';
                              });
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedFormat == 'Photo'
                                          ? colorScheme.primary
                                          : colorScheme.outline.withOpacity(
                                              0.3,
                                            ),
                                      width: 2,
                                    ),
                                    color: selectedFormat == 'Photo'
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                  ),
                                  child: selectedFormat == 'Photo'
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Photo',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                  // Lock Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lock',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: isLocked,
                        onChanged: (value) {
                          setState(() {
                            isLocked = value;
                          });
                        },
                        activeColor: colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                  // Compress Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Compress',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: isCompressed,
                        onChanged: (value) {
                          setState(() {
                            isCompressed = value;
                          });
                        },
                        activeColor: colorScheme.primary,
                      ),
                    ],
                  ),
                  if (isCompressed) ...[
                    const SizedBox(height: AppConstants.spacingM),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Low',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: colorScheme.primary,
                              inactiveTrackColor: colorScheme.primary
                                  .withOpacity(0.2),
                              thumbColor: colorScheme.primary,
                              overlayColor: colorScheme.primary.withOpacity(
                                0.1,
                              ),
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                            ),
                            child: RangeSlider(
                              values: const RangeValues(0.3, 0.6),
                              onChanged: (values) {
                                if (values.start < 0.4) {
                                  setState(() {
                                    compressLevel = 'Low';
                                  });
                                } else if (values.start < 0.7) {
                                  setState(() {
                                    compressLevel = 'Good';
                                  });
                                } else {
                                  setState(() {
                                    compressLevel = 'High';
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        Text(
                          'High',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Center(
                      child: Text(
                        compressLevel,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppConstants.spacingXL),
                  // OK Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _performSaveDocument(
                          context,
                          document,
                          selectedFormat,
                          colorScheme,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Perform Save Document Function - Save to Gallery
  Future<void> _performSaveDocument(
    BuildContext context,
    dynamic document,
    String selectedFormat,
    ColorScheme colorScheme,
  ) async {
    try {
      final filePath = document.imagePath ?? document.thumbnailPath;
      if (filePath == null || filePath.isEmpty) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: 'File path not available',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: 'File not found',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      final isPDF = filePath.toLowerCase().endsWith('.pdf') ||
                   document.name.toLowerCase().endsWith('.pdf') ||
                   (document.category?.toLowerCase() ?? '') == 'pdf';

      if (isPDF) {
        // For PDF, save to downloads directory
        final directory = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory('${directory.path}/Download/Scanify AI');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        final fileName = document.name;
        final destFile = File('${downloadsDir.path}/$fileName');
        await sourceFile.copy(destFile.path);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved "${document.name}" to Downloads'),
              backgroundColor: colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // For images, save to Pictures directory (accessible from gallery)
        try {
          Directory? picturesDir;
          if (Platform.isAndroid) {
            // Android: Use external storage Pictures directory
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              picturesDir = Directory('${externalDir.path.split('/Android')[0]}/Pictures/Scanify AI');
            }
          } else if (Platform.isIOS) {
            // iOS: Use application documents directory
            final appDir = await getApplicationDocumentsDirectory();
            picturesDir = Directory('${appDir.path}/Pictures/Scanify AI');
          }

          if (picturesDir == null) {
            // Fallback to Downloads
            final directory = await getApplicationDocumentsDirectory();
            picturesDir = Directory('${directory.path}/Download/Scanify AI/Pictures');
          }

          if (!await picturesDir.exists()) {
            await picturesDir.create(recursive: true);
          }

          final fileName = document.name;
          final destFile = File('${picturesDir.path}/$fileName');
          await sourceFile.copy(destFile.path);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved "${document.name}" to Gallery'),
                backgroundColor: colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Fluttertoast.showToast(
              msg: 'Error saving to gallery: $e',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error saving file: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  // Move to Trash Bottom Sheet
  void _showMoveToTrashBottomSheet(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface.withOpacity(0.98) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingXL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXL),
                // Title
                Text(
                  'Are you Sure ?',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                // Message
                Text(
                  'You want to move to Trash ?',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingXL),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colorScheme.outline.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await provider.moveToTrash(document.id);
                          Fluttertoast.showToast(
                            msg: '"${document.name}" moved to trash',
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text(
                          'Trash',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Change Tag Bottom Sheet
  void _showChangeTagBottomSheet(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? selectedTag = document.category;
    int? selectedTagId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.98)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(
                      bottom: AppConstants.spacingM,
                    ),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.label_rounded,
                            color: colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: AppConstants.spacingS),
                          Text(
                            'Change Tag',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Icon(
                              Icons.close_rounded,
                              color: colorScheme.primary,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  // Create New Tag
                  GestureDetector(
                    onTap: () async {
                      final result = await _showCreateTagDialog(context, colorScheme, isDark);
                      if (result != null) {
                        // Reload tags after creating new tag
                        await _loadTags();
                        setState(() {
                          final newTag = _tags.firstWhere(
                            (t) => t.id == result,
                            orElse: () => Tag(title: ''),
                          );
                          if (newTag.title.isNotEmpty) {
                            selectedTag = newTag.title;
                            selectedTagId = newTag.id;
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppConstants.spacingM,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: AppConstants.spacingS),
                          Text(
                            'Create New Tag',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: AppConstants.spacingS),
                  // Tag List from Database
                  _tags.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppConstants.spacingM),
                          child: Center(
                            child: Text(
                              'No tags available',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _tags.length,
                          itemBuilder: (context, index) {
                            final tag = _tags[index];

                            return RadioListTile<String>(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tag.title,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (tag.isDefault)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.lock_rounded,
                                        size: 14,
                                        color: colorScheme.primary.withOpacity(
                                          0.6,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              value: tag.title,
                              groupValue: selectedTag,
                              onChanged: (value) {
                                setState(() {
                                  selectedTag = value;
                                  selectedTagId = tag.id;
                                });
                              },
                              activeColor: colorScheme.primary,
                            );
                          },
                        ),
                  const SizedBox(height: AppConstants.spacingM),
                  // Change Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedTag != null && selectedTagId != null) {
                          Navigator.pop(context);
                          await _updateDocumentTag(
                            context,
                            document,
                            selectedTagId!,
                            selectedTag!,
                            colorScheme,
                            provider,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Update Document Tag in Database
  Future<void> _updateDocumentTag(
    BuildContext context,
    dynamic document,
    int tagId,
    String tagTitle,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) async {
    try {
      final docId = int.tryParse(document.id.toString());
      if (docId == null) {
        Fluttertoast.showToast(
          msg: 'Invalid document ID',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Get current document from database
      final currentDoc = await _db.getDocumentById(docId);
      if (currentDoc == null) {
        Fluttertoast.showToast(
          msg: 'Document not found',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Update document with new tag_id
      final updatedDoc = currentDoc.copyWith(tagId: tagId);
      await _db.updateDocument(updatedDoc);

      // Reload documents in provider
      await provider.loadDocuments();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag changed to "$tagTitle"'),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error updating tag: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  // Update Document Title in Database
  Future<void> _updateDocumentTitle(
    BuildContext context,
    dynamic document,
    String newTitle,
    ColorScheme colorScheme,
  ) async {
    try {
      final docId = int.tryParse(document.id.toString());
      if (docId == null) {
        Fluttertoast.showToast(
          msg: 'Invalid document ID',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Get current document from database
      final currentDoc = await _db.getDocumentById(docId);
      if (currentDoc == null) {
        Fluttertoast.showToast(
          msg: 'Document not found',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Update document with new title
      final updatedDoc = currentDoc.copyWith(title: newTitle);
      await _db.updateDocument(updatedDoc);

      // Reload documents in provider
      final provider = Provider.of<HomeProvider>(context, listen: false);
      await provider.loadDocuments();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renamed to "$newTitle"'),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error updating title: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  // Rename Bottom Sheet
  void _showRenameBottomSheet(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: document.name);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface.withOpacity(0.98) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          'Set Document Name',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Icon(
                            Icons.close_rounded,
                            color: colorScheme.primary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingXL),
                // Name Input
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Document name',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? colorScheme.surface.withOpacity(0.3)
                        : colorScheme.surface.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingM,
                      vertical: AppConstants.spacingM,
                    ),
                  ),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                const SizedBox(height: AppConstants.spacingL),
                // Rename Button
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colorScheme.outline.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final newName = nameController.text.trim();
                          if (newName.isNotEmpty) {
                            Navigator.pop(context);
                            await _updateDocumentTitle(
                              context,
                              document,
                              newName,
                              colorScheme,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text(
                          'Rename',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Move/Copy Page
  void _showMoveCopyPage(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
    HomeProvider provider,
    String action,
  ) {
    NavigationService.toMoveCopy(
      arguments: {'document': document, 'action': action},
    );
  }

  // Scanner Mode Selection
  void _showScannerModeBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) => ScannerModeBottomSheet(
        onModeSelected: (mode) {
          if (mode == ScannerMode.simple) {
            NavigationService.toSimpleScannerType();
          } else if (mode == ScannerMode.ai) {
            NavigationService.toAIScannerCamera();
          }
        },
      ),
    );
  }

}
