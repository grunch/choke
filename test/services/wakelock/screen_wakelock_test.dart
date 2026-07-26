import 'package:flutter_test/flutter_test.dart';
import 'package:choke/services/wakelock/screen_wakelock.dart';

/// Records every request that actually reached the platform.
class _RecordingToggle {
  final List<bool> calls = [];

  /// Set to make the platform refuse, the way an unregistered plugin does.
  Object? error;

  Future<void> call({required bool enable}) async {
    calls.add(enable);
    if (error != null) throw error!;
  }
}

void main() {
  group('NoopScreenWakelock', () {
    test('accepts both requests without reaching for a platform', () {
      const wakelock = NoopScreenWakelock();

      expect(
        Future.wait([wakelock.keepAwake(true), wakelock.keepAwake(false)]),
        completes,
      );
    });
  });

  group('PlatformScreenWakelock', () {
    test('asks the platform to hold the screen on', () async {
      // Arrange
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);

      // Act
      await wakelock.keepAwake(true);

      // Assert
      expect(toggle.calls, [true]);
    });

    test('releases the screen again', () async {
      // Arrange
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      await wakelock.keepAwake(true);

      // Act
      await wakelock.keepAwake(false);

      // Assert
      expect(toggle.calls, [true, false]);
    });

    test('does not repeat a request the platform is already honouring',
        () async {
      // Arrange
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);

      // Act: the match screen rebuilds far more often than the match changes
      await wakelock.keepAwake(true);
      await wakelock.keepAwake(true);
      await wakelock.keepAwake(true);

      // Assert
      expect(toggle.calls, [true]);
    });

    test('starts out released, so nothing is asked for a screen left alone',
        () async {
      // Arrange
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);

      // Act
      await wakelock.keepAwake(false);

      // Assert
      expect(toggle.calls, isEmpty);
    });

    test('a platform that refuses is not fatal', () async {
      // Arrange
      final toggle = _RecordingToggle()..error = Exception('no plugin');
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);

      // Act + Assert: a device that cannot hold its screen on still referees
      await expectLater(wakelock.keepAwake(true), completes);
    });

    test('retries after a refusal instead of believing it worked', () async {
      // Arrange
      final toggle = _RecordingToggle()..error = Exception('no plugin');
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);
      await wakelock.keepAwake(true);
      toggle.error = null;

      // Act: the next rebuild asks again
      await wakelock.keepAwake(true);

      // Assert
      expect(toggle.calls, [true, true]);
    });

    test('applies rapid opposite requests in the order they were made',
        () async {
      // Arrange: a screen opened and closed inside one frame
      final toggle = _RecordingToggle();
      final wakelock = PlatformScreenWakelock(toggle: toggle.call);

      // Act: neither is awaited before the next is made
      final held = wakelock.keepAwake(true);
      final released = wakelock.keepAwake(false);
      await Future.wait([held, released]);

      // Assert: the screen is left free to sleep, not pinned on by a race
      expect(toggle.calls, [true, false]);
    });
  });
}
