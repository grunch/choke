import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAnnouncementsKey = 'choke:announcements-enabled';

/// The announcement channel is on unless the user turns it off.
///
/// A judgement call, and worth stating plainly: the channel is low-frequency
/// and product-related, and nothing here posts a system notification, so
/// nothing escapes the app the user just opened. The day it does post one,
/// Android 13+ requires a runtime permission and this default is re-argued,
/// not inherited (§5).
const bool defaultAnnouncementsEnabled = true;

/// Whether the app opens the announcement channel at all.
///
/// Persists to [SharedPreferences] and hydrates synchronously at startup, the
/// same pattern as `matchSoundEnabledProvider`.
final announcementsEnabledProvider =
    StateNotifierProvider<AnnouncementsEnabledNotifier, bool>((ref) {
  return AnnouncementsEnabledNotifier();
});

/// Manages the announcements preference with persistence.
class AnnouncementsEnabledNotifier extends StateNotifier<bool> {
  AnnouncementsEnabledNotifier() : super(defaultAnnouncementsEnabled);

  /// Load the saved preference. Call before runApp().
  ///
  /// A device whose preferences cannot be read gets the default, like every
  /// other setting here. Failing the other way would silence a channel the
  /// user never asked to silence, and do it invisibly.
  static Future<bool> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kAnnouncementsKey) ?? defaultAnnouncementsEnabled;
    } catch (e) {
      debugPrint('Announcements preference load failed: $e');
      return defaultAnnouncementsEnabled;
    }
  }

  /// Set the initial value synchronously (called at startup).
  void hydrate(bool enabled) => state = enabled;

  /// Update the preference and persist it.
  ///
  /// [state] moves first, on purpose: the listener that opens and closes the
  /// channel hangs off this provider, and the whole point of the switch is
  /// that it acts at the tap rather than after a write to disk completes
  /// (§5). A failed write costs the *next launch* its preference, which is a
  /// far smaller thing than a subscription that stays open while the switch
  /// reads off.
  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAnnouncementsKey, enabled);
    } catch (e) {
      debugPrint('Announcements preference save failed: $e');
    }
  }
}
