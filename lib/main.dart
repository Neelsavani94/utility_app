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
import 'Screens/qr_generator/qr_generator_screen.dart';
import 'Screens/scan_pdf/scan_pdf_filter_screen.dart';
import 'Screens/scan_pdf/scan_pdf_progress_screen.dart';
import 'Screens/scan_pdf/scan_pdf_viewer_screen.dart';
import 'Screens/esign/sign_list_screen.dart';
import 'Screens/esign/sign_create_screen.dart';
import 'modules/split_pdf/split_pdf_screen.dart';
import 'modules/split_pdf/split_pdf_images_list_screen.dart';
import 'modules/split_pdf/split_pdf_page_editor_screen.dart';
import 'modules/split_pdf/models/pdf_page_image.dart';
import 'dart:typed_data';
import 'modules/compress/compress_screen.dart';
import 'modules/watermark/watermark_screen.dart';
import 'Screens/trash/trash_screen.dart';
import 'Screens/favorites/favorites_screen.dart';
import 'Screens/image_viewer/image_viewer_screen.dart';
import 'Screens/import_files/import_files_screen.dart';
import 'dart:io';
import 'Theme/theme.dart';
import 'Services/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await GetStorage.init();
  // Initialize database
  await DatabaseHelper.instance.database;
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
                  documentDetails: arguments['documentDetails'] as List<Map<String, dynamic>>? ?? [],
                );
              },
            ),
            GetPage(
              name: AppRoutes.extractText,
              page: () {
                final arguments = Get.arguments as Map<String, dynamic>?;
                final imagePath = arguments?['imagePath'] as String?;
                return ExtractTextScreen(imagePath: imagePath);
              },
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
                            .map(
                              (key, value) => MapEntry(
                                key,
                                value is Uint8List ? value : null,
                              ),
                            )
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
            GetPage(
              name: AppRoutes.splitPDF,
              page: () => const SplitPdfScreen(),
            ),
            GetPage(
              name: AppRoutes.splitPDFImagesList,
              page: () {
                final arguments = Get.arguments as Map<String, dynamic>?;
                final rawList = (arguments?['pageImages'] as List?) ?? [];
                final pageImages = rawList
                    .map((e) => e as PdfPageImage)
                    .toList();
                return SplitPdfImagesListScreen(pageImages: pageImages);
              },
            ),
            GetPage(
              name: AppRoutes.splitPDFPageEditor,
              page: () {
                final arguments = Get.arguments as Map<String, dynamic>?;
                return SplitPdfPageEditorScreen(
                  initialBytes: arguments!['initialBytes'] as Uint8List,
                  onImageEdited:
                      arguments['onImageEdited'] as Function(Uint8List)?,
                );
              },
            ),
            GetPage(
              name: AppRoutes.compress,
              page: () => const CompressScreen(),
            ),
            GetPage(
              name: AppRoutes.watermark,
              page: () => const WatermarkScreen(),
            ),
            GetPage(
              name: AppRoutes.esignList,
              page: () => const SignListScreen(),
            ),
            GetPage(
              name: AppRoutes.esignCreate,
              page: () => const SignCreateScreen(),
            ),
            GetPage(name: AppRoutes.trash, page: () => const TrashScreen()),
            GetPage(
              name: AppRoutes.favorites,
              page: () => const FavoritesScreen(),
            ),
            GetPage(
              name: AppRoutes.imageViewer,
              page: () {
                final arguments = Get.arguments as Map<String, dynamic>?;
                return ImageViewerScreen(
                  imagePath: arguments!['imagePath'] as String,
                  imageName: arguments['imageName'] as String?,
                );
              },
            ),
            GetPage(
              name: AppRoutes.importFiles,
              page: () {
                final arguments = Get.arguments as Map<String, dynamic>?;
                final forExtractText = arguments?['forExtractText'] as bool? ?? false;
                final forWatermark = arguments?['forWatermark'] as bool? ?? false;
                final forMerge = arguments?['forMerge'] as bool? ?? false;
                final forSplit = arguments?['forSplit'] as bool? ?? false;
                return ImportFilesScreen(
                  forExtractText: forExtractText,
                  forWatermark: forWatermark,
                  forMerge: forMerge,
                  forSplit: forSplit,
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
