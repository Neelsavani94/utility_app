import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_routes.dart';

class NavigationService {
  // Navigate to a route
  static Future<dynamic>? navigateTo(String routeName, {dynamic arguments}) {
    return Get.toNamed(routeName, arguments: arguments);
  }

  // Navigate and remove previous route
  static Future<dynamic>? navigateToReplacement(
    String routeName, {
    dynamic arguments,
  }) {
    return Get.offNamed(routeName, arguments: arguments);
  }

  // Navigate and remove all previous routes
  static Future<dynamic>? navigateToAndRemoveUntil(
    String routeName, {
    dynamic arguments,
  }) {
    return Get.offAllNamed(routeName, arguments: arguments);
  }

  // Go back
  static void goBack({dynamic result}) {
    Get.back(result: result);
  }

  // Go back with result
  static void goBackWithResult(dynamic result) {
    Get.back(result: result);
  }

  // Check if can go back
  static bool canGoBack() {
    if (Get.context != null) {
      return Navigator.canPop(Get.context!);
    }
    return false;
  }

  // Navigate to specific routes
  static Future<dynamic>? toSplash() {
    return navigateTo(AppRoutes.splash);
  }

  static Future<dynamic>? toOnboarding() {
    return navigateToReplacement(AppRoutes.onboarding);
  }

  static Future<dynamic>? toHome() {
    return navigateToAndRemoveUntil(AppRoutes.home);
  }

  static Future<dynamic>? toTools() {
    return navigateTo(AppRoutes.tools);
  }

  static Future<dynamic>? toSettings() {
    return navigateTo(AppRoutes.settings);
  }

  static Future<dynamic>? toManageTags() {
    return navigateTo(AppRoutes.manageTags);
  }

  static Future<dynamic>? toPremium() {
    return navigateTo(AppRoutes.premium);
  }

  static Future<dynamic>? toMoveCopy({Map<String, dynamic>? arguments}) {
    return navigateTo(AppRoutes.moveCopy, arguments: arguments);
  }

  static Future<dynamic>? toESignList() {
    return navigateTo(AppRoutes.esignList);
  }

  static Future<dynamic>? toESignCreate() {
    return navigateTo(AppRoutes.esignCreate);
  }

  static Future<dynamic>? toExtractText() {
    return navigateTo(AppRoutes.extractText);
  }

  static Future<dynamic>? toQRReader() {
    return navigateTo(AppRoutes.qrReader);
  }

  static Future<dynamic>? toQRGenerator() {
    return navigateTo(AppRoutes.qrGenerator);
  }
}

