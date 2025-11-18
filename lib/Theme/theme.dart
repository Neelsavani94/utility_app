import 'package:flutter/material.dart';

class AppTheme {
  // Unique & Best Color Palette for ScanifyAI
  // Primary: Vibrant Purple-Indigo (modern, premium, creative)
  static const Color primaryLight = Color(0xFF6C5CE7); // Vibrant Purple-Indigo - Premium & Creative
  static const Color primaryDark = Color(0xFFA78BFA); // Lighter Purple for dark mode
  
  // Secondary: Soft Purple-Magenta (creative, premium)
  static const Color accentLight = Color(0xFFAF52DE); // Purple-Magenta
  static const Color accentDark = Color(0xFFBF5AF2); // Lighter Purple for dark mode
  
  // Tertiary: Emerald Green (success, growth)
  static const Color tertiaryLight = Color(0xFF30D158); // Green
  static const Color tertiaryDark = Color(0xFF32D74B); // Lighter Green for dark mode
  
  // Neutral backgrounds - Ultra minimal & clean
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color bgLightSecondary = Color(0xFFF5F7FA);
  static const Color bgDark = Color(0xFF000000);
  static const Color bgDarkSecondary = Color(0xFF1C1C1E);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryLight,
      secondary: accentLight,
      tertiary: tertiaryLight,
      surface: bgLight,
      background: bgLightSecondary,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: const Color(0xFF0A0E27),
      onSurface: const Color(0xFF1A1F3A),
      surfaceVariant: const Color(0xFFF5F7FA),
      outline: const Color(0xFFE5E7EB),
    ),
    scaffoldBackgroundColor: bgLightSecondary,
    // Use system fonts (Inter on Android, SF Pro on iOS)
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
      ),
      displayMedium: TextStyle(
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
      ),
      displaySmall: TextStyle(
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'SF Pro Text',
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'SF Pro Text',
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryDark,
      secondary: accentDark,
      tertiary: tertiaryDark,
      surface: bgDarkSecondary,
      background: bgDark,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: const Color(0xFFF5F7FA),
      onSurface: const Color(0xFFD1D5DB),
      surfaceVariant: const Color(0xFF2A2F4A),
      outline: const Color(0xFF3A3F5A),
    ),
    scaffoldBackgroundColor: bgDark,
    // Use system fonts (Inter on Android, SF Pro on iOS)
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
      ),
      displayMedium: TextStyle(
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
      ),
      displaySmall: TextStyle(
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'SF Pro Text',
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'SF Pro Text',
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
      ),
    ),
  );
}
