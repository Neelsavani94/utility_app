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
