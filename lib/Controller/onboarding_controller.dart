import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../Screens/home/home_screen.dart';

class OnboardingController extends GetxController {
  final _storage = GetStorage();
  final pageController = PageController();
  final currentPage = 0.obs;

  bool get isOnboardingSeen => _storage.read('onboarding_seen') ?? false;

  void setOnboardingSeen() {
    _storage.write('onboarding_seen', true);
  }

  void nextPage() {
    if (currentPage.value < 2) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      completeOnboarding();
    }
  }

  void skipOnboarding() {
    completeOnboarding();
  }

  void completeOnboarding() {
    setOnboardingSeen();
    Get.offAll(() => const HomeScreen(), transition: Transition.fadeIn, duration: const Duration(milliseconds: 800));
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
