import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';

import 'Controller/theme_controller.dart';
import 'Providers/home_provider.dart';
import 'Routes/app_routes.dart';
import 'Screens/splash_screen.dart';
import 'Screens/OnBoarding/onboarding_screen.dart';
import 'Screens/home/home_screen.dart';
import 'Screens/tools/tools_screen.dart';
import 'Screens/settings/settings_screen.dart';
import 'Screens/settings/manage_tags_screen.dart';
import 'Screens/premium/premium_screen.dart';
import 'Screens/move_copy/move_copy_screen.dart';
import 'Screens/extract_text/extract_text_screen.dart';
import 'Screens/qr_reader/qr_reader_screen.dart';
import 'Screens/qr_generator/qr_generator_screen.dart';
import 'Screens/scan_pdf/scan_pdf_filter_screen.dart';
import 'Screens/scan_pdf/scan_pdf_progress_screen.dart';
import 'Screens/scan_pdf/scan_pdf_viewer_screen.dart';
import 'dart:io';
import 'dart:typed_data';
import 'Theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await GetStorage.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.put(ThemeController());

    return Obx(
      () => MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => HomeProvider())],
        child: GetMaterialApp(
          title: 'ScanifyAI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.themeMode.value,
          initialRoute: AppRoutes.splash,
          getPages: [
            GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
            GetPage(name: AppRoutes.onboarding, page: () => OnboardingScreen()),
            GetPage(name: AppRoutes.home, page: () => const HomeScreen()),
            GetPage(name: AppRoutes.tools, page: () => const ToolsScreen()),
            GetPage(
              name: AppRoutes.settings,
              page: () => const SettingsScreen(),
            ),
            GetPage(
              name: AppRoutes.manageTags,
              page: () => const ManageTagsScreen(),
            ),
            GetPage(name: AppRoutes.premium, page: () => const PremiumScreen()),
            GetPage(
              name: AppRoutes.moveCopy,
              page: () {
                final arguments = Get.arguments as Map<String, dynamic>?;
                return MoveCopyScreen(
                  document: arguments!['document'],
                  action: arguments['action'],
                );
              },
            ),
            GetPage(
              name: AppRoutes.extractText,
              page: () => const ExtractTextScreen(),
            ),
            GetPage(
              name: AppRoutes.qrReader,
              page: () => const QRReaderScreen(),
            ),
            GetPage(
              name: AppRoutes.qrGenerator,
              page: () => const QRGeneratorScreen(),
            ),
            GetPage(
              name: AppRoutes.scanPDFFilter,
              page: () {
                final arguments = Get.arguments as Map<String, dynamic>?;
                return ScanPDFFilterScreen(
                  imageFiles: (arguments!['imageFiles'] as List)
                      .map((e) => e as File)
                      .toList(),
                );
              },
            ),
            GetPage(
              name: AppRoutes.scanPDFProgress,
              page: () {
                final arguments = Get.arguments as Map<String, dynamic>?;
                return ScanPDFProgressScreen(
                  imageFiles: (arguments!['imageFiles'] as List)
                      .map((e) => e as File)
                      .toList(),
                  filter: arguments['filter'] as String,
                  filteredImages: arguments['filteredImages'] != null
                      ? (arguments['filteredImages'] as Map<String, dynamic>)
                          .map((key, value) => MapEntry(
                                key,
                                value is Uint8List ? value : null,
                              ))
                      : null,
                );
              },
            ),
            GetPage(
              name: AppRoutes.scanPDFViewer,
              page: () {
                final arguments = Get.arguments as Map<String, dynamic>?;
                return ScanPDFViewerScreen(
                  pdfPath: arguments!['pdfPath'] as String,
                );
              },
            ),
          ],
          unknownRoute: GetPage(
            name: '/notfound',
            page: () => Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Page not found')),
            ),
          ),
        ),
      ),
    );
  }
}
