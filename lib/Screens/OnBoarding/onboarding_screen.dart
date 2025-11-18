import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Controller/onboarding_controller.dart';
import '../../Controller/theme_controller.dart';
import '../../Widget/cursor_button.dart';
import 'onboarding_screen_1.dart';
import 'onboarding_screen_2.dart';
import 'onboarding_screen_3.dart';

class OnboardingScreen extends StatelessWidget {
  OnboardingScreen({super.key});

  final controller = Get.put(OnboardingController());

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
                    colorScheme.primary.withOpacity(0.06),
                    colorScheme.secondary.withOpacity(0.04),
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
        child: Stack(
          children: [
            // Page View with swipe navigation
            PageView(
              controller: controller.pageController,
              onPageChanged: (index) => controller.currentPage.value = index,
              children: const [
                OnboardingPage1(),
                OnboardingPage2(),
                OnboardingPage3(),
              ],
            ),

            // Top Bar - Minimal Design
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Theme Toggle Button - Minimal
                    GestureDetector(
                      onTap: () => Get.find<ThemeController>().toggleTheme(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: colorScheme.onSurface,
                          size: 20,
                        ),
                      ),
                    ),

                    // Skip Button - Minimal (only show on first 2 pages)
                    Obx(
                      () => controller.currentPage.value < 2
                          ? GestureDetector(
                              onTap: controller.skipOnboarding,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outline.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Skip',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation - Minimal Design
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.background.withOpacity(0.0),
                      colorScheme.background,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      // Page Indicator Dots - Minimal
                      Obx(
                        () => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            final isActive =
                                controller.currentPage.value == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? colorScheme.primary
                                    : colorScheme.outline.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // CTA Button
                      Obx(
                        () => ScanifyButton(
                          onPressed: controller.nextPage,
                          text: controller.currentPage.value < 2
                              ? 'Continue'
                              : 'Get Started',
                          icon: controller.currentPage.value < 2
                              ? Icons.arrow_forward_rounded
                              : Icons.rocket_launch_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
