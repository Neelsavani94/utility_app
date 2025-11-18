import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Controller/onboarding_controller.dart';
import '../Routes/navigation_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.1), weight: 60),
          TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 40),
        ]).animate(
          CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.7)),
    );

    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 2800), () {
      final onboardingController = Get.put(OnboardingController());
      if (onboardingController.isOnboardingSeen) {
        NavigationService.toHome();
      } else {
        NavigationService.toOnboarding();
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colorScheme.background,
                    colorScheme.primary.withOpacity(0.08),
                    colorScheme.secondary.withOpacity(0.05),
                    colorScheme.background,
                  ]
                : [
                    colorScheme.background,
                    colorScheme.primary.withOpacity(0.02),
                    colorScheme.secondary.withOpacity(0.01),
                    colorScheme.background,
                  ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Minimal Logo Design
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? colorScheme.primary.withOpacity(0.3)
                                  : colorScheme.primary.withOpacity(0.2),
                              blurRadius: isDark ? 40 : 30,
                              offset: const Offset(0, 12),
                              spreadRadius: isDark ? 2 : 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.code_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // App Name - Minimal Typography
                      Text(
                        'Scanify',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onBackground,
                          letterSpacing: -1.2,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'AI-Powered Coding Assistant',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: colorScheme.onBackground.withOpacity(0.5),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
