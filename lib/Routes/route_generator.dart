import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Screens/splash_screen.dart';
import '../Screens/OnBoarding/onboarding_screen.dart';
import '../Screens/home/home_screen.dart';
import '../Screens/tools/tools_screen.dart';
import 'app_routes.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {

    switch (settings.name) {
      case AppRoutes.splash:
        return GetPageRoute(
          page: () => const SplashScreen(),
          settings: settings,
        );

      case AppRoutes.onboarding:
        return GetPageRoute(
          page: () => OnboardingScreen(),
          settings: settings,
        );

      case AppRoutes.home:
        return GetPageRoute(
          page: () => const HomeScreen(),
          settings: settings,
        );

      case AppRoutes.tools:
        return GetPageRoute(
          page: () => const ToolsScreen(),
          settings: settings,
        );

      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return GetPageRoute(
      page: () => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: const Center(
          child: Text('Page not found'),
        ),
      ),
    );
  }
}

