import 'package:flutter/material.dart';
import '../Constants/app_constants.dart';

class BottomNavigationBarCustom extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const BottomNavigationBarCustom({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<BottomNavigationBarCustom> createState() =>
      _BottomNavigationBarCustomState();
}

class _BottomNavigationBarCustomState extends State<BottomNavigationBarCustom>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();

    // Initialize animations for each nav item
    _controllers = List.generate(
      AppConstants.bottomNavItems.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    _scaleAnimations = _controllers.map((controller) {
      return Tween<double>(
        begin: 1.0,
        end: 0.85,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    _fadeAnimations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.4,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    }).toList();

    // Set initial state
    _updateSelectedIndex(widget.selectedIndex);
  }

  @override
  void didUpdateWidget(BottomNavigationBarCustom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _updateSelectedIndex(widget.selectedIndex);
    }
  }

  void _updateSelectedIndex(int index) {
    for (int i = 0; i < _controllers.length; i++) {
      if (i == index) {
        _controllers[i].forward();
      } else {
        _controllers[i].reverse();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingS,
          vertical: AppConstants.spacingS,
        ),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface.withOpacity(0.4) : Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
            bottom: Radius.circular(0),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(AppConstants.bottomNavItems.length, (index) {
            final item = AppConstants.bottomNavItems[index];
            final isSelected = widget.selectedIndex == index;
            final isCenter = index == 2;

            return Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _scaleAnimations[index],
                  _fadeAnimations[index],
                ]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimations[index].value,
                    child: Opacity(
                      opacity: _fadeAnimations[index].value,
                      child: GestureDetector(
                        onTapDown: (_) {
                          _controllers[index].forward();
                        },
                        onTapUp: (_) {
                          _controllers[index].reverse();
                          widget.onItemSelected(index);
                        },
                        onTapCancel: () {
                          _controllers[index].reverse();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.all(isSelected ? 8 : 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primary.withOpacity(0.15)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: isCenter
                                    ? Colors.transparent
                                    : isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withOpacity(0.5),
                                size: isSelected ? 32 : 24,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCenter
                                    ? Colors.transparent
                                    : isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withOpacity(0.6),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ),
    );
  }
}
