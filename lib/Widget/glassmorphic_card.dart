import 'package:flutter/material.dart';
import '../Constants/app_constants.dart';

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? borderRadius;
  final double? blur;
  final Color? backgroundColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final double? opacity;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: backgroundColor ??
            (isDark
                ? colorScheme.surface.withOpacity(opacity ?? 0.25)
                : colorScheme.surface.withOpacity(opacity ?? 0.85)),
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppConstants.radiusL,
        ),
        border: border ??
            Border.all(
              color: isDark
                  ? colorScheme.outline.withOpacity(0.15)
                  : colorScheme.outline.withOpacity(0.08),
              width: 1,
            ),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.4)
                    : Colors.black.withOpacity(0.04),
                blurRadius: blur ?? 24,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
      ),
      child: child,
    );
  }
}
