import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    test('ignores the pubkey parameter that used to be an alias', () {
      // Arrange — `pubkey` was a second spelling of `npub` that nothing ever
      // produced. This asserts the removal rather than merely dropping the
      // case that covered it: silently starting to accept it again is the
      // regression worth catching.
      final uri = Uri.parse('https://bjjscore.live/?pubkey=npub1fake');

      // Act + Assert — not a *broken* link either. It names nothing this app
      // answers for, which is the silent case, not the accusing one.
      expect(boardOf(uri), isNull);
      expect(readShareLink(uri, crypto), isA<NotAShareLink>());
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

    test('a URI with no host is never ours, pubkey or not', () {
      // `/?npub=x` and a scheme-less `bjjscore.live/?npub=x` both parse with an
      // empty host. Treating them as ours put a full-screen "that link is
      // broken" in front of somebody over a route they never followed.
      for (final raw in [
        '/?npub=nonsense',
        'bjjscore.live/?npub=nonsense',
        '/?npub=npub1fake',
        '/',
      ]) {
        expect(
          readShareLink(Uri.parse(raw), crypto),
          isA<NotAShareLink>(),
          reason: raw,
        );
      }
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

    testWidgets('does not tear a guarded screen away from the user',
        (tester) async {
      // A referee scoring a live match guards the control screen with a
      // PopScope. popUntil ignores that — it calls pop, which is unconditional
      // — so an incoming link used to remove the screen mid-fight with none of
      // the confirmation the guard exists to require.
      //
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
        builder: (_) => const PopScope(
          canPop: false,
          child: Scaffold(body: Text('a match in progress')),
        ),
      ));
      await tester.pumpAndSettle();

      // Act
      openShareLink(Uri.parse(liveBoardShareUrl('npub1fake')), crypto, ref);
      await tester.pumpAndSettle();

      // Assert — the board is selected, but the referee keeps their screen
      expect(find.text('a match in progress'), findsOneWidget);
      expect(ref.read(selectedTabProvider), AppTab.scoreboard);
      expect(ref.read(watchedPubkeyProvider), _watched);
    });

    testWidgets('a link for the board already open leaves the stack alone',
        (tester) async {
      // Re-shares in a group chat are how this happens, and closing the match
      // they had open to hand them back the same list reads as losing their
      // place.
      //
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
      await ref.read(watchedPubkeyProvider.notifier).watch(_watched);
      key.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('a match detail')),
      ));
      await tester.pumpAndSettle();

      // Act — the same board, again
      openShareLink(Uri.parse(liveBoardShareUrl('npub1fake')), crypto, ref);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('a match detail'), findsOneWidget);
    });

    testWidgets('a broken link clears the stack so its message is seen',
        (tester) async {
      // Combining the two changes creates a case neither PR had on its own: the
      // broken-link message lives on the scoreboard, under the root navigator,
      // so a detail route left on top would hide it. A warning nobody sees is
      // no better than no warning.
      //
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
      openShareLink(
        Uri.parse('https://bjjscore.live/?npub=nonsense'),
        crypto,
        ref,
      );
      await tester.pumpAndSettle();

      // Assert
      expect(ref.read(brokenShareLinkProvider), isTrue);
      expect(find.text('a match detail'), findsNothing);
      expect(find.text('the board'), findsOneWidget);
    });

    testWidgets('a broken link still will not tear away a guarded screen',
        (tester) async {
      // The referee outranks the warning: a match in progress is not
      // interrupted, even to say a link was bad.
      //
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
        builder: (_) => const PopScope(
          canPop: false,
          child: Scaffold(body: Text('a match in progress')),
        ),
      ));
      await tester.pumpAndSettle();

      // Act
      openShareLink(
        Uri.parse('https://bjjscore.live/?npub=nonsense'),
        crypto,
        ref,
      );
      await tester.pumpAndSettle();

      // Assert — the flag is set and waiting for them behind the match
      expect(ref.read(brokenShareLinkProvider), isTrue);
      expect(find.text('a match in progress'), findsOneWidget);
    });
  });

  group('readShareLink — match links', () {
    /// The match a link names, or null when it names none this app can read.
    String? matchOf(Uri uri) {
      final link = readShareLink(uri, crypto);
      return link is SharedMatch ? link.matchId : null;
    }

    test('reads the link matchShareUrl actually builds', () {
      // Arrange — the exact URL the sharer produces, so the two cannot drift
      final uri = Uri.parse(matchShareUrl('npub1fake', 'abcd'));

      // Act
      final link = readShareLink(uri, crypto);

      // Assert — both halves, because either alone names nothing
      expect(link, isA<SharedMatch>());
      expect((link as SharedMatch).pubkeyHex, _watched);
      expect(link.matchId, 'abcd');
    });

    test('accepts the spellings a chat client might hand back', () {
      // Arrange — validation is on the decoded value, trimmed and lowercased,
      // so all three of these are the same id
      for (final raw in ['abcd', '%61%62%63%64', 'abcd%20', 'ABCD']) {
        final uri =
            Uri.parse('https://bjjscore.live/?npub=npub1fake&match=$raw');

        // Act + Assert
        expect(matchOf(uri), 'abcd', reason: raw);
      }
    });

    test('a value that is not a match id breaks the link', () {
      // Arrange — the sender named something and it cannot be read. That is
      // not the same as naming nothing.
      for (final raw in ['abc', 'abcde', 'zzzz', 'ab-cd']) {
        final uri =
            Uri.parse('https://bjjscore.live/?npub=npub1fake&match=$raw');

        // Act + Assert
        expect(readShareLink(uri, crypto), isA<BrokenShareLink>(), reason: raw);
      }
    });

    test('an empty match is no match, and leaves a board link intact', () {
      // Arrange — `&match=` on its own should not accuse anybody of anything,
      // exactly as a bare `?npub=` does not
      final uri = Uri.parse('https://bjjscore.live/?npub=npub1fake&match=');

      // Act
      final link = readShareLink(uri, crypto);

      // Assert
      expect(link, isA<SharedBoard>());
      expect((link as SharedBoard).pubkeyHex, _watched);
    });

    test('a match with no organizer names nothing at all', () {
      // Arrange — a match id is unique only inside one author's events, so
      // there is nobody to subscribe to and nothing to show
      expect(
        readShareLink(Uri.parse('https://bjjscore.live/?match=abcd'), crypto),
        isA<BrokenShareLink>(),
      );
      expect(
        readShareLink(
            Uri.parse('https://bjjscore.live/?npub=&match=abcd'), crypto),
        isA<BrokenShareLink>(),
      );
    });

    test('an unreadable organizer breaks the link, match or no match', () {
      expect(
        readShareLink(
            Uri.parse('https://bjjscore.live/?npub=nonsense&match=abcd'),
            crypto),
        isA<BrokenShareLink>(),
      );
    });

    test('another host is still not ours, match or no match', () {
      expect(
        readShareLink(
            Uri.parse('https://evil.example/?npub=npub1fake&match=abcd'),
            crypto),
        isA<NotAShareLink>(),
      );
    });
  });

  group('openShareLink — match links', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

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

    testWidgets('asks for the match the link named', (tester) async {
      // Arrange
      final ref = await pumpRef(tester);

      // Act
      final handled = openShareLink(
          Uri.parse(matchShareUrl('npub1fake', 'abcd')), crypto, ref);
      await tester.pump();

      // Assert — the board is watched and the match is requested; resolving it
      // is the screen's job, not this one's
      expect(handled, isTrue);
      expect(ref.read(watchedPubkeyProvider), _watched);
      expect(ref.read(requestedMatchProvider), 'abcd');
      expect(ref.read(selectedTabProvider), AppTab.scoreboard);
    });

    testWidgets('has the request in place before the pubkey changes',
        (tester) async {
      // Arrange — switching the watched author rebuilds the feed, and anything
      // reacting to that asks whether a match was requested. Set second, it
      // would read the previous answer.
      late ProviderContainer container;
      late WidgetRef ref;
      await tester.pumpWidget(ProviderScope(
        child: Consumer(builder: (context, r, _) {
          ref = r;
          container = ProviderScope.containerOf(context);
          return const SizedBox();
        }),
      ));

      String? seenWhenPubkeyChanged;
      container.listen<String?>(
        watchedPubkeyProvider,
        (_, __) =>
            seenWhenPubkeyChanged = container.read(requestedMatchProvider),
      );

      // Act
      openShareLink(Uri.parse(matchShareUrl('npub1fake', 'abcd')), crypto, ref);
      await tester.pump();

      // Assert
      expect(seenWhenPubkeyChanged, 'abcd');
    });

    testWidgets('a board link afterwards asks for no match', (tester) async {
      // Arrange — a link naming only a board is not a request for whatever
      // match happened to be open before it
      final ref = await pumpRef(tester);
      openShareLink(Uri.parse(matchShareUrl('npub1fake', 'abcd')), crypto, ref);
      await tester.pump();
      expect(ref.read(requestedMatchProvider), 'abcd');

      // Act
      openShareLink(Uri.parse(liveBoardShareUrl('npub1fake')), crypto, ref);
      await tester.pump();

      // Assert
      expect(ref.read(requestedMatchProvider), isNull);
    });

    testWidgets('a broken link asks for no match either', (tester) async {
      // Arrange
      final ref = await pumpRef(tester);
      openShareLink(Uri.parse(matchShareUrl('npub1fake', 'abcd')), crypto, ref);
      await tester.pump();

      // Act
      openShareLink(
        Uri.parse('https://bjjscore.live/?npub=npub1fake&match=zzzz'),
        crypto,
        ref,
      );
      await tester.pump();

      // Assert — the message must not sit over a match still being requested
      expect(ref.read(brokenShareLinkProvider), isTrue);
      expect(ref.read(requestedMatchProvider), isNull);
    });
  });
}
