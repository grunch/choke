import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the device screen on while a match is on it.
///
/// A phone that locks itself after 30 seconds is a real problem around a mat: a
/// minute can pass in a fight with nothing to score and nobody touching the
/// phone — the referee waiting to award the takedown, a spectator watching a
/// board. Same idea as a video player holding the screen while it plays.
///
/// Like the match cues, this is a courtesy and never a dependency: a device
/// that refuses the request must still work normally, so every failure is
/// logged and dropped rather than thrown at the caller.
///
/// Holds are **leases**, not a shared switch. Two screens can overlap during a
/// route transition — Flutter disposes a popped route only after its exit
/// animation, so the arriving screen's `initState` runs before the departing
/// screen's `dispose` — and with a single boolean the departing release lands
/// on top of the arriving hold and cancels it. Each screen takes its own lease
/// instead, and the platform flag drops only when the last lease lets go.
abstract class ScreenWakelock {
  /// A claim of this caller's own. Vote through it, release it on the way out.
  ScreenWakelockLease lease();
}

/// One participant's claim on the screen.
abstract class ScreenWakelockLease {
  /// This lease's vote. The screen is held while **any** lease votes true.
  ///
  /// Idempotent, and cheap to repeat: voting what is already voted does
  /// nothing, so callers may vote on every rebuild or tick without counting
  /// them. Repeating is in fact the only way a request the platform dropped
  /// ever gets made again.
  ///
  /// The returned future completes when there is no longer work in flight,
  /// which is not a promise the vote was applied — see the drain. Callers that
  /// need to know should read the platform, not await this.
  Future<void> keepAwake(bool on);

  /// Withdraw for good. After this the lease is dead and further votes do
  /// nothing — a disposed screen must not be able to change anything.
  Future<void> release();
}

/// A [ScreenWakelock] that does nothing.
///
/// The default wherever a real one cannot be reached — tests above all, which
/// have no platform channels to answer the request.
class NoopScreenWakelock implements ScreenWakelock {
  const NoopScreenWakelock();

  @override
  ScreenWakelockLease lease() => const _NoopLease();
}

class _NoopLease implements ScreenWakelockLease {
  const _NoopLease();

  @override
  Future<void> keepAwake(bool on) async {}

  @override
  Future<void> release() async {}
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
/// awake while the app is in the background, so a hold left behind cannot
/// flatten a pocketed phone. It is still released explicitly, because a match
/// that has ended should let the phone sleep on the scorer's table.
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

  /// The leases currently voting to hold the screen.
  ///
  /// What the platform is asked for is derived — held while this is non-empty —
  /// so a stale release from a dying screen subtracts only its own vote and can
  /// never cancel a hold some other screen still has.
  final Set<_PlatformLease> _holding = {};

  /// What the platform has actually accepted. Only ever moved *after* a
  /// successful call, so a request that failed or timed out leaves this
  /// disagreeing with what is wanted — which is what makes the next vote retry.
  bool _held = false;

  bool _applying = false;

  @override
  ScreenWakelockLease lease() => _PlatformLease(this);

  bool get _wanted => _holding.isNotEmpty;

  Future<void> _vote(_PlatformLease lease, bool on) {
    if (on) {
      _holding.add(lease);
    } else {
      _holding.remove(lease);
    }
    return _drain();
  }

  /// Move the platform to what is wanted, one call at a time.
  ///
  /// Votes that arrive mid-flight do not queue up behind this: they change the
  /// lease set and return, and the loop below reads the derived state again
  /// when the call in flight comes back. That keeps a caller voting once a
  /// second from stacking a second of work per second onto a platform that is
  /// answering slowly, while never losing the state that was asked for last.
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
          // changed its mind within the same loop. The next vote tries again,
          // and while a match is on a screen one arrives every second.
          return;
        }
      }
    } finally {
      _applying = false;
    }
  }
}

class _PlatformLease implements ScreenWakelockLease {
  _PlatformLease(this._owner);

  final PlatformScreenWakelock _owner;
  bool _released = false;

  @override
  Future<void> keepAwake(bool on) {
    // A dead lease stays dead: dispose is allowed to race a late tick, and the
    // tick must not resurrect the claim of a screen that is gone.
    if (_released) return Future.value();
    return _owner._vote(this, on);
  }

  @override
  Future<void> release() {
    if (_released) return Future.value();
    _released = true;
    return _owner._vote(this, false);
  }
}

/// The app-wide screen wakelock.
///
/// One service holding all the leases, because the platform flag is one flag:
/// scoping this per screen would give each screen its own idea of what the
/// platform was told, and the flag would follow whichever spoke last.
final screenWakelockProvider = Provider<ScreenWakelock>((ref) {
  return PlatformScreenWakelock();
});
