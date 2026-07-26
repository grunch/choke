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

  /// The hex a link names, or null for anything that is not a board link.
  String? boardOf(Uri uri) {
    final link = readShareLink(uri, crypto);
    return link is SharedBoard ? link.pubkeyHex : null;
  }

  group('readShareLink', () {
    test('reads the link Account actually shares', () {
      // Arrange — the exact URL liveBoardShareUrl builds, so the sharer and the
      // reader cannot drift apart without this failing
      final uri = Uri.parse(liveBoardShareUrl('npub1fake'));

      // Act + Assert
      expect(boardOf(uri), _watched);
    });

    test('reads a bare hex pubkey too', () {
      // Arrange
      final uri = Uri.parse('https://bjjscore.live/?npub=${'a' * 64}');

      // Act + Assert
      expect(boardOf(uri), 'a' * 64);
    });

    test('accepts the pubkey parameter the web board also accepts', () {
      // Arrange — choke-scoreboard takes either name, and one link is shared to
      // everyone
      final uri = Uri.parse('https://bjjscore.live/?pubkey=npub1fake');

      // Act + Assert
      expect(boardOf(uri), _watched);
    });

    test('ignores whitespace around a pasted key', () {
      // Arrange
      final uri = Uri.parse('https://bjjscore.live/?npub=%20npub1fake%20');

      // Act + Assert
      expect(boardOf(uri), _watched);
    });

    test('refuses a link belonging to somebody else', () {
      // Arrange — the OS hands over whatever was tapped, and another host's
      // link is not this app's to interpret
      final uri = Uri.parse('https://evil.example/?npub=npub1fake');

      // Act + Assert
      expect(boardOf(uri), isNull);
    });

    test('refuses a link that names no usable key', () {
      // Act + Assert
      expect(
        boardOf(Uri.parse('https://bjjscore.live/')),
        isNull,
      );
      expect(
        boardOf(Uri.parse('https://bjjscore.live/?npub=')),
        isNull,
      );
      expect(
        boardOf(Uri.parse('https://bjjscore.live/?npub=nonsense')),
        isNull,
      );
    });

    test('tells a broken key apart from no key at all', () {
      // The whole point of the three cases: one of these named a board and
      // failed, the others never named one.
      expect(
        readShareLink(
            Uri.parse('https://bjjscore.live/?npub=nonsense'), crypto),
        isA<BrokenShareLink>(),
      );
      expect(
        readShareLink(Uri.parse('https://bjjscore.live/'), crypto),
        isA<NotAShareLink>(),
      );
      expect(
        readShareLink(Uri.parse('https://bjjscore.live/?npub='), crypto),
        isA<NotAShareLink>(),
      );
      expect(
        readShareLink(Uri.parse('https://evil.example/?npub=nonsense'), crypto),
        isA<NotAShareLink>(),
        reason: 'another host is not ours to judge',
      );
      expect(
        readShareLink(Uri.parse('/'), crypto),
        isA<NotAShareLink>(),
        reason: 'the ordinary launch route',
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

    testWidgets('reports a link whose pubkey cannot be read', (tester) async {
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

      // Assert — the user followed a link for one board; leaving another one on
      // screen would be a substitution they cannot see
      expect(handled, isTrue);
      expect(ref.read(brokenShareLinkProvider), isTrue);
      expect(ref.read(selectedTabProvider), AppTab.scoreboard);

      // …and their own board is kept, not thrown away over somebody else's
      // broken link
      expect(ref.read(watchedPubkeyProvider), 'c' * 64);
    });

    testWidgets('a good link afterwards clears the broken state',
        (tester) async {
      // Arrange
      final ref = await pumpRef(tester);
      openShareLink(
        Uri.parse('https://bjjscore.live/?npub=nonsense'),
        crypto,
        ref,
      );
      await tester.pump();
      expect(ref.read(brokenShareLinkProvider), isTrue);

      // Act
      openShareLink(Uri.parse(liveBoardShareUrl('npub1fake')), crypto, ref);
      await tester.pump();

      // Assert
      expect(ref.read(brokenShareLinkProvider), isFalse);
      expect(ref.read(watchedPubkeyProvider), _watched);
    });

    testWidgets('an empty parameter is no link, not a broken one',
        (tester) async {
      // Arrange — `?npub=` on its own should not accuse anybody of anything
      final ref = await pumpRef(tester);

      // Act
      final handled = openShareLink(
        Uri.parse('https://bjjscore.live/?npub='),
        crypto,
        ref,
      );
      await tester.pump();

      // Assert
      expect(handled, isFalse);
      expect(ref.read(brokenShareLinkProvider), isFalse);
      expect(ref.read(selectedTabProvider), AppTab.home);
    });

    testWidgets('another host is not ours to complain about', (tester) async {
      // Arrange
      final ref = await pumpRef(tester);

      // Act
      final handled = openShareLink(
        Uri.parse('https://evil.example/?npub=nonsense'),
        crypto,
        ref,
      );
      await tester.pump();

      // Assert
      expect(handled, isFalse);
      expect(ref.read(brokenShareLinkProvider), isFalse);
    });

    testWidgets('ignores the plain launch route', (tester) async {
      // Arrange — what the engine reports when the app was not opened by a link
      final ref = await pumpRef(tester);

      // Act
      final handled = openShareLink(Uri.parse('/'), crypto, ref);
      await tester.pump();

      // Assert
      expect(handled, isFalse);
      expect(ref.read(brokenShareLinkProvider), isFalse,
          reason: 'opening the app normally must not report a broken link');
      expect(ref.read(selectedTabProvider), AppTab.home);
    });
  });

  group('openShareLink logging', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('never writes the rejected link or its values to the log',
        (tester) async {
      // Arrange — somebody pastes a private key into a share link. The parser
      // rejects it, and the log must not become the place it leaks.
      const nsec = 'nsec1averysecretvaluethatmustnotbelogged';
      late WidgetRef ref;
      await tester.pumpWidget(ProviderScope(
        child: Consumer(builder: (context, r, _) {
          ref = r;
          return const SizedBox();
        }),
      ));

      final logged = <String>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logged.add(message);
      };

      // Act — restored inside the body, not in a tearDown: the framework
      // asserts its debug variables are untouched before tearDowns run.
      final bool handled;
      try {
        handled = openShareLink(
          Uri.parse('https://bjjscore.live/?npub=$nsec'),
          crypto,
          ref,
        );
      } finally {
        debugPrint = previous;
      }

      // Assert — a pubkey that cannot be read is now reported rather than
      // swallowed, but what it contained still must not reach the log
      expect(handled, isTrue);
      expect(ref.read(brokenShareLinkProvider), isTrue);
      expect(logged, isNotEmpty, reason: 'it should say something');
      expect(logged.join('\n'), isNot(contains(nsec)));
      expect(logged.join('\n'), isNot(contains('nsec1')));
    });
  });
}
