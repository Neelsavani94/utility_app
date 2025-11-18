import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  final _storage = GetStorage();
  final themeMode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    final savedTheme = _storage.read('theme') ?? 'system';
    themeMode.value = _getThemeMode(savedTheme);
  }

  void toggleTheme() {
    if (themeMode.value == ThemeMode.light) {
      themeMode.value = ThemeMode.dark;
      _storage.write('theme', 'dark');
    } else {
      themeMode.value = ThemeMode.light;
      _storage.write('theme', 'light');
    }
  }

  ThemeMode _getThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
