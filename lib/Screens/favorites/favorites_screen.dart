import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import '../../Constants/app_constants.dart';
import '../../Providers/home_provider.dart';
import '../../Components/empty_state.dart';
import '../../Services/database_helper.dart';
import '../../Models/document_model.dart';
import '../../Routes/navigation_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<DocumentModel> _favoriteDocuments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load favorite documents from FavouriteDocuments table
      final favoriteDocs = await _db.getAllFavouriteDocuments();

      // Convert FavouriteDocuments to DocumentModel
      _favoriteDocuments = await Future.wait(favoriteDocs.map((favDoc) async {
        // Get the referenced document to get type
        final documentId = favDoc['document_id'] as int?;
        String category = 'document';
        bool isFavorite = true; // All items in FavouriteDocuments are favorites
        
        if (documentId != null) {
          final document = await _db.getDocument(documentId);
          if (document != null) {
            category = document['type']?.toString() ?? 'document';
          }
        }
        
        // Determine file type from image path extension if type is not available
        final imagePath = favDoc['Image_path']?.toString() ?? '';
        if (category == 'document' && imagePath.isNotEmpty) {
          final extension = imagePath.toLowerCase().split('.').last;
          if (extension == 'pdf') {
            category = 'pdf';
          } else if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
            category = 'image';
          }
        }
        
        final createdDate = favDoc['created_date'] != null
            ? DateTime.tryParse(favDoc['created_date'].toString())
            : null;
        
        return DocumentModel(
          id: favDoc['id']?.toString() ?? '',
          name: favDoc['title']?.toString() ?? 'Untitled',
          createdAt: createdDate ?? DateTime.now(),
          location: 'In this device',
          category: category,
          isFavorite: isFavorite,
          thumbnailPath: favDoc['image_thumbnail']?.toString(),
          imagePath: imagePath,
          isDeleted: false,
        );
      }));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading favorites: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<HomeProvider>();

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: isDark
            ? colorScheme.surface.withOpacity(0.3)
            : colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(
              Icons.bookmark_rounded,
              color: Colors.amber.shade700,
              size: 24,
            ),
            const SizedBox(width: AppConstants.spacingS),
            Text(
              'Favorites',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_favoriteDocuments.length}',
                style: TextStyle(
                  color: Colors.amber.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: colorScheme.onSurface,
            ),
            onPressed: () async {
              await _loadFavorites();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          : _favoriteDocuments.isEmpty
              ? const EmptyState(
                  title: 'No favorites yet',
                  subtitle:
                      'Tap the bookmark icon on any document to add it to favorites',
                  icon: Icons.bookmark_border_rounded,
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  color: colorScheme.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppConstants.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _favoriteDocuments.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppConstants.spacingS),
                          itemBuilder: (context, index) {
                            final document = _favoriteDocuments[index];
                            return _buildDocumentCard(
                              context,
                              document,
                              provider,
                              colorScheme,
                              isDark,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    DocumentModel document,
    HomeProvider provider,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _handleDocumentTap(context, document),
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
                    // Star (Favorite) icon - Remove from favorites
                    IconButton(
                      onPressed: () async {
                        // Get favorite document to get document_id
                        final favId = int.tryParse(document.id);
                        if (favId != null) {
                          final favDoc = await _db.getFavouriteDocument(favId);
                          if (favDoc != null) {
                            final documentId = favDoc['document_id'] as int?;
                            
                            // Update Document table to set favourite = false
                            if (documentId != null) {
                              await _db.updateDocument(documentId, {
                                'favourite': 0,
                                'updated_date': DateTime.now().toIso8601String(),
                              });
                            }
                            
                            // Remove from FavouriteDocuments table
                            await _db.deleteFavouriteDocument(favId);
                            
                            // Reload favorites and home provider
                            await _loadFavorites();
                            await provider.loadDocuments();
                            
                            if (mounted) {
                              Fluttertoast.showToast(
                                msg: '"${document.name}" removed from favorites',
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.amber,
                                textColor: Colors.white,
                              );
                            }
                          }
                        }
                      },
                      icon: Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Colors.amber.shade600,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 25,
                        minHeight: 25,
                      ),
                      tooltip: 'Remove favorite',
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
    DocumentModel document,
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

  void _handleDocumentTap(BuildContext context, DocumentModel document) {
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

    final category = document.category.toLowerCase();
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

  Future<void> _handleShareDocument(BuildContext context, DocumentModel document) async {
    // Check if it's a folder
    final category = document.category.toLowerCase();
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

  void _showDocumentOptionsBottomSheet(
    BuildContext context,
    DocumentModel document,
    ColorScheme colorScheme,
    bool isDark,
    HomeProvider provider,
  ) {
    // Import the method from home_screen.dart or create a shared component
    // For now, we'll create a simple version here
    // You can extract this to a shared component later
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surface.withOpacity(0.98)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.drive_file_move_rounded,
                  color: colorScheme.primary),
              title: const Text('Move'),
              onTap: () {
                Navigator.pop(context);
                // Handle move
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Move to Trash'),
              onTap: () async {
                Navigator.pop(context);
                // Get the document_id from FavouriteDocuments
                final favId = int.tryParse(document.id);
                if (favId != null) {
                  final favDoc = await _db.getFavouriteDocument(favId);
                  if (favDoc != null) {
                    final documentId = favDoc['document_id'] as int?;
                    if (documentId != null) {
                      // Move document to trash (soft delete)
                      await _db.softDeleteDocument(documentId);
                      // Remove from FavouriteDocuments
                      await _db.deleteFavouriteDocument(favId);
                      // Reload favorites
                      await _loadFavorites();
                      // Reload home provider
                      await provider.loadDocuments();
                      if (mounted) {
                        Fluttertoast.showToast(
                          msg: '"${document.name}" moved to trash',
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                        );
                      }
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

