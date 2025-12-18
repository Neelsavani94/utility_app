import 'dart:io';
import 'dart:typed_data';
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

  static Future<dynamic>? toExtractText({String? imagePath}) {
    return navigateTo(
      AppRoutes.extractText,
      arguments: {'imagePath': imagePath},
    );
  }


  static Future<dynamic>? toQRGenerator() {
    return navigateTo(AppRoutes.qrGenerator);
  }

  static Future<dynamic>? toPhotoEditor({required List<File> imageFiles}) {
    return navigateTo(
      AppRoutes.photoEditor,
      arguments: {'imageFiles': imageFiles},
    );
  }

  static Future<dynamic>? toScanPDF() {
    return navigateTo(AppRoutes.scanPDF);
  }

  static Future<dynamic>? toScanPDFFilter({required List<dynamic> imageFiles}) {
    return navigateTo(
      AppRoutes.scanPDFFilter,
      arguments: {'imageFiles': imageFiles},
    );
  }

  static Future<dynamic>? toScanPDFProgress({
    required List<dynamic> imageFiles,
    required String filter,
    Map<String, dynamic>? filteredImages,
  }) {
    return navigateTo(
      AppRoutes.scanPDFProgress,
      arguments: {
        'imageFiles': imageFiles,
        'filter': filter,
        'filteredImages': filteredImages,
      },
    );
  }

  static Future<dynamic>? toScanPDFViewer({required String pdfPath}) {
    return navigateTo(
      AppRoutes.scanPDFViewer,
      arguments: {'pdfPath': pdfPath},
    );
  }

  static Future<dynamic>? toSplitPDF() {
    return navigateTo(AppRoutes.splitPDF);
  }

  static Future<dynamic>? toSplitPdfImagesList({required List<dynamic> pageImages}) {
    return navigateTo(
      AppRoutes.splitPDFImagesList,
      arguments: {'pageImages': pageImages},
    );
  }

  static Future<dynamic>? toSplitPdfPageEditor({
    required Uint8List initialBytes,
    Function(Uint8List)? onImageEdited,
  }) {
    return navigateTo(
      AppRoutes.splitPDFPageEditor,
      arguments: {
        'initialBytes': initialBytes,
        'onImageEdited': onImageEdited,
      },
    );
  }

  static Future<dynamic>? toCompress() {
    return navigateTo(AppRoutes.compress);
  }

  static Future<dynamic>? toWatermark() {
    return navigateTo(AppRoutes.watermark);
  }

  static Future<dynamic>? toTrash() {
    return navigateTo(AppRoutes.trash);
  }

  static Future<dynamic>? toSimpleScannerType() {
    return navigateTo(AppRoutes.simpleScannerType);
  }

  static Future<dynamic>? toSimpleScannerCamera({required dynamic scanType}) {
    return navigateTo(
      AppRoutes.simpleScannerCamera,
      arguments: {'scanType': scanType},
    );
  }

  static Future<dynamic>? toSimpleScannerEditor({
    required List<File> images,
    required dynamic scanType,
  }) {
    return navigateTo(
      AppRoutes.simpleScannerEditor,
      arguments: {
        'images': images,
        'scanType': scanType,
      },
    );
  }

  static Future<dynamic>? toAIScannerCamera() {
    return navigateTo(AppRoutes.aiScannerCamera);
  }

  static Future<dynamic>? toAIScannerEditor({required List<File> images}) {
    return navigateTo(
      AppRoutes.aiScannerEditor,
      arguments: {'images': images},
    );
  }

  static Future<dynamic>? toFavorites() {
    return navigateTo(AppRoutes.favorites);
  }

  static Future<dynamic>? toImageViewer({
    required String imagePath,
    String? imageName,
  }) {
    return navigateTo(
      AppRoutes.imageViewer,
      arguments: {
        'imagePath': imagePath,
        'imageName': imageName,
      },
    );
  }

  static Future<dynamic>? toImportFiles({
    bool forExtractText = false,
    bool forWatermark = false,
  }) {
    return navigateTo(
      AppRoutes.importFiles,
      arguments: {
        'forExtractText': forExtractText,
        'forWatermark': forWatermark,
      },
    );
  }
}

