import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'choke:theme-mode';

/// Provider for the app theme mode. Defaults to ThemeMode.system.
/// Persists selection to SharedPreferences.
///
/// Hydrated synchronously from SharedPreferences at startup to avoid
/// theme flash on first frame.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  /// Initialize from SharedPreferences. Call before runApp().
  static Future<ThemeMode> loadSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kThemeModeKey);
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  /// Set initial theme mode synchronously (called at startup).
  void hydrate(ThemeMode mode) {
    state = mode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.dark:
        await prefs.setString(_kThemeModeKey, 'dark');
      case ThemeMode.light:
        await prefs.setString(_kThemeModeKey, 'light');
      case ThemeMode.system:
        await prefs.setString(_kThemeModeKey, 'system');
    }
  }
}
