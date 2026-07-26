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

      // Assert
      expect(handled, isFalse);
      expect(logged, isNotEmpty, reason: 'it should say something');
      expect(logged.join('\n'), isNot(contains(nsec)));
      expect(logged.join('\n'), isNot(contains('nsec1')));
    });
  });

  group('openShareLink navigation', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('clears a pushed route so the board is what ends up visible',
        (tester) async {
      // Arrange — the app is open on a detail screen, as it is whenever
      // somebody is watching a match and a link arrives.
      late WidgetRef ref;
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(ProviderScope(
        overrides: [navigatorKeyProvider.overrideWithValue(key)],
        child: MaterialApp(
          navigatorKey: key,
          home: Consumer(builder: (context, r, _) {
            ref = r;
            return const Scaffold(body: Text('the board'));
          }),
        ),
      ));

      key.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('a match detail')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('a match detail'), findsOneWidget);

      // Act
      final handled =
          openShareLink(Uri.parse(liveBoardShareUrl('npub1fake')), crypto, ref);
      await tester.pumpAndSettle();

      // Assert — switching the tab alone would have moved the screen underneath
      // this route, leaving the user staring at the match they were already on
      expect(handled, isTrue);
      expect(find.text('a match detail'), findsNothing);
      expect(find.text('the board'), findsOneWidget);
      expect(ref.read(selectedTabProvider), AppTab.scoreboard);
    });

    testWidgets('a cold start pops nothing, having pushed nothing',
        (tester) async {
      // Arrange — no stack yet, which is the launch case
      late WidgetRef ref;
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(ProviderScope(
        overrides: [navigatorKeyProvider.overrideWithValue(key)],
        child: MaterialApp(
          navigatorKey: key,
          home: Consumer(builder: (context, r, _) {
            ref = r;
            return const Scaffold(body: Text('the board'));
          }),
        ),
      ));

      // Act
      final handled =
          openShareLink(Uri.parse(liveBoardShareUrl('npub1fake')), crypto, ref);
      await tester.pumpAndSettle();

      // Assert
      expect(handled, isTrue);
      expect(find.text('the board'), findsOneWidget);
      expect(ref.read(watchedPubkeyProvider), _watched);
    });

    testWidgets('a link that is not ours leaves the stack alone',
        (tester) async {
      // Arrange
      late WidgetRef ref;
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(ProviderScope(
        overrides: [navigatorKeyProvider.overrideWithValue(key)],
        child: MaterialApp(
          navigatorKey: key,
          home: Consumer(builder: (context, r, _) {
            ref = r;
            return const Scaffold(body: Text('the board'));
          }),
        ),
      ));
      key.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('a match detail')),
      ));
      await tester.pumpAndSettle();

      // Act
      final handled = openShareLink(
          Uri.parse('https://evil.example/?npub=npub1fake'), crypto, ref);
      await tester.pumpAndSettle();

      // Assert — an unrelated link must not throw the user out of what they
      // were doing
      expect(handled, isFalse);
      expect(find.text('a match detail'), findsOneWidget);
    });
  });
}
