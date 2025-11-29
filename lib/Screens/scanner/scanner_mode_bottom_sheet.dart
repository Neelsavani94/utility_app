import 'package:flutter/material.dart';
import '../../Constants/app_constants.dart';

enum ScannerMode {
  simple,
  ai,
}

class ScannerModeBottomSheet extends StatelessWidget {
  final Function(ScannerMode mode) onModeSelected;

  const ScannerModeBottomSheet({
    super.key,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
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
                margin: const EdgeInsets.only(bottom: AppConstants.spacingL),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: Text(
                      'Choose Scanner Mode',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surface.withOpacity(0.5)
                            : colorScheme.surfaceVariant.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurface,
                        size: 18,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.spacingL),

              // Simple Scanner Option
              _buildModeCard(
                context,
                icon: Icons.document_scanner_rounded,
                title: 'Simple Scanner',
                description: 'Manual editing with advanced tools',
                features: [
                  'Crop, rotate, adjust',
                  'Brightness, contrast, filters',
                  'Multiple pages support',
                ],
                colorScheme: colorScheme,
                isDark: isDark,
                onTap: () {
                  Navigator.of(context).pop();
                  onModeSelected(ScannerMode.simple);
                },
              ),

              const SizedBox(height: AppConstants.spacingM),

              // AI Scanner Option
              _buildModeCard(
                context,
                icon: Icons.auto_awesome_rounded,
                title: 'AI Scanner',
                description: 'Automatic enhancement with AI',
                features: [
                  'Auto edge detection',
                  'Perspective correction',
                  'Color & text enhancement',
                ],
                colorScheme: colorScheme,
                isDark: isDark,
                isPremium: true,
                onTap: () {
                  Navigator.of(context).pop();
                  onModeSelected(ScannerMode.ai);
                },
              ),

              const SizedBox(height: AppConstants.spacingM),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required List<String> features,
    required ColorScheme colorScheme,
    required bool isDark,
    bool isPremium = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          gradient: isPremium
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withOpacity(0.1),
                    colorScheme.secondary.withOpacity(0.1),
                  ],
                )
              : null,
          color: isPremium
              ? null
              : (isDark
                  ? colorScheme.surface.withOpacity(0.5)
                  : colorScheme.surfaceVariant.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPremium
                ? colorScheme.primary.withOpacity(0.3)
                : (isDark
                    ? colorScheme.outline.withOpacity(0.2)
                    : colorScheme.outline.withOpacity(0.1)),
            width: isPremium ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: isPremium
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colorScheme.primary, colorScheme.secondary],
                      )
                    : null,
                color: isPremium
                    ? null
                    : colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isPremium ? Colors.white : colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...features.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                feature,
                                style: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: colorScheme.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

