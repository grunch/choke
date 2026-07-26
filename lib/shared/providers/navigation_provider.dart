import 'package:flutter/widgets.dart';
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

/// The root navigator, so code outside the widget tree can act on the stack.
///
/// A shared link arriving while the app is open has to clear whatever is on top
/// before it selects a tab. Changing the tab alone moves the screen *underneath*
/// a pushed route, which the user never sees — and if the link named a different
/// organizer, the match detail sitting on top stops belonging to the watched
/// board and turns into its own "no longer available" page. The link promised a
/// board and delivered a dead end.
///
/// A key rather than a router because the app navigates with an IndexedStack and
/// imperative pushes; introducing routing to pop one route would be a far larger
/// change than the bug is worth.
final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(),
);
