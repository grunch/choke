import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'choke:theme-mode';

/// Provider for the app theme mode. Defaults to ThemeMode.system.
/// Persists selection to SharedPreferences.
///
/// Hydrated synchronously from SharedPreferences at startup to avoid
/// theme flash on first frame.
/// Provides the current [ThemeMode] for the app.
///
/// Defaults to [ThemeMode.system]. The value is persisted to
/// [SharedPreferences] and can be hydrated before the first frame
/// to avoid a theme flash on startup.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Manages the app's [ThemeMode] state with persistence.
///
/// On startup, call [loadSavedThemeMode] to read the saved preference,
/// then [hydrate] to set the initial value synchronously before the
/// first frame renders.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  /// Creates a [ThemeModeNotifier] with [ThemeMode.system] as default.
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

  /// Updates the theme mode and persists the choice to [SharedPreferences].
  ///
  /// Accepts [ThemeMode.system], [ThemeMode.dark], or [ThemeMode.light].
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
