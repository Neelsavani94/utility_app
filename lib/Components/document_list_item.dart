import 'package:flutter/material.dart';
import '../Constants/app_constants.dart';
import '../Models/document_model.dart';
import '../Widget/glassmorphic_card.dart';

class DocumentListItem extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;
  final VoidCallback? onMore;

  const DocumentListItem({
    super.key,
    required this.document,
    this.onTap,
    this.onShare,
    this.onFavorite,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      opacity: isDark ? 0.2 : 0.8,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 56,
              height: 76,
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.description_rounded,
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                size: AppConstants.iconL,
              ),
            ),
            const SizedBox(width: AppConstants.spacingM),

            // Document Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppConstants.spacingXS),
                  Text(
                    document.formattedDate,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 12,
                        ),
                  ),
                  const SizedBox(height: AppConstants.spacingXS),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_android_rounded,
                        size: AppConstants.iconXS,
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                      const SizedBox(width: AppConstants.spacingXS),
                      Text(
                        document.location,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.4),
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action Buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.share_rounded,
                    size: AppConstants.iconM,
                  ),
                  onPressed: onShare,
                  color: colorScheme.onSurface.withOpacity(0.6),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: AppConstants.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  ),
                  child: Text(
                    document.category,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingS),
                IconButton(
                  icon: Icon(
                    document.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: AppConstants.iconM,
                  ),
                  onPressed: onFavorite,
                  color: document.isFavorite
                      ? Colors.amber.shade600
                      : colorScheme.onSurface.withOpacity(0.6),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: AppConstants.spacingS),
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: AppConstants.iconM,
                  ),
                  onPressed: onMore,
                  color: colorScheme.onSurface.withOpacity(0.6),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
