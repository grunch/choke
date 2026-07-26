import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the device screen on while the referee is running a match.
///
/// A phone that locks itself after 30 seconds is a real problem on the mat: a
/// minute can pass in a fight with nothing to score, and the referee should not
/// have to unlock a phone to award the takedown that ends it. Same idea as a
/// video player holding the screen on while it plays.
///
/// Like the match cues, this is a courtesy and never a dependency: a device
/// that refuses the request must still referee a match normally, so every
/// failure is logged and dropped rather than thrown at the caller.
abstract class ScreenWakelock {
  /// Hold the screen on ([on] true) or let it go back to sleeping normally.
  ///
  /// Idempotent: asking for a state the platform is already in does nothing, so
  /// callers may ask on every rebuild without counting them.
  Future<void> keepAwake(bool on);
}

/// A [ScreenWakelock] that does nothing.
///
/// The default wherever a real one cannot be reached — tests above all, which
/// have no platform channels to answer the request.
class NoopScreenWakelock implements ScreenWakelock {
  const NoopScreenWakelock();

  @override
  Future<void> keepAwake(bool on) async {}
}

/// What [PlatformScreenWakelock] calls to actually move the platform flag.
///
/// Matches `WakelockPlus.toggle` so the plugin can be handed over directly, and
/// swapped for something a test can watch.
typedef WakelockToggle = Future<void> Function({required bool enable});

/// Holds the screen on through `wakelock_plus`.
///
/// On Android that is `FLAG_KEEP_SCREEN_ON` on the activity window — no
/// permission involved — and on iOS the idle timer. Neither can hold a phone
/// awake while the app is in the background, so a hold left behind cannot flatten
/// a pocketed phone. It is still released explicitly, because a match that has
/// ended should let the phone sleep on the scorer's table.
class PlatformScreenWakelock implements ScreenWakelock {
  PlatformScreenWakelock({WakelockToggle? toggle})
      : _toggle = toggle ?? WakelockPlus.toggle;

  final WakelockToggle _toggle;

  /// Requests are serialised through this chain so the platform ends up in the
  /// state of the *last* one. Without it, a screen opened and closed inside the
  /// same frame could apply its two requests out of order and leave the screen
  /// pinned on for the rest of the session.
  Future<void> _queue = Future.value();

  /// What the platform has been told, as far as we know. Starts false, matching
  /// a device that has been asked for nothing.
  bool _held = false;

  @override
  Future<void> keepAwake(bool on) => _queue = _queue.then((_) => _apply(on));

  Future<void> _apply(bool on) async {
    if (_held == on) return;

    // Claim the new state before awaiting, so a request arriving while this one
    // is still in flight does not fire a duplicate.
    _held = on;
    try {
      await _toggle(enable: on);
    } catch (e) {
      // Put it back: the platform is not in the state just claimed, and the
      // next request — the next rebuild, or leaving the screen — should try
      // again rather than assume this one landed.
      _held = !on;
      debugPrint(
        'ScreenWakelock: could not ${on ? 'hold' : 'release'} the screen: $e',
      );
    }
  }
}

/// The app-wide screen wakelock.
///
/// Deliberately not scoped to a single match: the hold belongs to whichever
/// screen currently wants it, and a single owner of the platform flag is what
/// keeps one screen's release from cancelling another's hold.
final screenWakelockProvider = Provider<ScreenWakelock>((ref) {
  return PlatformScreenWakelock();
});
