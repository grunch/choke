import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sections in the bottom bar, in the order they appear there.
///
/// An enum rather than the bare index the nav bar used to keep, because the
/// index is now written from more than one place — a shared link opens the
/// scoreboard — and a `2` at a call site says nothing about which screen it is.
enum AppTab {
  home,
  scoreboard,
  account,
  settings;

  static AppTab fromIndex(int index) => AppTab.values[index];
}

/// Which section is showing.
///
/// Lifted out of the navigation widget's own state so that anything holding a
/// ref can move the user, which is what a shared board link does when the app
/// is already open. Deliberately not persisted: the app opens on Home, not on
/// wherever it happened to be left.
final selectedTabProvider = StateProvider<AppTab>((ref) => AppTab.home);
