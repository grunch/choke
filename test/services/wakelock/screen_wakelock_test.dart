import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:choke/services/wakelock/screen_wakelock.dart';

/// Records every request that actually reached the platform.
class _RecordingToggle {
  final List<bool> calls = [];

  /// Set to make the platform refuse, the way a plugin that has no foreground
  /// activity does.
  Object? error;

  /// Set to make the platform never answer, which is what a method channel with
  /// nothing on the far end does — it does not fail, it simply never replies.
  bool hang = false;

  /// Completes when [calls] has reached [count], so a test can wait for a
  /// request to arrive without waiting on one that never comes back.
  Future<void> untilCalled(int count) async {
    while (calls.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> call({required bool enable}) {
    calls.add(enable);
    if (hang) return Completer<void>().future;
    if (error != null) return Future.error(error!);
    return Future.value();
  }
}

void main() {
  group('NoopScreenWakelock', () {
    test('hands out leases that accept everything and do nothing', () {
      const wakelock = NoopScreenWakelock();
      final lease = wakelock.lease();

      expect(
        Future.wait([
          lease.keepAwake(true),
          lease.keepAwake(false),
          lease.release(),
        ]),
        completes,
      );
    });
  });

  group('PlatformScreenWakelock', () {
    test('asks the platform to hold the screen on', () async {
      // Arrange
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      final lease = wakelock.lease();

      // Act
      await lease.keepAwake(true);

      // Assert
      expect(toggle.calls, [true]);
    });

    test('releases the screen again', () async {
      // Arrange
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      final lease = wakelock.lease();
      await lease.keepAwake(true);

      // Act
      await lease.keepAwake(false);

      // Assert
      expect(toggle.calls, [true, false]);
    });

    test('does not repeat a request the platform is already honouring',
        () async {
      // Arrange
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      final lease = wakelock.lease();

      // Act: the match screen rebuilds far more often than the match changes
      await lease.keepAwake(true);
      await lease.keepAwake(true);
      await lease.keepAwake(true);

      // Assert
      expect(toggle.calls, [true]);
    });

    test('starts out released, so nothing is asked for a screen left alone',
        () async {
      // Arrange
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      final lease = wakelock.lease();

      // Act
      await lease.keepAwake(false);

      // Assert
      expect(toggle.calls, isEmpty);
    });

    test('a platform that refuses is not fatal', () async {
      // Arrange
      final toggle = _RecordingToggle()..error = Exception('no plugin');
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      final lease = wakelock.lease();

      // Act + Assert: a device that cannot hold its screen on still referees
      await expectLater(lease.keepAwake(true), completes);
    });

    test('retries after a refusal instead of believing it worked', () async {
      // Arrange
      final toggle = _RecordingToggle()..error = Exception('no plugin');
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      final lease = wakelock.lease();
      await lease.keepAwake(true);
      toggle.error = null;

      // Act: the next rebuild asks again
      await lease.keepAwake(true);

      // Assert
      expect(toggle.calls, [true, true]);
    });

    test('gives up on a platform that never answers', () async {
      // Arrange: a method channel with nothing on the far end never replies.
      final toggle = _RecordingToggle()..hang = true;
      final wakelock = PlatformScreenWakelock(
        toggle: toggle.call,
        timeout: const Duration(milliseconds: 20),
      );
      final lease = wakelock.lease();

      // Act + Assert: the request comes back rather than hanging forever
      await expectLater(lease.keepAwake(true), completes);
    });

    test('a request that never answered does not wedge the next one', () async {
      // Arrange: the first attempt hangs and times out
      final toggle = _RecordingToggle()..hang = true;
      final wakelock = PlatformScreenWakelock(
        toggle: toggle.call,
        timeout: const Duration(milliseconds: 20),
      );
      final lease = wakelock.lease();
      await lease.keepAwake(true);
      expect(toggle.calls, [true], reason: 'the first attempt was made');
      toggle.hang = false;

      // Act: ask again, the way the running clock does every second
      await lease.keepAwake(true);

      // Assert: the screen is held after all. Serialising requests behind the
      // dead one would have left the wakelock useless for the whole session.
      expect(toggle.calls, [true, true]);
    });

    test('does not stack up work while the platform is answering slowly',
        () async {
      // Arrange: one call in flight, going nowhere for now
      final toggle = _RecordingToggle()..hang = true;
      final wakelock = PlatformScreenWakelock(
        toggle: toggle.call,
        timeout: const Duration(milliseconds: 20),
      );
      final lease = wakelock.lease();
      lease.keepAwake(true);
      await toggle.untilCalled(1);

      // Act: a running clock asks 30 more times while that one is still out
      for (var i = 0; i < 30; i++) {
        lease.keepAwake(true);
      }

      // Assert: 30 more requests did not become 30 more platform calls queued
      // behind a call that has not come back.
      expect(toggle.calls, hasLength(1));
    });

    test('applies rapid opposite requests in the order they were made',
        () async {
      // Arrange: a screen opened and closed inside one frame
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      final lease = wakelock.lease();

      // Act: neither is awaited before the next is made
      final held = lease.keepAwake(true);
      final released = lease.keepAwake(false);
      await Future.wait([held, released]);

      // Assert: the screen is left free to sleep, not pinned on by a race
      expect(toggle.calls, [true, false]);
    });

    test("a dying screen's release cannot cancel another screen's hold", () async {
      // The route-transition overlap: Flutter disposes a popped route after its
      // exit animation, so the arriving screen holds before the departing one
      // releases. With a shared boolean the stale release won — and if the
      // arriving screen never re-asserted (a waiting control screen does not),
      // it stayed released indefinitely.
      //
      // Arrange
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      final departing = wakelock.lease();
      final arriving = wakelock.lease();
      await departing.keepAwake(true);
      await arriving.keepAwake(true);

      // Act — the popped screen's dispose fires last
      await departing.release();

      // Assert — the platform was never asked to let go
      expect(toggle.calls, [true]);
    });

    test('the screen is released when the last lease lets go', () async {
      // Arrange
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      final a = wakelock.lease();
      final b = wakelock.lease();
      await a.keepAwake(true);
      await b.keepAwake(true);

      // Act
      await a.release();
      await b.release();

      // Assert
      expect(toggle.calls, [true, false]);
    });

    test('a released lease is dead: late votes change nothing', () async {
      // dispose is allowed to race a late tick, and the tick must not
      // resurrect the claim of a screen that is gone.
      //
      // Arrange
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      final gone = wakelock.lease();
      await gone.keepAwake(true);
      await gone.release();
      expect(toggle.calls, [true, false]);

      // Act
      await gone.keepAwake(true);

      // Assert
      expect(toggle.calls, [true, false]);
    });

    test('one lease voting twice is one hold, not two', () async {
      // Re-voting every tick is the retry mechanism; it must not need a
      // matching number of releases.
      //
      // Arrange
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      final lease = wakelock.lease();
      await lease.keepAwake(true);
      await lease.keepAwake(true);

      // Act
      await lease.keepAwake(false);

      // Assert
      expect(toggle.calls, [true, false]);
    });
  });
}
