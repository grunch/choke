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
  /// Idempotent, and cheap to repeat: asking for a state the platform is already
  /// in does nothing, so callers may ask on every rebuild without counting them.
  /// Repeating is in fact the only way a request the platform dropped ever gets
  /// made again.
  ///
  /// The returned future completes when there is no longer work in flight, which
  /// is not a promise that [on] was applied — a request made while an earlier
  /// one is still out returns as soon as the state has been recorded. Callers
  /// that need to know should read the platform, not await this.
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
  PlatformScreenWakelock({WakelockToggle? toggle, Duration? timeout})
      : _toggle = toggle ?? WakelockPlus.toggle,
        _timeout = timeout ?? _defaultTimeout;

  /// A request the platform has not answered in this long is not going to be.
  ///
  /// It has to be bounded. The plugin talks over a method channel, and a channel
  /// with nothing on the far end — no registered plugin, no foreground engine —
  /// leaves the call pending forever rather than failing. Waiting on that
  /// forever is how the whole wakelock stops working after one bad call.
  static const _defaultTimeout = Duration(seconds: 5);

  final WakelockToggle _toggle;
  final Duration _timeout;

  /// The state the app wants. Overwritten by each request, so the newest one
  /// wins and older ones are simply superseded: only the latest state matters,
  /// and the ones behind it are already stale. Same reasoning as the outbox in
  /// `MatchControlNotifier`, for the same reason.
  bool _wanted = false;

  /// What the platform has actually accepted. Only ever moved *after* a
  /// successful call, so a request that failed or timed out leaves this
  /// disagreeing with [_wanted] — which is what makes the next request retry.
  bool _held = false;

  bool _applying = false;

  @override
  Future<void> keepAwake(bool on) {
    _wanted = on;
    return _drain();
  }

  /// Move the platform to [_wanted], one call at a time.
  ///
  /// Requests that arrive mid-flight do not queue up behind this: they update
  /// [_wanted] and return, and the loop below picks the new value up when the
  /// call in flight comes back. That keeps a caller asking once a second from
  /// stacking a second of work per second onto a platform that is answering
  /// slowly, while still never losing the state that was asked for last.
  Future<void> _drain() async {
    if (_applying) return;
    _applying = true;
    try {
      while (_wanted != _held) {
        final wanted = _wanted;
        try {
          await _toggle(enable: wanted).timeout(_timeout);
          _held = wanted;
        } catch (e) {
          debugPrint(
            'ScreenWakelock: could not '
            '${wanted ? 'hold' : 'release'} the screen: $e',
          );
          // Do not spin on a platform that just refused — it will not have
          // changed its mind within the same loop. The next request tries
          // again, and while a match is running one arrives every second.
          return;
        }
      }
    } finally {
      _applying = false;
    }
  }
}

/// The app-wide screen wakelock.
///
/// Deliberately not scoped to a single match: the hold belongs to whichever
/// screen wants it, and one owner of the platform flag is what keeps a release
/// from fighting a hold.
///
/// That is a precondition, not just a description. The state here is a single
/// pair of booleans, so exactly one widget may ask at a time — today that is
/// `MatchControlScreen`, the only screen with a reason to. A second owner would
/// break it in a way tests would not catch: two overlapping screens hand over
/// during a route transition, where the arriving one's `initState` runs before
/// the departing one's `dispose`, and the departing release would cancel a hold
/// that had just been taken. Whoever adds one needs reference-counted leases
/// here rather than a bool, so the flag drops only when the last owner lets go.
final screenWakelockProvider = Provider<ScreenWakelock>((ref) {
  return PlatformScreenWakelock();
});
