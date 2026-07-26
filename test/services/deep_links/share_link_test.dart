import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/account/account_screen.dart';
import 'package:choke/features/scoreboard/providers/scoreboard_providers.dart';
import 'package:choke/services/deep_links/share_link.dart';
import 'package:choke/shared/providers/navigation_provider.dart';

import '../../support/nostr_fakes.dart';

const _watched =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  final crypto = FakeNostrCrypto();

  group('pubkeyFromShareLink', () {
    test('reads the link Account actually shares', () {
      // Arrange — the exact URL liveBoardShareUrl builds, so the sharer and the
      // reader cannot drift apart without this failing
      final uri = Uri.parse(liveBoardShareUrl('npub1fake'));

      // Act + Assert
      expect(pubkeyFromShareLink(uri, crypto), _watched);
    });

    test('reads a bare hex pubkey too', () {
      // Arrange
      final uri = Uri.parse('https://bjjscore.live/?npub=${'a' * 64}');

      // Act + Assert
      expect(pubkeyFromShareLink(uri, crypto), 'a' * 64);
    });

    test('accepts the pubkey parameter the web board also accepts', () {
      // Arrange — choke-scoreboard takes either name, and one link is shared to
      // everyone
      final uri = Uri.parse('https://bjjscore.live/?pubkey=npub1fake');

      // Act + Assert
      expect(pubkeyFromShareLink(uri, crypto), _watched);
    });

    test('ignores whitespace around a pasted key', () {
      // Arrange
      final uri = Uri.parse('https://bjjscore.live/?npub=%20npub1fake%20');

      // Act + Assert
      expect(pubkeyFromShareLink(uri, crypto), _watched);
    });

    test('refuses a link belonging to somebody else', () {
      // Arrange — the OS hands over whatever was tapped, and another host's
      // link is not this app's to interpret
      final uri = Uri.parse('https://evil.example/?npub=npub1fake');

      // Act + Assert
      expect(pubkeyFromShareLink(uri, crypto), isNull);
    });

    test('refuses a link that names no usable key', () {
      // Act + Assert
      expect(
        pubkeyFromShareLink(Uri.parse('https://bjjscore.live/'), crypto),
        isNull,
      );
      expect(
        pubkeyFromShareLink(Uri.parse('https://bjjscore.live/?npub='), crypto),
        isNull,
      );
      expect(
        pubkeyFromShareLink(
            Uri.parse('https://bjjscore.live/?npub=nonsense'), crypto),
        isNull,
      );
    });
  });

  group('openShareLink', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    /// Pump a widget that hands back its ref, so a link can be opened with the
    /// same kind of ref the app uses.
    Future<WidgetRef> pumpRef(WidgetTester tester) async {
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        child: Consumer(builder: (context, ref, _) {
          captured = ref;
          return const SizedBox();
        }),
      ));
      return captured;
    }

    testWidgets('watches the shared pubkey and shows the scoreboard',
        (tester) async {
      // Arrange
      final ref = await pumpRef(tester);
      expect(ref.read(selectedTabProvider), AppTab.home);

      // Act
      final handled = openShareLink(
        Uri.parse(liveBoardShareUrl('npub1fake')),
        crypto,
        ref,
      );
      await tester.pump();

      // Assert
      expect(handled, isTrue);
      expect(ref.read(watchedPubkeyProvider), _watched);
      expect(ref.read(selectedTabProvider), AppTab.scoreboard);
    });

    testWidgets('leaves everything alone for a link it does not understand',
        (tester) async {
      // Arrange — someone is already watching a board
      final ref = await pumpRef(tester);
      await ref.read(watchedPubkeyProvider.notifier).watch('c' * 64);

      // Act
      final handled = openShareLink(
        Uri.parse('https://bjjscore.live/?npub=nonsense'),
        crypto,
        ref,
      );
      await tester.pump();

      // Assert — forgetting the board they were watching, to show them an empty
      // one, would be worse than ignoring a link that made no sense
      expect(handled, isFalse);
      expect(ref.read(watchedPubkeyProvider), 'c' * 64);
      expect(ref.read(selectedTabProvider), AppTab.home);
    });

    testWidgets('ignores the plain launch route', (tester) async {
      // Arrange — what the engine reports when the app was not opened by a link
      final ref = await pumpRef(tester);

      // Act
      final handled = openShareLink(Uri.parse('/'), crypto, ref);
      await tester.pump();

      // Assert
      expect(handled, isFalse);
      expect(ref.read(selectedTabProvider), AppTab.home);
    });
  });
}
