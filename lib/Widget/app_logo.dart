import 'package:flutter/material.dart';

/// Reusable App Logo Widget
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final Widget? fallback;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/logo.png',
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            // Fallback widget or default icon
            if (fallback != null) {
              return fallback!;
            }
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, colorScheme.secondary],
                ),
              ),
              child: Icon(
                Icons.description_rounded,
                color: Colors.white,
                size: (width ?? 40) * 0.5,
              ),
            );
          },
        ),
      ),
    );
  }
}

