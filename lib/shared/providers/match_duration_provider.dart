import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kMatchDurationKey = 'choke:default-match-duration';

/// Default match duration options in seconds (3–10 minutes).
const List<int> defaultDurationOptions = [180, 240, 300, 360, 420, 480, 600];

/// Default duration: 5 minutes (300 seconds).
const int defaultMatchDuration = 300;

/// Provider for the default match duration in seconds.
///
/// Persists the selection to [SharedPreferences] and hydrates
/// synchronously at startup (same pattern as [ThemeModeNotifier]).
final matchDurationProvider =
    StateNotifierProvider<MatchDurationNotifier, int>((ref) {
  return MatchDurationNotifier();
});

/// Manages the default match duration state with persistence.
class MatchDurationNotifier extends StateNotifier<int> {
  /// Creates a [MatchDurationNotifier] with 300s (5 min) as default.
  MatchDurationNotifier() : super(defaultMatchDuration);

  /// Load saved duration from [SharedPreferences]. Call before runApp().
  static Future<int> loadSavedDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kMatchDurationKey) ?? defaultMatchDuration;
  }

  /// Set initial duration synchronously (called at startup).
  void hydrate(int seconds) {
    state = seconds;
  }

  /// Updates the default duration and persists to [SharedPreferences].
  Future<void> setDuration(int seconds) async {
    state = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMatchDurationKey, seconds);
  }
}

/// Format seconds as mm:ss.
String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
