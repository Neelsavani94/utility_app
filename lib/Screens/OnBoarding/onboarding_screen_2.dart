import 'package:flutter/material.dart';

class OnboardingPage2 extends StatefulWidget {
  const OnboardingPage2({super.key});

  @override
  State<OnboardingPage2> createState() => _OnboardingPage2State();
}

class _OnboardingPage2State extends State<OnboardingPage2>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _deviceController;
  late List<Animation<double>> _featureAnimations;
  late Animation<double> _deviceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _deviceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Stagger animations for features
    _featureAnimations = List.generate(3, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.15,
            0.7 + index * 0.15,
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });

    _deviceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _deviceController,
        curve: Curves.easeOut,
      ),
    );

    _deviceController.forward();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _deviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final features = [
      {
        'icon': Icons.auto_awesome_rounded,
        'title': 'AI-Powered',
        'desc': 'Intelligent code suggestions',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.speed_rounded,
        'title': 'Lightning Fast',
        'desc': 'Optimized performance',
        'color': colorScheme.secondary,
      },
      {
        'icon': Icons.security_rounded,
        'title': 'Secure & Private',
        'desc': 'Your code stays protected',
        'color': colorScheme.tertiary,
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Minimal Device Illustration
          FadeTransition(
            opacity: _deviceAnimation,
            child: ScaleTransition(
              scale: _deviceAnimation,
              child: Container(
                width: 200,
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: colorScheme.surface,
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.4)
                          : Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Code lines
                      ...List.generate(
                        3,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            width: double.infinity,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colorScheme.outline.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Code block
                      Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 64),

          // Features List - Minimal Design
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _featureAnimations[index],
              builder: (context, child) {
                final animation = _featureAnimations[index];
                return Opacity(
                  opacity: animation.value,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      20 * (1 - animation.value),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: (features[index]['color'] as Color)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              features[index]['icon'] as IconData,
                              color: features[index]['color'] as Color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  features[index]['title'] as String,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onBackground,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  features[index]['desc'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onBackground
                                        .withOpacity(0.5),
                                    height: 1.3,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
