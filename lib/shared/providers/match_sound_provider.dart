import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kMatchSoundKey = 'choke:match-sound-enabled';

/// The match clock makes noise unless told otherwise.
///
/// A referee who wants the bell has to do nothing to get it; one refereeing
/// beside three other mats can turn it off. Defaulting the other way would hide
/// the feature from everyone who never opens Settings.
const bool defaultMatchSoundEnabled = true;

/// Whether the start bell and the end horn are audible.
///
/// Persists to [SharedPreferences] and hydrates synchronously at startup, the
/// same pattern as [MatchDurationNotifier].
final matchSoundEnabledProvider =
    StateNotifierProvider<MatchSoundEnabledNotifier, bool>((ref) {
  return MatchSoundEnabledNotifier();
});

/// Manages the match sound preference with persistence.
class MatchSoundEnabledNotifier extends StateNotifier<bool> {
  /// Creates a [MatchSoundEnabledNotifier] with the cues switched on.
  MatchSoundEnabledNotifier() : super(defaultMatchSoundEnabled);

  /// Load the saved preference from [SharedPreferences]. Call before runApp().
  ///
  /// Returns [defaultMatchSoundEnabled] when nothing is stored — which is also
  /// what a device whose preferences cannot be read gets, since a silent clock
  /// nobody asked for is the worse failure of the two.
  static Future<bool> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kMatchSoundKey) ?? defaultMatchSoundEnabled;
  }

  /// Set the initial value synchronously (called at startup).
  void hydrate(bool enabled) => state = enabled;

  /// Updates the preference and persists it.
  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMatchSoundKey, enabled);
  }
}
