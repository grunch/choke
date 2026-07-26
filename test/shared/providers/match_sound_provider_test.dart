import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/shared/providers/match_sound_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The notifier persists through SharedPreferences, a plugin that does not
    // exist on the test host unless it is mocked.
    SharedPreferences.setMockInitialValues({});
  });

  group('loadSaved', () {
    test('the cues are on for anyone who has never touched the setting',
        () async {
      // Arrange — empty preferences, set in setUp

      // Act
      final enabled = await MatchSoundEnabledNotifier.loadSaved();

      // Assert — defaulting to silence would hide the feature from everyone
      // who never opens Settings.
      expect(enabled, isTrue);
      expect(defaultMatchSoundEnabled, isTrue);
    });

    test('a stored preference is honoured', () async {
      // Arrange
      SharedPreferences.setMockInitialValues(
        {'choke:match-sound-enabled': false},
      );

      // Act
      final enabled = await MatchSoundEnabledNotifier.loadSaved();

      // Assert
      expect(enabled, isFalse);
    });
  });

  group('setEnabled', () {
    test('turning the sound off survives a restart', () async {
      // Arrange
      final notifier = MatchSoundEnabledNotifier();
      addTearDown(notifier.dispose);

      // Act
      await notifier.setEnabled(false);

      // Assert — the state changed, and so did what the next launch will read
      expect(notifier.state, isFalse);
      expect(await MatchSoundEnabledNotifier.loadSaved(), isFalse);
    });

    test('turning it back on persists too', () async {
      // Arrange
      SharedPreferences.setMockInitialValues(
        {'choke:match-sound-enabled': false},
      );
      final notifier = MatchSoundEnabledNotifier()..hydrate(false);
      addTearDown(notifier.dispose);

      // Act
      await notifier.setEnabled(true);

      // Assert
      expect(notifier.state, isTrue);
      expect(await MatchSoundEnabledNotifier.loadSaved(), isTrue);
    });
  });

  group('hydrate', () {
    test('applies the saved value before the first frame', () {
      // Arrange
      final notifier = MatchSoundEnabledNotifier();
      addTearDown(notifier.dispose);
      expect(notifier.state, isTrue);

      // Act
      notifier.hydrate(false);

      // Assert — no flash of an audible clock on a device set to silent
      expect(notifier.state, isFalse);
    });
  });
}
