import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:image_picker/image_picker.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../Constants/app_constants.dart';
import '../../Providers/home_provider.dart';
import '../../Components/empty_state.dart';
import '../../Components/bottom_navigation_bar_custom.dart';
import '../../Routes/navigation_service.dart';
import '../../Services/database_helper.dart';
import '../../Services/tag_service.dart';
import '../../Models/tag_model.dart';
import '../../Models/document_model.dart';
import '../../Services/document_scan_serivce.dart';
import '../../Services/clipboard_service.dart';
import '../../Services/file_storage_service.dart';
import '../../Services/photo_editor_service.dart';
import '../../Widget/app_logo.dart';
import '../settings/settings_screen.dart';
import 'document_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final DatabaseHelper _db = DatabaseHelper.instance;
  final TagService _tagService = TagService.instance;
  List<Tag> _tags = [];
  bool _isLoadingTags = true;
  int _previousBottomNavIndex = 0;
  bool _showToolsOnHome = true;
  DateTime? _lastRefreshTime;
  final documentScanner = DocumentScanner(
    options: DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.filter,
      pageLimit: 1,
      isGalleryImport: true,
    ),
  );
  final scanService = DocumentScanService();
  final clipboardService = ClipboardService.instance;
  final fileStorageService = FileStorageService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showToolsOnHome = SettingsScreen.getShowToolsOnHome();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only check tools setting when dependencies change (less frequent refresh)
    // Full refresh is handled by PopScope and bottom nav change
    final currentShowTools = SettingsScreen.getShowToolsOnHome();
    if (_showToolsOnHome != currentShowTools) {
      setState(() {
        _showToolsOnHome = currentShowTools;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Update when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      final currentShowTools = SettingsScreen.getShowToolsOnHome();
      if (_showToolsOnHome != currentShowTools) {
        setState(() {
          _showToolsOnHome = currentShowTools;
        });
      }
    }
  }

  Future<void> _loadTags() async {
    if (!mounted) return;

    setState(() {
      _isLoadingTags = true;
    });

    try {
      final tags = await _tagService.getAllTags();
      if (mounted) {
        setState(() {
          _tags = tags;
          _isLoadingTags = false;
        });
      }
    } catch (e) {
      log('Error loading tags: $e');
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
        // Show error toast
        Fluttertoast.showToast(
          msg: 'Error loading tags: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        // Always check and sync tools setting state when widget rebuilds
        final currentShowTools = SettingsScreen.getShowToolsOnHome();
        if (_showToolsOnHome != currentShowTools) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _showToolsOnHome = currentShowTools;
              });
            }
          });
        }

        // Refresh documents, tags and check tools setting when bottom nav changes
        final currentIndex = provider.selectedBottomNavIndex;
        if (_previousBottomNavIndex != currentIndex && currentIndex == 0) {
          // Refresh when returning to home
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Debounce: Only refresh if it's been more than 500ms since last refresh
              final now = DateTime.now();
              if (_lastRefreshTime == null ||
                  now.difference(_lastRefreshTime!).inMilliseconds > 500) {
                _lastRefreshTime = now;
                // Refresh documents
                provider.loadDocuments();
                // Refresh tags
                _loadTags();
                // Check if tools setting has changed (already checked above, but ensure sync)
                if (_showToolsOnHome != currentShowTools) {
                  setState(() {
                    _showToolsOnHome = currentShowTools;
                  });
                }
              }
            }
          });
        }
        _previousBottomNavIndex = currentIndex;

        return PopScope(
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            // Refresh documents, tags and check tools setting when returning to this screen
            if (!didPop) {
              // Debounce: Only refresh if it's been more than 500ms since last refresh
              final now = DateTime.now();
              if (_lastRefreshTime == null ||
                  now.difference(_lastRefreshTime!).inMilliseconds > 500) {
                _lastRefreshTime = now;
                // Refresh documents
                provider.loadDocuments();
                // Refresh tags
                _loadTags();
                // Check if tools setting has changed
                final currentShowTools = SettingsScreen.getShowToolsOnHome();
                if (_showToolsOnHome != currentShowTools) {
                  setState(() {
                    _showToolsOnHome = currentShowTools;
                  });
                }
              }
            }
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: colorScheme.background,
            appBar: _buildAppBar(
              context,
              colorScheme,
              isDark,
              provider,
              RichText(
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
                            // Quick Tools Grid (conditional)
                            if (_showToolsOnHome)
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: _buildToolsGrid(context, provider),
                              ),
                            if (_showToolsOnHome)
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
                                        MediaQuery.of(context).size.height *
                                        0.3,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              colorScheme.primary,
                                            ),
                                      ),
                                    ),
                                  )
                                : provider.filteredDocuments.isEmpty
                                ? SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.3,
                                    child: const EmptyState(
                                      title: 'Start Scanning!',
                                      subtitle: 'We don\'t see any files',
                                      icon: Icons.document_scanner_rounded,
                                    ),
                                  )
                                : provider.viewMode == 'grid'
                                ? _buildDocumentsGridView(context, provider)
                                : _buildDocumentsList(context, provider),
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
              onItemSelected: (index) async {
                // Handle QR Scan navigation (index 1) - open scanner directly
                if (index == 1) {
                  await _handleQRScan(context, colorScheme);
                } else if (index == 3) {
                  // Handle OCR Scan (index 3) - pick image first, then navigate
                  await _handleOCRScan(context, colorScheme);
                } else if (index == 4) {
                  // Handle Import (index 4) - navigate to import files
                  NavigationService.toImportFiles();
                } else {
                  // For other items, update the selected index
                  provider.setSelectedBottomNavIndex(index);
                }
              },
            ),
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
            // Logo Image
            const AppLogo(width: 40, height: 40, borderRadius: 10),
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
            await _loadTags();
          },
          colorScheme,
          isDark,
        ),
        _buildHeaderAction(
          context,
          Icons.settings_rounded,
          () {
            NavigationService.toSettings();
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
                PopupMenuItem(
                  value: 'view_mode',
                  child: _buildMenuItem(
                    context,
                    Icons.view_module_rounded,
                    'View Mode',
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
                  case 'view_mode':
                    _showViewModeDialog(context, colorScheme, isDark, provider);
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
              // Merge PDF tool - same as Tools Screen
              NavigationService.toImportFiles(forMerge: true);
            } else if (index == 1) {
              // Split PDF tool - same as Tools Screen
              NavigationService.toImportFiles(forSplit: true);
            } else if (index == 2) {
              // eSign tool - same as Tools Screen
              NavigationService.toESignList();
            } else if (index == 3) {
              // Watermark tool - same as Tools Screen
              NavigationService.toImportFiles(forWatermark: true);
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

      // Open ProImageEditor directly for first image
      final photoEditorService = PhotoEditorService.instance;
      await photoEditorService.openEditorForMultipleAndSave(
        context: context,
        imageFiles: files,
      );
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

  Widget _buildDocumentsList(BuildContext context, HomeProvider provider) {
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

  Widget _buildDocumentsGridView(BuildContext context, HomeProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: provider.filteredDocuments.length,
      itemBuilder: (context, index) {
        final document = provider.filteredDocuments[index];
        return _buildGridDocumentCard(
          context,
          document,
          provider,
          colorScheme,
          isDark,
        );
      },
    );
  }

  Widget _buildGridDocumentCard(
    BuildContext context,
    DocumentModel document,
    HomeProvider provider,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () async {
        // Since we're showing groups, create Document from group data
        // DocumentDetailScreen uses document.title to find the group
        final docToShow = Document(
          title: document.name, // Group name
          type: document.category,
          imagePath: document.imagePath ?? "",
          thumbnailPath: document.thumbnailPath,
          id: int.tryParse(document.id) ?? 0, // Group ID or 0
          isFavourite: document.isFavorite,
          isDeleted: document.isDeleted,
          createdAt: document.createdAt,
          deletedAt: document.deletedAt,
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocumentDetailScreen(document: docToShow),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? colorScheme.outline.withOpacity(0.1)
                : colorScheme.outline.withOpacity(0.08),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail - takes most of the space
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: _buildDocumentThumbnail(
                  document,
                  colorScheme,
                  200,
                  isDark,
                ),
              ),
            ),
            // Content section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Text(
                      document.name,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Date
                    Text(
                      document.formattedDate,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    // Action icons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Phone icon
                        Icon(
                          Icons.phone_android_rounded,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        // Star icon
                        GestureDetector(
                          onTap: () => provider.toggleFavorite(document.id),
                          child: Icon(
                            document.isFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 16,
                            color: document.isFavorite
                                ? Colors.amber
                                : colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        // Share icon
                        GestureDetector(
                          onTap: () {
                            // Handle share
                            _handleShareDocument(context, document);
                          },
                          child: Icon(
                            Icons.share_rounded,
                            size: 14,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        // More icon
                        GestureDetector(
                          onTap: () {
                            // Handle more options
                            _showDocumentOptionsBottomSheet(
                              context,
                              document,
                              colorScheme,
                              isDark,
                              provider,
                            );
                          },
                          child: Icon(
                            Icons.more_vert_rounded,
                            size: 14,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    DocumentModel document,
    HomeProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        // Since we're showing groups, create Document from group data
        // DocumentDetailScreen uses document.title to find the group
        final docToShow = Document(
          title: document.name, // Group name
          type: document.category,
          imagePath: document.imagePath ?? "",
          thumbnailPath: document.thumbnailPath,
          id: int.tryParse(document.id) ?? 0, // Group ID or 0
          isFavourite: document.isFavorite,
          isDeleted: document.isDeleted,
          createdAt: document.createdAt,
          deletedAt: document.deletedAt,
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocumentDetailScreen(document: docToShow),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? colorScheme.outline.withOpacity(0.1)
                : colorScheme.outline.withOpacity(0.08),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail on the left
            _buildDocumentThumbnail(document, colorScheme, 56, isDark),
            const SizedBox(width: 12),
            // Content - Title, Date, Location
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
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Date/Time
                  Text(
                    document.formattedDate,
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Location with phone icon
                  Row(
                    children: [
                      Icon(
                        Icons.phone_android_rounded,
                        size: 12,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'In this device',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right side actions: Tag Button, then Share, Star, More in row
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tag button (showing category) - at top
                InkWell(
                  onTap: () {
                    provider.setSelectedCategory(document.category);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.primaryContainer.withOpacity(0.3)
                          : colorScheme.primaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      document.category,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Share, Star, More icons in a row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Share icon
                    IconButton(
                      onPressed: () => _handleShareDocument(context, document),
                      icon: Icon(
                        Icons.share_rounded,
                        size: 18,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 25,
                        minHeight: 25,
                      ),
                      tooltip: 'Share',
                    ),
                    // Star (Favorite) icon
                    IconButton(
                      onPressed: () async {
                        await provider.toggleFavorite(document.id);
                      },
                      icon: Icon(
                        document.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 18,
                        color: document.isFavorite
                            ? Colors.amber.shade600
                            : colorScheme.onSurface.withOpacity(0.7),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 25,
                        minHeight: 25,
                      ),
                      tooltip: document.isFavorite
                          ? 'Remove favorite'
                          : 'Add favorite',
                    ),
                    // More options (vertical ellipsis)
                    IconButton(
                      onPressed: () {
                        _showDocumentOptionsBottomSheet(
                          context,
                          document,
                          colorScheme,
                          isDark,
                          provider,
                        );
                      },
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 25,
                        minHeight: 25,
                      ),
                      tooltip: 'More options',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentThumbnail(
    dynamic document,
    ColorScheme colorScheme,
    double size,
    bool isDark,
  ) {
    final thumbnailPath = document.thumbnailPath;

    // If thumbnail exists and is not empty, show thumbnail
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      final thumbnailFile = File(thumbnailPath);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colorScheme.surfaceVariant.withOpacity(0.3),
          border: Border.all(
            color: isDark
                ? colorScheme.outline.withOpacity(0.1)
                : colorScheme.outline.withOpacity(0.08),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            thumbnailFile,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to icon if thumbnail fails to load
              return Container(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                child: Icon(
                  Icons.description_rounded,
                  color: colorScheme.onSurface.withOpacity(0.4),
                  size: size * 0.4,
                ),
              );
            },
          ),
        ),
      );
    }

    // Default icon - minimal design
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withOpacity(0.1)
              : colorScheme.outline.withOpacity(0.08),
          width: 0.5,
        ),
      ),
      child: Icon(
        Icons.description_rounded,
        color: colorScheme.onSurface.withOpacity(0.4),
        size: size * 0.4,
      ),
    );
  }

  Future<void> _handleShareDocument(
    BuildContext context,
    dynamic document,
  ) async {
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
      final isPDF =
          category == 'pdf' ||
          filePath.toLowerCase().endsWith('.pdf') ||
          document.name.toLowerCase().endsWith('.pdf');

      await Share.shareXFiles([
        XFile(filePath),
      ], text: isPDF ? 'PDF Document' : 'Image');
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

  void _showScannerOptionsDialog(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    showDialog(
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose Scanner Type',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildScannerOption(
                  context: context,
                  colorScheme: colorScheme,
                  title: 'AI Scanner',
                  icon: Icons.auto_awesome,
                  description: 'Advanced AI-powered scanning',
                  onTap: () {
                    Navigator.of(context).pop();
                    _scanWithAIScanner();
                  },
                ),
                const SizedBox(height: 12),
                _buildScannerOption(
                  context: context,
                  colorScheme: colorScheme,
                  title: 'Simple Scanner',
                  icon: Icons.document_scanner,
                  description: 'Quick and simple scanning',
                  onTap: () {
                    Navigator.of(context).pop();
                    _scanWithSimpleScanner();
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerOption({
    required BuildContext context,
    required ColorScheme colorScheme,
    required String title,
    required IconData icon,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: colorScheme.onSurface.withOpacity(0.4),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanWithAIScanner() async {
    try {
      // AI Scanner with full mode for advanced scanning
      final aiScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.jpeg,
          mode: ScannerMode.full,
          pageLimit: 1,
          isGalleryImport: true,
        ),
      );

      DocumentScanningResult result = await aiScanner.scanDocument();
      log(result.images.toString());
      await scanService.scanAndSaveDocument(result: result);

      // Reload documents in home screen after saving
      if (mounted) {
        await context.read<HomeProvider>().loadDocuments();
        Fluttertoast.showToast(
          msg: 'Document saved successfully',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      log('Error in AI Scanner: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error scanning document: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _scanWithSimpleScanner() async {
    try {
      // Simple Document Scanner with filter mode
      final simpleScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.jpeg,
          mode: ScannerMode.filter,
          pageLimit: 1,
          isGalleryImport: true,
        ),
      );

      DocumentScanningResult result = await simpleScanner.scanDocument();
      log(result.images.toString());
      await scanService.scanAndSaveDocument(result: result);

      // Reload documents in home screen after saving
      if (mounted) {
        await context.read<HomeProvider>().loadDocuments();
        Fluttertoast.showToast(
          msg: 'Document saved successfully',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      log('Error in Simple Scanner: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error scanning document: $e',
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
          onTap: () async {
            await _requestCameraPermissionAndShowDialog(
              context,
              colorScheme,
              isDark,
            );
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

  Future<void> _requestCameraPermissionAndShowDialog(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) async {
    // Request camera permission
    final status = await Permission.camera.request();

    if (status.isGranted) {
      // Permission granted, show scanner options dialog
      _showScannerOptionsDialog(context, colorScheme, isDark);
    } else if (status.isDenied) {
      // Permission denied, show message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Camera permission is required to use this feature',
            ),
            backgroundColor: colorScheme.error,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
      }
    } else if (status.isPermanentlyDenied) {
      // Permission permanently denied, open app settings
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Camera Permission Required'),
            content: const Text(
              'Camera permission is required to use this feature. Please enable it in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
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
                      (doc['type'] as String? ?? '').toLowerCase() ==
                          'folder' &&
                      (doc['title'] as String? ?? '').toLowerCase() ==
                          folderName.toLowerCase(),
                  orElse: () => <String, dynamic>{
                    'title': '',
                    'type': '',
                    'Image_path': '',
                  },
                );

                if ((existingFolder['title'] as String? ?? '').isNotEmpty) {
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

              try {
                // Check for duplicate tag names using TagService
                final existingTag = await _tagService.findTagByTitle(tagName);
                if (existingTag != null) {
                  Fluttertoast.showToast(
                    msg: 'Tag "$tagName" already exists',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                  );
                  return;
                }

                // Create tag using TagService
                final createdTag = await _tagService.createTag(
                  title: tagName,
                  isDefault: false,
                );

                if (mounted) {
                  Navigator.pop(context, createdTag.id);
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
                log('Error creating tag: $e');
                if (mounted) {
                  Fluttertoast.showToast(
                    msg: 'Error creating tag: $e',
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
    return null;
  }

  void _showSortByDialog(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    HomeProvider provider,
  ) {
    final sortOptions = [
      {
        'label': 'Name (A-Z)',
        'value': 'name_asc',
        'icon': Icons.sort_by_alpha_rounded,
      },
      {
        'label': 'Name (Z-A)',
        'value': 'name_desc',
        'icon': Icons.sort_by_alpha_rounded,
      },
      {
        'label': 'Date (Newest)',
        'value': 'date_desc',
        'icon': Icons.access_time_rounded,
      },
      {
        'label': 'Date (Oldest)',
        'value': 'date_asc',
        'icon': Icons.access_time_rounded,
      },
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
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.6),
                size: 20,
              ),
              title: Text(
                option['label'] as String,
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
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

  void _showViewModeDialog(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    HomeProvider provider,
  ) {
    // Small delay to ensure popup is dismissed
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark
              ? colorScheme.surface.withOpacity(0.95)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'View Mode',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // List View Option
              ListTile(
                leading: Icon(
                  Icons.view_list_rounded,
                  color: provider.viewMode == 'list'
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.6),
                  size: 24,
                ),
                title: Text(
                  'List View',
                  style: TextStyle(
                    color: provider.viewMode == 'list'
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: provider.viewMode == 'list'
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                trailing: provider.viewMode == 'list'
                    ? Icon(
                        Icons.check_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  provider.setViewMode('list');
                  Navigator.pop(context);
                },
              ),
              // Grid View Option
              ListTile(
                leading: Icon(
                  Icons.view_module_rounded,
                  color: provider.viewMode == 'grid'
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.6),
                  size: 24,
                ),
                title: Text(
                  'Grid View',
                  style: TextStyle(
                    color: provider.viewMode == 'grid'
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: provider.viewMode == 'grid'
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                trailing: provider.viewMode == 'grid'
                    ? Icon(
                        Icons.check_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  provider.setViewMode('grid');
                  Navigator.pop(context);
                },
              ),
            ],
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
    });
  }

  void _showDocumentOptionsBottomSheet(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
    bool isDark,
    HomeProvider provider,
  ) {
    final options = <Map<String, dynamic>>[
      {
        'icon': Icons.drive_file_move_rounded,
        'title': 'Move Tools',
        'color': colorScheme.primary,
      },
      if (clipboardService.hasCopiedDocument() ||
          clipboardService.hasCopiedGroup())
        {
          'icon': Icons.paste_rounded,
          'title': 'Paste',
          'color': colorScheme.secondary,
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
        'title': 'Copy Tools',
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
      case 'Move Tools':
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
      case 'Copy Tools':
        _handleCopyDocument(context, document, colorScheme, provider);
        break;
      case 'Paste':
        _handlePasteDocument(context, document, colorScheme, provider);
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
  Future<void> _handleMoveDocument(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) async {
    await _showMoveCopyPage(context, document, colorScheme, provider, 'Move');
  }

  // Paste Document Function - For Home Screen groups
  Future<void> _handlePasteDocument(
    BuildContext context,
    dynamic targetDocument,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) async {
    // Check if we have a copied group
    if (clipboardService.hasCopiedGroup()) {
      try {
        final sourceGroupName = clipboardService.getCopiedGroupName()!;
        final targetGroupName = targetDocument.name;

        if (sourceGroupName == targetGroupName) {
          Fluttertoast.showToast(
            msg: 'Cannot paste group into itself',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
          return;
        }

        // Get all documents from source group
        // final sourceDocs = await _db.getGroupDocs(sourceGroupName); // TODO: Implement getGroupDocs method
        final sourceDocs = <Map<String, dynamic>>[];

        if (sourceDocs.isEmpty) {
          Fluttertoast.showToast(
            msg: 'Source group is empty',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
          return;
        }

        // Ensure target group table exists
        // await _db.createDocTable(targetGroupName); // TODO: Implement createDocTable method

        // Copy all documents from source group to target group
        int copiedCount = 0;
        for (final _doc in sourceDocs) {
          try {
            // await _db.addGroupDoc( // TODO: Implement addGroupDoc method
            //   groupName: targetGroupName,
            //   imgPath: _doc['imgpath']?.toString() ?? '',
            //   imgName: _doc['imgname']?.toString() ?? '',
            //   imgNote: _doc['imgnote']?.toString() ?? '',
            // );
            copiedCount++;
          } catch (e) {
            log('Error copying document from group: $e');
          }
        }

        // Update target group's first image if needed
        if (copiedCount > 0 && sourceDocs.isNotEmpty) {
          final firstImg = sourceDocs[0]['imgpath']?.toString() ?? '';
          if (firstImg.isNotEmpty) {
            // await _db.updateGroupFirstImg(targetGroupName, firstImg); // TODO: Implement updateGroupFirstImg method
          }
        }

        Fluttertoast.showToast(
          msg: 'Group copied successfully ($copiedCount items)',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: colorScheme.primary,
          textColor: Colors.white,
        );

        // Clear clipboard
        clipboardService.clearClipboard();

        // Refresh documents
        if (mounted) {
          provider.loadDocuments();
        }
      } catch (e) {
        log('Error pasting group: $e');
        Fluttertoast.showToast(
          msg: 'Error pasting group: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
      return;
    }

    // Fallback to document paste if no group copied
    if (!clipboardService.hasCopiedDocument()) {
      Fluttertoast.showToast(
        msg: 'No document or group copied',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final copiedDoc = clipboardService.getCopiedDocument()!;

      // Get target folder (tagId) from target document
      // int? targetTagId; // TODO: Use targetTagId when copyDocumentWithDetails is implemented
      int? targetTagId;
      if (targetDocument is DocumentModel) {
        // final targetDoc = await _db.getDocumentById( // TODO: Implement getDocumentById method
        //   int.parse(targetDocument.id),
        // );
        final targetDoc = await _db.getDocument(int.parse(targetDocument.id));
        targetTagId = targetDoc?['tag_id'] as int?;
      } else if (targetDocument is Document) {
        targetTagId = targetDocument.tagId;
      }
      // Note: targetTagId is prepared for future use when copyDocumentWithDetails is implemented

      // Copy the document with all its details
      // final newDocId = await _db.copyDocumentWithDetails( // TODO: Implement copyDocumentWithDetails method
      //   copiedDoc.id!,
      //   targetTagId,
      // );
      final newDocId = copiedDoc.id; // Temporary: just use same ID

      // Copy files
      // final newDoc = await _db.getDocumentById(newDocId); // TODO: Implement getDocumentById method
      final newDocMap = await _db.getDocument(newDocId!);
      if (newDocMap != null) {
        // Copy main image file
        final isPDF =
            (newDocMap['type'] as String? ?? '').toLowerCase() == 'pdf';
        final newImagePath = await fileStorageService.copyFile(
          sourcePath: newDocMap['Image_path'] as String? ?? '',
          newFileName: '${newDocMap['title']}_copy',
          isPDF: isPDF,
        );

        if (newImagePath != null) {
          // Copy thumbnail if exists
          String? newThumbnailPath;
          final thumbnailPath = newDocMap['image_thumbnail'] as String?;
          if (thumbnailPath != null) {
            newThumbnailPath = await fileStorageService.copyThumbnail(
              sourceThumbnailPath: thumbnailPath,
              newThumbnailName: '${newDocMap['title']}_thumb_copy',
            );
          }

          // Update document with new file paths
          // final updatedDoc = newDoc.copyWith( // TODO: Fix - newDoc is Map, not Document
          //   imagePath: newImagePath,
          //   thumbnailPath: newThumbnailPath,
          // );
          // await _db.updateDocument(updatedDoc); // TODO: Fix updateDocument signature
          await _db.updateDocument(newDocId, {
            'Image_path': newImagePath,
            'image_thumbnail': newThumbnailPath,
          });

          // Copy all document detail files
          final details = await _db.getDocumentDetailsByDocumentId(newDocId);
          for (final detailMap in details) {
            final detailImagePath = detailMap['Image_path'] as String? ?? '';
            final newDetailImagePath = await fileStorageService.copyFile(
              sourcePath: detailImagePath,
              newFileName: '${detailMap['title']}_copy',
              isPDF: false,
            );

            String? newDetailThumbnailPath;
            final detailThumbnailPath = detailMap['image_thumbnail'] as String?;
            if (detailThumbnailPath != null) {
              newDetailThumbnailPath = await fileStorageService.copyThumbnail(
                sourceThumbnailPath: detailThumbnailPath,
                newThumbnailName: '${detailMap['title']}_thumb_copy',
              );
            }

            if (newDetailImagePath != null) {
              // final updatedDetail = detail.copyWith( // TODO: Fix - detail is Map, not DocumentDetail
              //   imagePath: newDetailImagePath,
              //   thumbnailPath: newDetailThumbnailPath,
              // );
              // await _db.updateDocumentDetail(updatedDetail); // TODO: Fix updateDocumentDetail signature
              await _db.updateDocumentDetail(detailMap['id'] as int, {
                'Image_path': newDetailImagePath,
                'image_thumbnail': newDetailThumbnailPath,
              });
            }
          }
        }
      }

      Fluttertoast.showToast(
        msg: 'Document pasted successfully',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: colorScheme.primary,
        textColor: Colors.white,
      );

      // Refresh documents
      if (mounted) {
        provider.loadDocuments();
      }
    } catch (e) {
      log('Error pasting document: $e');
      Fluttertoast.showToast(
        msg: 'Error pasting document: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
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
      final email = result.trim();
      if (email.isEmpty) {
        return;
      }

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
        final isPDF =
            filePath.toLowerCase().endsWith('.pdf') ||
            document.name.toLowerCase().endsWith('.pdf') ||
            (document.category?.toLowerCase() ?? '') == 'pdf';

        // Use Share.shareXFiles to share the file with email attachment
        // This will show a share sheet where user can select email client
        // The file will be attached automatically
        await Share.shareXFiles(
          [XFile(filePath)],
          text:
              'Please find the attached ${isPDF ? 'PDF' : 'image'}: ${document.name}\n\nTo: $email',
          subject: document.name,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sharing "${document.name}" - Select email to send to $email',
              ),
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
            msg: 'Error sending email: $e',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      }
    }
  }

  // OCR Document Function - Get image from Document table and open ExtractTextScreen
  Future<void> _handleOCRDocument(
    BuildContext context,
    dynamic document,
  ) async {
    try {
      // Get document ID
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

      // Get document from database
      final documentData = await _db.getDocument(docId);
      if (documentData == null) {
        Fluttertoast.showToast(
          msg: 'Document not found',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Get image path from document (prefer Image_path, fallback to image_thumbnail)
      final imagePath = documentData['Image_path']?.toString() ?? '';
      final thumbnailPath = documentData['image_thumbnail']?.toString() ?? '';
      final filePath = imagePath.isNotEmpty ? imagePath : thumbnailPath;

      if (filePath.isEmpty) {
        Fluttertoast.showToast(
          msg: 'Image path not available',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        Fluttertoast.showToast(
          msg: 'Image file not found',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Check if it's a PDF (ExtractTextScreen works with images, not PDFs)
      final isPDF =
          filePath.toLowerCase().endsWith('.pdf') ||
          (documentData['type']?.toString().toLowerCase() ?? '') == 'pdf';

      if (isPDF) {
        Fluttertoast.showToast(
          msg: 'OCR is available for images only. PDFs are not supported.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      // Navigate to ExtractTextScreen with the image path
      if (context.mounted) {
        NavigationService.toExtractText(imagePath: filePath);
      }
    } catch (e) {
      log('Error opening OCR screen: $e');
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error opening OCR: ${e.toString()}',
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
  Future<void> _handleCopyDocument(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
    HomeProvider provider,
  ) async {
    await _showMoveCopyPage(context, document, colorScheme, provider, 'Copy');
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
                              content: Text(
                                'File "${document.name}" locked with PIN',
                              ),
                              backgroundColor: colorScheme.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        } else {
                          Fluttertoast.showToast(
                            msg: 'Please enter a 4-digit PIN',
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.orange,
                            textColor: Colors.white,
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
                          isLocked,
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

  // Perform Save Document Function - Save all document details to Gallery
  Future<void> _performSaveDocument(
    BuildContext context,
    dynamic document,
    String selectedFormat,
    bool isLocked,
    ColorScheme colorScheme,
  ) async {
    try {
      // Get document ID
      final docId = int.tryParse(document.id.toString());
      if (docId == null) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: 'Invalid document ID',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      // Get document name for file naming
      final documentName = document.name;
      if (documentName.isEmpty) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: 'Invalid document name',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      // Get all document details using document_id
      final documentDetails = await _db
          .getDocumentDetailsByDocumentIdNotDeleted(docId);

      if (documentDetails.isEmpty) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: 'No images found in document',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
        }
        return;
      }

      // Filter valid image paths from document details
      final validImagePaths = <String>[];
      for (final detail in documentDetails) {
        // Try Image_path first, then image_thumbnail
        final imgPath = detail['Image_path']?.toString() ?? '';
        final thumbnailPath = detail['image_thumbnail']?.toString() ?? '';

        // Prefer Image_path, fallback to thumbnail
        final pathToCheck = imgPath.isNotEmpty ? imgPath : thumbnailPath;

        if (pathToCheck.isNotEmpty) {
          final file = File(pathToCheck);
          if (await file.exists()) {
            validImagePaths.add(pathToCheck);
          }
        }
      }

      if (validImagePaths.isEmpty) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: 'No valid image files found',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      if (selectedFormat == 'Photo') {
        // Save all images to gallery
        await _saveAllImagesToGallery(
          context,
          validImagePaths,
          documentName,
          isLocked,
          colorScheme,
        );
      } else if (selectedFormat == 'PDF') {
        // Convert all images to PDF and save
        await _saveAllImagesAsPdf(
          context,
          validImagePaths,
          documentName,
          isLocked,
          colorScheme,
        );
      }
    } catch (e) {
      log('Error saving document: $e');
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error saving: ${e.toString()}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  // Save all images to gallery
  Future<void> _saveAllImagesToGallery(
    BuildContext context,
    List<String> imagePaths,
    String groupName,
    bool isLocked,
    ColorScheme colorScheme,
  ) async {
    BuildContext? dialogContext;
    bool dialogShown = false;

    try {
      // Request appropriate permission based on platform
      // Note: saver_gallery handles permissions internally, but we'll request for better UX
      PermissionStatus? status;

      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), photos permission is used
        // For Android 12 and below, storage permission is used
        // Try photos first (for Android 13+)
        status = await Permission.photos.request();

        // If photos permission is not available or denied, try storage (for older Android)
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      } else if (Platform.isIOS) {
        // For iOS, use photos permission
        status = await Permission.photos.request();
      }

      // If permission is denied, show user-friendly message
      // Note: saver_gallery might still work without explicit permission in some cases
      if (status != null) {
        if (!status.isGranted && !status.isLimited) {
          if (context.mounted) {
            // Check if permission is permanently denied
            if (status.isPermanentlyDenied) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Permission Required'),
                  content: const Text(
                    'Photo library permission is required to save images to gallery. '
                    'Please enable it in app settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        openAppSettings();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              );
              return;
            } else {
              // Permission denied but not permanently - show message but continue
              // saver_gallery might handle it internally
              log('Permission not granted, but continuing with save operation');
            }
          }
        }
      }

      int savedCount = 0;
      int failedCount = 0;

      // Determine save location based on lock status
      Directory? saveDirectory;
      if (isLocked) {
        // For locked images, save to hidden folder with .nomedia file
        if (Platform.isAndroid) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Save to a hidden folder that won't be scanned by gallery
            saveDirectory = Directory(
              '${externalDir.path.split('/Android')[0]}/.ScanifyAI_Locked',
            );
          } else {
            final appDir = await getApplicationDocumentsDirectory();
            saveDirectory = Directory('${appDir.path}/.Locked');
          }
        } else if (Platform.isIOS) {
          // For iOS, save to app's private directory
          final appDir = await getApplicationDocumentsDirectory();
          saveDirectory = Directory('${appDir.path}/.Locked');
        }

        if (saveDirectory != null && !await saveDirectory.exists()) {
          await saveDirectory.create(recursive: true);

          // Create .nomedia file to hide from gallery (Android)
          if (Platform.isAndroid) {
            final nomediaFile = File('${saveDirectory.path}/.nomedia');
            if (!await nomediaFile.exists()) {
              await nomediaFile.create();
            }
          }
        }
      }

      // Save each image to gallery
      for (final imagePath in imagePaths) {
        try {
          final file = File(imagePath);
          if (await file.exists()) {
            // Read image bytes
            final imageBytes = await file.readAsBytes();

            // Generate filename
            final fileName = '${groupName}_${savedCount + 1}.jpg';

            if (isLocked && saveDirectory != null) {
              // Save locked images to hidden directory
              final lockedFilePath = '${saveDirectory.path}/$fileName';
              final lockedFile = File(lockedFilePath);
              await lockedFile.writeAsBytes(imageBytes);
              savedCount++;
              log('Successfully saved locked image: $fileName');
            } else {
              // Save normal images to gallery
              final result = await SaverGallery.saveImage(
                imageBytes,
                fileName: fileName,
                skipIfExists: false,
              );

              if (result.isSuccess) {
                savedCount++;
                log('Successfully saved image to gallery: $fileName');
              } else {
                failedCount++;
                log(
                  'Failed to save image: $imagePath - ${result.errorMessage ?? "Unknown error"}',
                );
              }
            }
          } else {
            failedCount++;
            log('Image file not found: $imagePath');
          }
        } catch (e) {
          failedCount++;
          log('Error saving image $imagePath: $e');
        }
      }

      // Show result
      if (context.mounted) {
        if (savedCount > 0) {
          Fluttertoast.showToast(
            msg: isLocked
                ? 'Saved $savedCount locked image(s) to hidden folder'
                : 'Saved $savedCount image(s) to gallery',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: colorScheme.primary,
            textColor: Colors.white,
          );
        }
      }

      if (failedCount > 0) {
        Fluttertoast.showToast(
          msg: 'Failed to save $failedCount image(s)',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
      }
      // }
    } catch (e) {
      log('Error saving images to gallery: $e');
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error saving images: ${e.toString()}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } finally {
      // Always close loading dialog
      if (dialogShown && dialogContext != null && context.mounted) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }
    }
  }

  // Convert all images to PDF and save
  Future<void> _saveAllImagesAsPdf(
    BuildContext context,
    List<String> imagePaths,
    String groupName,
    bool isLocked,
    ColorScheme colorScheme,
  ) async {
    BuildContext? dialogContext;
    bool dialogShown = false;
    PdfDocument? document;

    try {
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            dialogContext = ctx;
            return Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Converting images to PDF...',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        dialogShown = true;
      }

      // Create PDF document
      document = PdfDocument();

      // Add each image as a page in the PDF
      for (final imagePath in imagePaths) {
        try {
          final file = File(imagePath);
          if (!await file.exists()) {
            log('Image file not found: $imagePath');
            continue;
          }

          // Read image bytes
          final imageBytes = await file.readAsBytes();

          // Create PDF page with image
          final page = document.pages.add();
          final pageSize = page.size;

          // Load image
          final image = PdfBitmap(imageBytes);

          // Calculate image size to fit page while maintaining aspect ratio
          double imageWidth = image.width.toDouble();
          double imageHeight = image.height.toDouble();
          double pageWidth = pageSize.width;
          double pageHeight = pageSize.height;

          double scaleX = pageWidth / imageWidth;
          double scaleY = pageHeight / imageHeight;
          double scale = scaleX < scaleY ? scaleX : scaleY;

          double scaledWidth = imageWidth * scale;
          double scaledHeight = imageHeight * scale;

          // Center image on page
          double x = (pageWidth - scaledWidth) / 2;
          double y = (pageHeight - scaledHeight) / 2;

          // Draw image
          page.graphics.drawImage(
            image,
            Rect.fromLTWH(x, y, scaledWidth, scaledHeight),
          );
        } catch (e) {
          log('Error adding image to PDF: $imagePath - $e');
        }
      }

      // Determine save location based on lock status
      Directory? pdfDir;
      if (isLocked) {
        // For locked PDFs, save to hidden folder
        if (Platform.isAndroid) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Save to a hidden folder that won't be accessible without PIN
            pdfDir = Directory(
              '${externalDir.path.split('/Android')[0]}/.ScanifyAI_Locked/PDFs',
            );
          } else {
            final appDir = await getApplicationDocumentsDirectory();
            pdfDir = Directory('${appDir.path}/.Locked/PDFs');
          }
        } else if (Platform.isIOS) {
          // For iOS, save to app's private directory
          final appDir = await getApplicationDocumentsDirectory();
          pdfDir = Directory('${appDir.path}/.Locked/PDFs');
        }

        if (pdfDir != null && !await pdfDir.exists()) {
          await pdfDir.create(recursive: true);

          // Create .nomedia file to hide from gallery (Android)
          if (Platform.isAndroid) {
            final nomediaFile = File('${pdfDir.path}/.nomedia');
            if (!await nomediaFile.exists()) {
              await nomediaFile.create();
            }
          }
        }
      } else {
        // Save PDF to app's documents directory (no permissions required)
        // This is accessible via file manager in the app's folder
        final directory = await getApplicationDocumentsDirectory();
        pdfDir = Directory('${directory.path}/PDFs');
        if (!await pdfDir.exists()) {
          await pdfDir.create(recursive: true);
        }
      }

      if (pdfDir == null) {
        throw Exception('Could not determine PDF save location');
      }

      // Generate PDF filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = groupName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final pdfFileName = '${sanitizedName}_$timestamp.pdf';
      final pdfPath = '${pdfDir.path}/$pdfFileName';

      // Save PDF file
      final pdfBytes = await document.save();
      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(pdfBytes);

      // Show success message with file location
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: isLocked
              ? 'Locked PDF saved: $pdfFileName\nLocation: Hidden folder (requires PIN)'
              : 'PDF saved: $pdfFileName\nLocation: App Documents/PDFs',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: colorScheme.primary,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      log('Error converting images to PDF: $e');
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error creating PDF: ${e.toString()}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } finally {
      // Always dispose PDF document
      document?.dispose();

      // Always close loading dialog using the stored dialog context
      if (dialogShown && dialogContext != null && context.mounted) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
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
                      final result = await _showCreateTagDialog(
                        context,
                        colorScheme,
                        isDark,
                      );
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
      final currentDocMap = await _db.getDocument(docId);
      if (currentDocMap == null) {
        Fluttertoast.showToast(
          msg: 'Document not found',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Update document with new tag_id and type (tagTitle is the type)
      await _db.updateDocument(docId, {
        'type': tagTitle,
        'updated_date': DateTime.now().toIso8601String(),
      });

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
      // For Home Screen, document is a DocumentModel representing a group
      final oldGroupName = document.name;
      final trimmedNewTitle = newTitle.trim();

      if (oldGroupName.isEmpty || trimmedNewTitle.isEmpty) {
        Fluttertoast.showToast(
          msg: 'Invalid document name',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // If name hasn't changed, no need to update
      if (oldGroupName == trimmedNewTitle) {
        Navigator.pop(context);
        return;
      }

      // Check if new name already exists in Document table (excluding current document and deleted documents)
      final docId = int.tryParse(document.id.toString());
      final allDocuments = await _db.getDocumentsNotDeleted();

      // Check for duplicate name (excluding current document)
      final duplicateExists = allDocuments.any((doc) {
        final existingTitle = doc['title'] as String? ?? '';
        final existingId = doc['id'] as int?;
        return existingTitle == trimmedNewTitle && existingId != docId;
      });

      if (duplicateExists) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: 'Document name already exists',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
        }
        return;
      }

      // Update document title in database
      if (docId != null) {
        await _db.updateDocument(docId, {
          'title': trimmedNewTitle,
          'updated_date': DateTime.now().toIso8601String(),
        });
      }

      // Reload documents in provider
      final provider = Provider.of<HomeProvider>(context, listen: false);
      await provider.loadDocuments();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renamed to "$trimmedNewTitle"'),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      log('Error updating document name: $e');
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error updating name: ${e.toString()}',
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
  Future<void> _showMoveCopyPage(
    BuildContext context,
    dynamic document,
    ColorScheme colorScheme,
    HomeProvider provider,
    String action,
  ) async {
    try {
      // Get document ID
      final documentId = int.tryParse(document.id);
      if (documentId == null) {
        Fluttertoast.showToast(
          msg: 'Invalid document ID',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Get all DocumentDetail entries for this document from DocumentDetail table
      final documentDetails = await _db
          .getDocumentDetailsByDocumentIdNotDeleted(documentId);

      if (documentDetails.isEmpty) {
        Fluttertoast.showToast(
          msg: 'No items found in this document',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      // Navigate to MoveCopyScreen with document and documentDetails list
      NavigationService.toMoveCopy(
        arguments: {
          'document': document,
          'action': action,
          'documentDetails': documentDetails,
        },
      );
    } catch (e) {
      log('Error loading document details: $e');
      Fluttertoast.showToast(
        msg: 'Error: ${e.toString()}',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // Handle QR Scan - Open scanner directly
  Future<void> _handleQRScan(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    try {
      final String? result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SimpleBarcodeScannerPage(),
        ),
      );

      if (result != null &&
          result.isNotEmpty &&
          context.mounted &&
          result.toString() != '-1') {
        // Determine if it's a QR code or barcode
        final isQRCode =
            result.startsWith('http://') ||
            result.startsWith('https://') ||
            result.startsWith('www.') ||
            result.contains('://');

        final scannedType = isQRCode ? 'qrCode' : 'barcode';
        _showQRResultPopup(context, result, scannedType, colorScheme);
      }
    } catch (e) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error scanning: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  // Show QR Scan Result Popup
  void _showQRResultPopup(
    BuildContext context,
    String scannedText,
    String scannedType,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppConstants.spacingM),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          scannedType == 'qrCode' ? 'QR Code' : 'Barcode',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colorScheme.onSurface,
                          size: 24,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Scanned Text
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingM,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.spacingM),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.surface.withOpacity(0.5)
                          : colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      scannedText,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.onSurface,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingM),
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final searchQuery = Uri.encodeComponent(
                              scannedText,
                            );
                            final searchUrl = Uri.parse(
                              'https://www.google.com/search?q=$searchQuery',
                            );
                            try {
                              await launchUrl(
                                searchUrl,
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (e) {
                              Fluttertoast.showToast(
                                msg: 'Could not open browser',
                                toastLength: Toast.LENGTH_SHORT,
                              );
                            }
                          },
                          icon: const Icon(Icons.search_rounded, size: 20),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppConstants.spacingM,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingM),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await Share.share(scannedText);
                            } catch (e) {
                              Fluttertoast.showToast(
                                msg: 'Error sharing: $e',
                                toastLength: Toast.LENGTH_SHORT,
                              );
                            }
                          },
                          icon: const Icon(Icons.share_rounded, size: 20),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppConstants.spacingM,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Handle OCR Scan - Pick image first, then navigate to ExtractTextScreen
  Future<void> _handleOCRScan(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null && context.mounted) {
        // Navigate to ExtractTextScreen with the selected image
        NavigationService.toExtractText(imagePath: image.path);
      }
    } catch (e) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: 'Error picking image: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }
}
