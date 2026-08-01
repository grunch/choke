import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/features/scoreboard/providers/scoreboard_providers.dart';
import 'package:choke/features/scoreboard/scoreboard_match_screen.dart';
import 'package:choke/features/scoreboard/scoreboard_screen.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'package:choke/services/deep_links/share_link.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/crypto/nostr_crypto.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/services/wakelock/screen_wakelock.dart';
import 'package:choke/shared/providers/navigation_provider.dart';
import 'package:choke/shared/theme/app_theme.dart';

import '../../support/nostr_fakes.dart';

/// The relays are not part of what these tests are about; the feed just needs
/// something that answers.
class _OfflineNostrService extends NostrService {
  _OfflineNostrService()
      : super(KeyManager(crypto: FakeNostrCrypto()),
            crypto: FakeNostrCrypto(), backend: FakeRelayBackend());

  /// Empty, not a controller nobody writes to: events reach these tests
  /// through the [_feed] override, and a live controller here would only be
  /// one more thing left open at the end of every test.
  @override
  Stream<NostrEvent> get eventStream => const Stream.empty();

  @override
  void subscribeToAuthor(String authorPubkey, {String? subscriptionId}) {}

  @override
  void unsubscribe(String subscriptionId) {}

  @override
  List<NostrEvent> cachedEventsOf(int kind, String pubkey) => const [];
}

/// What `FakeNostrCrypto` decodes `npub1fake` to.
const _watched =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

const _matchId = 'abcd';

/// The link a recipient taps, naming one match on the watched board.
final _link = Uri.parse(
  'https://$kShareLinkHost/?npub=npub1fake&$kShareMatchParam=$_matchId',
);

/// What the feed is holding right now.
///
/// A [StateProvider] rather than a fixed override, because half of these tests
/// are about the moment an event *arrives* — the whole point of Pending is that
/// the answer comes later than the question.
final _feed = StateProvider<List<Match>>((ref) => const []);

Match _match() {
  return Match(
    id: _matchId,
    status: MatchStatus.inProgress,
    startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    duration: 300,
    f1Name: 'Buchecha',
    f2Name: 'Roger Gracie',
    f1Color: '#1BA34E',
    f2Color: '#F5B800',
  );
}

/// The scoreboard, wired the way the app wires it: one navigator, reachable
/// through [navigatorKeyProvider], so `openShareLink` can clear the stack.
Widget _wrap(void Function(WidgetRef) captureRef) {
  return ProviderScope(
    overrides: [
      nostrCryptoProvider.overrideWithValue(FakeNostrCrypto()),
      nostrServiceProvider.overrideWithValue(_OfflineNostrService()),
      // The real one talks to a method channel nothing answers in a test, and
      // its timeout would outlive the test as a pending timer.
      screenWakelockProvider.overrideWithValue(const NoopScreenWakelock()),
      scoreboardMatchesProvider.overrideWith((ref) => ref.watch(_feed)),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        captureRef(ref);
        return MaterialApp(
          navigatorKey: ref.watch(navigatorKeyProvider),
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ScoreboardScreen(),
        );
      },
    ),
  );
}

void main() {
  late WidgetRef ref;
  late AppLocalizations l10n;

  setUp(() async {
    // Already watching the organizer the link names, which is the ordinary
    // case: the interesting waiting is on the match, not on the board.
    SharedPreferences.setMockInitialValues(
      {'choke:scoreboard-pubkey': _watched},
    );
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// The board on screen, landscape, with the saved pubkey restored.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 740);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap((r) => ref = r));
    await tester.pump(); // the saved pubkey is restored asynchronously
    await tester.pump();
  }

  /// Long enough for a pushed route's transition to finish, and no longer.
  ///
  /// Not `pumpAndSettle`: the board's status dot blinks for as long as a match
  /// is running, so a settled frame never comes.
  Future<void> settleRoute(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openLink(WidgetTester tester) async {
    openShareLink(_link, ref.read(nostrCryptoProvider), ref);
    await settleRoute(tester);
  }

  group('a link that names one match', () {
    testWidgets('waits, rather than saying the match is not there',
        (tester) async {
      // Arrange — a cold link: the feed has answered nothing yet
      await pumpApp(tester);

      // Act
      await openLink(tester);

      // Assert — the promise of the link is still open, and says so
      expect(find.text(l10n.scoreboardMatchPendingTitle), findsOneWidget);
      expect(find.text(l10n.scoreboardMatchPendingBody), findsOneWidget);
      expect(find.text(l10n.scoreboardMatchUnresolvedTitle), findsNothing);
    });

    testWidgets('shows the board the moment the match arrives', (tester) async {
      // Arrange
      await pumpApp(tester);
      await openLink(tester);

      // Act — the relay answers
      ref.read(_feed.notifier).state = [_match()];
      await tester.pump();

      // Assert
      expect(find.text('BUCHECHA'), findsOneWidget);
      expect(find.text('ROGER GRACIE'), findsOneWidget);
      expect(find.text(l10n.scoreboardMatchPendingTitle), findsNothing);
    });

    testWidgets('says the match may have ended once the backstop expires',
        (tester) async {
      // Arrange
      await pumpApp(tester);
      await openLink(tester);

      // Act — the feed never answers
      await tester.pump(kMatchLinkBackstop + const Duration(seconds: 1));

      // Assert — and the copy carries why, not merely that
      expect(find.text(l10n.scoreboardMatchUnresolvedTitle), findsOneWidget);
      expect(find.text(l10n.scoreboardMatchUnresolvedBody), findsOneWidget);
      expect(find.text(l10n.scoreboardMatchPendingTitle), findsNothing);
    });

    testWidgets('is still pending one tick before the backstop',
        (tester) async {
      // Arrange
      await pumpApp(tester);
      await openLink(tester);

      // Act — a slow relay on venue wifi has not run out of time yet
      await tester.pump(kMatchLinkBackstop - const Duration(seconds: 1));

      // Assert
      expect(find.text(l10n.scoreboardMatchPendingTitle), findsOneWidget);
      expect(find.text(l10n.scoreboardMatchUnresolvedTitle), findsNothing);
    });

    testWidgets('lets a late arrival win, after Unresolved', (tester) async {
      // Arrange — the backstop has already run out
      await pumpApp(tester);
      await openLink(tester);
      await tester.pump(kMatchLinkBackstop + const Duration(seconds: 1));
      expect(find.text(l10n.scoreboardMatchUnresolvedTitle), findsOneWidget);

      // Act — the link was right and the network was slow
      ref.read(_feed.notifier).state = [_match()];
      await tester.pump();

      // Assert
      expect(find.text('BUCHECHA'), findsOneWidget);
      expect(find.text(l10n.scoreboardMatchUnresolvedTitle), findsNothing);
    });

    testWidgets('does nothing at all when the same link arrives again',
        (tester) async {
      // Arrange — the match is open, from the link, and resolved
      await pumpApp(tester);
      ref.read(_feed.notifier).state = [_match()];
      await openLink(tester);
      expect(find.text('BUCHECHA'), findsOneWidget);

      // Act — a re-share in the group chat
      await openLink(tester);

      // Assert — one board, not a second pushed on top of the first. A
      // MaterialPageRoute keeps the route under it in the tree, so a double
      // push would show up as two of everything.
      expect(find.byType(ScoreboardMatchScreen), findsOneWidget);
      expect(find.text('BUCHECHA'), findsOneWidget);
      expect(find.text(l10n.scoreboardMatchPendingTitle), findsNothing);
    });

    testWidgets('opens a different match on the board already watched',
        (tester) async {
      // Arrange — one match from the link, resolved
      await pumpApp(tester);
      ref.read(_feed.notifier).state = [_match()];
      await openLink(tester);

      // Act — a second link, same organizer, different fight
      openShareLink(
        Uri.parse(
          'https://$kShareLinkHost/?npub=npub1fake&$kShareMatchParam=beef',
        ),
        ref.read(nostrCryptoProvider),
        ref,
      );
      // Two: one for the board coming down, one for the next going up.
      await settleRoute(tester);
      await settleRoute(tester);

      // Assert — the board came down and the new request is waiting on the
      // feed, where a board link would have had nothing to do at all
      expect(find.text(l10n.scoreboardMatchPendingTitle), findsOneWidget);
      expect(find.text('BUCHECHA'), findsNothing);
    });
  });

  group('a match opened from the list', () {
    testWidgets('never waits', (tester) async {
      // Arrange — the card is on screen, so the match is already in hand
      await pumpApp(tester);
      ref.read(_feed.notifier).state = [_match()];
      await tester.pump();

      // Act
      await tester.tap(find.text('Buchecha'));
      await settleRoute(tester);

      // Assert — straight to the board, with no waiting state anywhere
      expect(find.text('ROGER GRACIE'), findsOneWidget);
      expect(find.text(l10n.scoreboardMatchPendingTitle), findsNothing);
      expect(find.text(l10n.scoreboardMatchUnresolvedTitle), findsNothing);
    });

    testWidgets('keeps the old dead end when the match ages out under it',
        (tester) async {
      // Arrange — a board left running until the match drops out of the feed
      await pumpApp(tester);
      ref.read(_feed.notifier).state = [_match()];
      await tester.pump();
      await tester.tap(find.text('Buchecha'));
      await settleRoute(tester);

      // Act
      ref.read(_feed.notifier).state = const [];
      await tester.pump();

      // Assert — this path never learned to wait, and must not start now
      expect(find.text(l10n.scoreboardEmptyTitle), findsWidgets);
      expect(find.text(l10n.scoreboardMatchPendingTitle), findsNothing);
    });
  });

  group('the shared 24-hour window', () {
    test('is 86400 seconds, the same number choke-scoreboard asserts', () {
      // The conformance obligation of the spec's §4: two languages and two
      // build systems make one shared constant impractical, so each repository
      // pins its own and a silent drift fails a build instead of splitting the
      // contract in half — a link that resolves in one reader and not the
      // other.
      expect(scoreboardMaxAgeSeconds, 86400);
    });
  });
}
