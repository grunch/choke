import 'package:flutter/material.dart';

/// BJJ Brand Colors - Style Guide
///
/// A powerful color palette extracted from Brazilian Jiu-Jitsu imagery.
/// Four essential colors that embody discipline, growth, achievement, and purity.

class BJJColors {
  // Navy Black - The Foundation
  /// Deep, authoritative background representing discipline and mastery.
  /// Usage: Backgrounds, headers, footers, overlays
  static const Color navy = Color(0xFF121A2E);
  static const Color navyDark = Color(0xFF0D1117);

  // BJJ Green - The Growth
  /// Vibrant green symbolizing growth, progress, and the journey through belt ranks.
  /// Usage: Primary actions, CTAs, success states, highlights
  static const Color green = Color(0xFF1BA34E);
  static const Color greenLight = Color(0xFF2DC45C);
  static const Color greenDark = Color(0xFF15823E);

  // Championship Gold - The Achievement
  /// Bold gold representing achievement, excellence, and championship spirit.
  /// Usage: Accents, badges, awards, special highlights
  static const Color gold = Color(0xFFF5B800);
  static const Color goldLight = Color(0xFFFFCC33);
  static const Color goldDark = Color(0xFFC49400);

  // Pure White - The Clarity
  /// Clean white for clarity, purity, and the traditional white gi.
  /// Usage: Text on dark backgrounds, cards, clean spaces
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F5F5);

  // Utility colors
  static const Color grey = Color(0xFF8B949E);
  static const Color greyDark = Color(0xFF484F58);
  static const Color greyLight = Color(0xFFC9D1D9);

  // Semantic colors
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = gold;
  static const Color success = green;
  static const Color info = Color(0xFF2196F3);

  // Extended palette for fighter color selection
  static const Color red = Color(0xFFD32F2F);
  static const Color blue = Color(0xFF2196F3);
  static const Color purple = Color(0xFF9C27B0);
  static const Color orange = Color(0xFFFF9800);

  /// Pre-defined fighter color palette for match creation
  static const List<Color> fighterPalette = [
    green,
    gold,
    red,
    blue,
    white,
    purple,
    orange,
    navy,
  ];
}

/// App Theme Configuration
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: BJJColors.navy,
      colorScheme: const ColorScheme.dark(
        primary: BJJColors.green,
        onPrimary: BJJColors.white,
        secondary: BJJColors.gold,
        onSecondary: BJJColors.navy,
        surface: BJJColors.navyDark,
        onSurface: BJJColors.white,
        error: BJJColors.error,
        onError: BJJColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BJJColors.navy,
        foregroundColor: BJJColors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BJJColors.green,
          foregroundColor: BJJColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BJJColors.green,
          side: const BorderSide(color: BJJColors.green, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BJJColors.gold),
      ),
      cardTheme: CardThemeData(
        color: BJJColors.navyDark,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BJJColors.navyDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BJJColors.greyDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BJJColors.greyDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BJJColors.green, width: 2),
        ),
        labelStyle: const TextStyle(color: BJJColors.grey),
        hintStyle: const TextStyle(color: BJJColors.greyDark),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: BJJColors.navy,
        selectedItemColor: BJJColors.green,
        unselectedItemColor: BJJColors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BJJColors.gold,
        foregroundColor: BJJColors.navy,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: BJJColors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: BJJColors.white,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: BJJColors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: BJJColors.white,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: BJJColors.white),
        bodyMedium: TextStyle(fontSize: 14, color: BJJColors.greyLight),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: BJJColors.green,
        ),
      ),
    );
  }

  /// Light theme — light backgrounds, dark text, same BJJ accent colors
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: BJJColors.offWhite,
      colorScheme: const ColorScheme.light(
        primary: BJJColors.green,
        onPrimary: BJJColors.white,
        secondary: BJJColors.gold,
        onSecondary: BJJColors.navy,
        surface: BJJColors.white,
        onSurface: BJJColors.navy,
        error: BJJColors.error,
        onError: BJJColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BJJColors.white,
        foregroundColor: BJJColors.navy,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BJJColors.green,
          foregroundColor: BJJColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BJJColors.green,
          side: const BorderSide(color: BJJColors.green, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BJJColors.goldDark),
      ),
      cardTheme: CardThemeData(
        color: BJJColors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BJJColors.offWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BJJColors.greyLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BJJColors.greyLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BJJColors.green, width: 2),
        ),
        labelStyle: const TextStyle(color: BJJColors.grey),
        hintStyle: const TextStyle(color: BJJColors.greyLight),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: BJJColors.white,
        selectedItemColor: BJJColors.green,
        unselectedItemColor: BJJColors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BJJColors.gold,
        foregroundColor: BJJColors.navy,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: BJJColors.navy,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: BJJColors.navy,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: BJJColors.navy,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: BJJColors.navy,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: BJJColors.navy),
        bodyMedium: TextStyle(fontSize: 14, color: BJJColors.greyDark),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: BJJColors.green,
        ),
      ),
    );
  }

  /// Championship theme variant - for special screens
  static ThemeData get championshipTheme {
    return darkTheme.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: BJJColors.gold,
        onPrimary: BJJColors.navy,
        secondary: BJJColors.white,
        onSecondary: BJJColors.navy,
        surface: BJJColors.navy,
        onSurface: BJJColors.gold,
      ),
      scaffoldBackgroundColor: BJJColors.navy,
    );
  }
}
