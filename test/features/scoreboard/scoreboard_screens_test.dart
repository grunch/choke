import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/features/scoreboard/providers/scoreboard_providers.dart';
import 'package:choke/features/scoreboard/board_palette.dart';
import 'package:choke/features/scoreboard/scoreboard_match_screen.dart';
import 'package:choke/features/scoreboard/scoreboard_screen.dart';
import 'package:choke/services/deep_links/share_link.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/crypto/nostr_crypto.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/services/wakelock/screen_wakelock.dart';
import 'package:choke/shared/theme/app_theme.dart';
import 'package:choke/shared/widgets/status_filter_bar.dart';

import '../../support/nostr_fakes.dart';

/// The relays are not part of what these tests are about; the feed just needs
/// something that answers.
class _OfflineNostrService extends NostrService {
  _OfflineNostrService()
      : super(KeyManager(crypto: FakeNostrCrypto()),
            crypto: FakeNostrCrypto(), backend: FakeRelayBackend());

  @override
  void subscribeToAuthor(String authorPubkey, {String? subscriptionId}) {}
}

const _watched =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Match _match({
  MatchStatus status = MatchStatus.inProgress,
  MatchWinner? winner,
  MatchMethod? method,
  String? submission,
}) {
  return Match(
    id: 'abcd',
    status: status,
    startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    duration: 300,
    f1Name: 'Buchecha',
    f2Name: 'Roger Gracie',
    f1Color: '#1BA34E',
    f2Color: '#F5B800',
    f1Pt2: 1,
    f2Pt3: 1,
    f1Pen: 1,
    f2Adv: 1,
    winner: winner,
    method: method,
    submission: submission,
    endedAt: status == MatchStatus.finished
        ? DateTime.now().millisecondsSinceEpoch ~/ 1000
        : null,
  );
}

/// Records what the board asked of the platform, in order and in full.
class _RecordingWakelock implements ScreenWakelock {
  final List<bool> requests = [];

  @override
  Future<void> keepAwake(bool on) async => requests.add(on);
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      nostrCryptoProvider.overrideWithValue(FakeNostrCrypto()),
      nostrServiceProvider.overrideWithValue(_OfflineNostrService()),
      // The real one talks to a method channel nothing answers in a test, and
      // its timeout would outlive the test as a pending timer.
      screenWakelockProvider.overrideWithValue(const NoopScreenWakelock()),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ScoreboardScreen', () {
    testWidgets('asks for a pubkey before it shows anything', (tester) async {
      // Arrange + Act
      await tester.pumpWidget(_wrap(const ScoreboardScreen()));
      await tester.pump();

      // Assert
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.scoreboardWelcomeBody), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('refuses something that is not a pubkey, and watches nothing',
        (tester) async {
      // Arrange
      late WidgetRef capturedRef;
      await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
        capturedRef = ref;
        return const ScoreboardScreen();
      })));
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Act
      await tester.enterText(find.byType(TextField), 'definitely-not-a-key');
      await tester.tap(find.text(l10n.scoreboardWatch));
      await tester.pump();

      // Assert
      expect(find.text(l10n.scoreboardInvalidPubkey), findsOneWidget);
      expect(capturedRef.read(watchedPubkeyProvider), isNull);
    });

    testWidgets('takes an npub and starts watching it', (tester) async {
      // Arrange
      late WidgetRef capturedRef;
      await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
        capturedRef = ref;
        return const ScoreboardScreen();
      })));
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Act — FakeNostrCrypto decodes this sentinel to the watched hex key
      await tester.enterText(find.byType(TextField), 'npub1fake');
      await tester.tap(find.text(l10n.scoreboardWatch));
      await tester.pump();

      // Assert
      expect(capturedRef.read(watchedPubkeyProvider), _watched);
    });

    testWidgets("lists the watched pubkey's matches", (tester) async {
      // Arrange + Act
      SharedPreferences.setMockInitialValues(
        {'choke:scoreboard-pubkey': _watched},
      );
      await tester.pumpWidget(_wrap(
        const ScoreboardScreen(),
        overrides: [
          scoreboardMatchesProvider.overrideWithValue([_match()]),
          scoreboardFilteredMatchesProvider.overrideWithValue([_match()]),
        ],
      ));
      await tester.pump();
      await tester.pump(); // the saved pubkey is restored asynchronously

      // Assert
      expect(find.text('Buchecha'), findsOneWidget);
      expect(find.text('Roger Gracie'), findsOneWidget);
    });

    testWidgets('says so when the organizer has published nothing yet',
        (tester) async {
      // Arrange — a pubkey is being watched, but no events have arrived
      SharedPreferences.setMockInitialValues(
        {'choke:scoreboard-pubkey': _watched},
      );
      await tester.pumpWidget(_wrap(
        const ScoreboardScreen(),
        overrides: [
          scoreboardMatchesProvider.overrideWithValue(const []),
          scoreboardFilteredMatchesProvider.overrideWithValue(const []),
        ],
      ));
      await tester.pump();
      await tester.pump();

      // Assert
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.scoreboardEmptyBody), findsOneWidget);
    });
  });

  group('ScoreboardMatchScreen', () {
    Future<void> pumpBoard(WidgetTester tester, Match match) async {
      // Landscape, which is the orientation this screen asks the device for.
      tester.view.physicalSize = const Size(1600, 740);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        ScoreboardMatchScreen(matchId: match.id),
        overrides: [
          scoreboardMatchesProvider.overrideWithValue([match]),
        ],
      ));
      await tester.pump();
    }

    testWidgets('shows both fighters and their effective scores',
        (tester) async {
      // Arrange + Act — f1 scored a takedown (2); f2 scored a guard pass (3)
      // and gained 2 more from f1's third penalty… which f1 does not have, so
      // f2 stands at 3 while f1's single penalty concedes nothing yet
      await pumpBoard(tester, _match());

      // Assert
      expect(find.text('BUCHECHA'), findsOneWidget);
      expect(find.text('ROGER GRACIE'), findsOneWidget);
      expect(find.text('2'), findsWidgets, reason: "f1's takedown");
      expect(find.text('3'), findsWidgets, reason: "f2's guard pass");
    });

    testWidgets('runs a clock while the match is live', (tester) async {
      // Arrange + Act
      await pumpBoard(tester, _match());

      // Assert
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.scoreboardTime), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\d\d:\d\d$')), findsOneWidget);
    });

    testWidgets('shows the time the match itself says is left', (tester) async {
      // Arrange — a clock is derived from the event, never counted locally, so a
      // match that started 30 seconds ago reads 30 seconds down whoever opens it
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final started = _match().copyWith(startAt: now - 30);

      // Act
      await pumpBoard(tester, started);

      // Assert — 5:00 minus 30 seconds
      expect(find.text('04:30'), findsOneWidget);
    });

    testWidgets('names the winner and how they won, once it is over',
        (tester) async {
      // Arrange + Act — f2 wins by submission, which the numbers cannot say
      await pumpBoard(
        tester,
        _match(
          status: MatchStatus.finished,
          winner: MatchWinner.f2,
          method: MatchMethod.submission,
          submission: 'bow_and_arrow',
        ),
      );

      // Assert
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.scoreboardWinner.toUpperCase()), findsOneWidget);
      expect(find.text('ROGER GRACIE'), findsWidgets);
      // The clock is gone: a finished match has no time left to show.
      expect(find.text(l10n.scoreboardTime), findsNothing);
    });

    testWidgets('a match that is no longer in the feed says so',
        (tester) async {
      // Arrange + Act — it can age out while this screen is open
      tester.view.physicalSize = const Size(1600, 740);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const ScoreboardMatchScreen(matchId: 'gone'),
        overrides: [
          scoreboardMatchesProvider.overrideWithValue(const []),
          scoreboardFilteredMatchesProvider.overrideWithValue(const []),
        ],
      ));
      await tester.pump();

      // Assert
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.scoreboardEmptyTitle), findsOneWidget);
    });
  });

  group('ScoreboardScreen status filter', () {
    testWidgets('shows a chip per status, counting everything in scope',
        (tester) async {
      // Arrange — counts come from the whole set, not from what survives the
      // filter, or a hidden status would always read zero
      SharedPreferences.setMockInitialValues(
        {'choke:scoreboard-pubkey': _watched},
      );
      final live = _match();
      final done = _match(status: MatchStatus.finished);

      // Act
      await tester.pumpWidget(_wrap(
        const ScoreboardScreen(),
        overrides: [
          scoreboardMatchesProvider.overrideWithValue([live, done]),
          scoreboardFilteredMatchesProvider.overrideWithValue([live]),
        ],
      ));
      await tester.pump();
      await tester.pump();

      // Assert — four chips, and the finished one counts its match even though
      // the list is not showing it
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byType(StatusFilterBar), findsOneWidget);

      // Scoped to the bar: the cards carry a status chip of their own, so a
      // bare text finder would count those too.
      Finder inBar(String label) => find.descendant(
            of: find.byType(StatusFilterBar),
            matching: find.text(label),
          );
      expect(inBar(l10n.statusFinished), findsOneWidget);
      expect(inBar(l10n.statusInProgress), findsOneWidget);
      expect(inBar(l10n.statusWaiting), findsOneWidget);
      expect(inBar(l10n.statusCanceled), findsOneWidget);
    });

    testWidgets('tapping a chip toggles that status into the filter',
        (tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues(
        {'choke:scoreboard-pubkey': _watched},
      );
      late WidgetRef capturedRef;
      await tester.pumpWidget(_wrap(
        Consumer(builder: (context, ref, _) {
          capturedRef = ref;
          return const ScoreboardScreen();
        }),
        overrides: [
          scoreboardMatchesProvider.overrideWithValue([_match()]),
          scoreboardFilteredMatchesProvider.overrideWithValue([_match()]),
        ],
      ));
      await tester.pump();
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        capturedRef.read(scoreboardStatusFilterProvider),
        isNot(contains(MatchStatus.finished)),
      );

      final chip = find.descendant(
        of: find.byType(StatusFilterBar),
        matching: find.text(l10n.statusFinished),
      );

      // Act
      await tester.tap(chip);
      await tester.pump();

      // Assert
      expect(
        capturedRef.read(scoreboardStatusFilterProvider),
        contains(MatchStatus.finished),
      );

      // Act — and off again
      await tester.tap(chip);
      await tester.pump();

      // Assert
      expect(
        capturedRef.read(scoreboardStatusFilterProvider),
        isNot(contains(MatchStatus.finished)),
      );
    });

    testWidgets('no chips before a pubkey is being watched', (tester) async {
      // Arrange + Act — nothing to filter yet
      await tester.pumpWidget(_wrap(const ScoreboardScreen()));
      await tester.pump();

      // Assert
      expect(find.byType(StatusFilterBar), findsNothing);
    });
  });

  group('ScoreboardScreen broken link', () {
    testWidgets('shows the board only after the user acknowledges the link',
        (tester) async {
      // Arrange — a board is already being watched, and a link naming a
      // different one arrived broken. Its matches must not stand in for the
      // board that was actually asked for.
      SharedPreferences.setMockInitialValues(
        {'choke:scoreboard-pubkey': _watched},
      );
      late WidgetRef ref;
      await tester.pumpWidget(_wrap(
        Consumer(builder: (context, r, _) {
          ref = r;
          return const ScoreboardScreen();
        }),
        overrides: [
          brokenShareLinkProvider.overrideWith((ref) => true),
          scoreboardMatchesProvider.overrideWithValue([_match()]),
          scoreboardFilteredMatchesProvider.overrideWithValue([_match()]),
        ],
      ));
      await tester.pump();
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Assert — the message, and none of the board behind it
      expect(find.text(l10n.scoreboardBrokenLinkTitle), findsOneWidget);
      expect(find.text('Buchecha'), findsNothing);

      // …including the header, which would otherwise name the organizer the
      // user was already watching one line above "that link is broken", and
      // invite them to read that hex as the link's board
      expect(
        find.textContaining(_watched.substring(0, 8)),
        findsNothing,
        reason: 'the previous organizer must not be named here',
      );
      expect(find.byType(TextField), findsNothing,
          reason: 'nothing to type into until they have read this');
      expect(find.byType(StatusFilterBar), findsNothing);

      // Act — they acknowledge it
      await tester.tap(find.text(l10n.scoreboardBrokenLinkDismiss));
      await tester.pump();

      // Assert — now their own board comes back
      expect(ref.read(brokenShareLinkProvider), isFalse);
      expect(find.text(l10n.scoreboardBrokenLinkTitle), findsNothing);
      expect(find.text('Buchecha'), findsOneWidget);
    });
  });

  group('BoardPalette', () {
    test('picks 3A for a light theme and the original for a dark one', () {
      // Arrange + Act + Assert — the switch itself, without a board around it
      expect(BoardPalette.light.background, const Color(0xFFF4F6FB));
      expect(BoardPalette.dark.background, const Color(0xFF05070E));
    });

    test('darkens a fighter colour for light, leaves it alone for dark', () {
      // A gi colour picked to glow on black is too light to read as a word on
      // white. 3A takes each channel to 72%.
      const jade = Color(0xFF13C880);

      final onLight = BoardPalette.light.readable(jade);
      final onDark = BoardPalette.dark.readable(jade);

      expect(onDark, jade, reason: 'the colour the fighter chose is the point');
      expect(onLight, isNot(jade));
      expect((onLight.r * 255).round(), (0x13 * 0.72).round());
      expect((onLight.g * 255).round(), (0xC8 * 0.72).round());
      expect((onLight.b * 255).round(), (0x80 * 0.72).round());
    });

    test('veils the losing half in its own background, not in black', () {
      // On a light board a dark veil reads as a shadow rather than as a half
      // that has been washed out.
      expect(BoardPalette.light.loserVeil.r, BoardPalette.light.background.r);
      expect(BoardPalette.dark.loserVeil.r, BoardPalette.dark.background.r);
    });

    test('the banner is not the clock card', () {
      // Collapsing the two because 3A gives them the same white is what left the
      // dark theme announcing its winner on a 3%-opaque panel, with the fighter
      // washes showing straight through.
      expect(
        BoardPalette.dark.bannerSurface,
        isNot(BoardPalette.dark.cardSurface),
      );
      expect(BoardPalette.dark.bannerSurface.a, greaterThan(0.6),
          reason: 'opaque enough that the washes do not come through');
      expect(BoardPalette.dark.cardSurface.a, lessThan(0.1),
          reason: 'the card, by contrast, is meant to be seen through');
      expect(BoardPalette.dark.bannerOutlined, isFalse,
          reason: 'the dark banner never had a border or a shadow');
      expect(BoardPalette.light.bannerOutlined, isTrue, reason: '3A asks for both');
    });

    test('preserves the dark surfaces it started from', () {
      // The light-theme tests cannot see a dark-theme regression by
      // construction, and that is exactly how the banner one got through.
      expect(BoardPalette.dark.background, const Color(0xFF05070E));
      expect(BoardPalette.dark.cardSurface, const Color(0x08FFFFFF));
      expect(BoardPalette.dark.bannerSurface, const Color(0xB805070E));
      expect(BoardPalette.dark.loserVeil, const Color(0x9E05070E));
      expect(BoardPalette.dark.label, const Color(0xFF5F6D8A));
      expect(BoardPalette.dark.vs, const Color(0x29FFFFFF));
    });

    test('carries the alphas, not just the colours', () {
      // Porting the hues and leaving the dark theme's opacities is the
      // difference between moving a palette and implementing a design.
      expect(BoardPalette.light.pillFillAlpha, .14);
      expect(BoardPalette.light.pillBorderAlpha, .45);
      expect(BoardPalette.light.chipFillAlpha, .12);
      expect(BoardPalette.light.chipBorderAlpha, .42);
      expect(BoardPalette.dark.pillFillAlpha, .12);
      expect(BoardPalette.dark.chipBorderAlpha, .5);
    });

    test('the blinking dot does not smudge a light board', () {
      expect(BoardPalette.light.pillDotGlowAlpha, 0);
      expect(BoardPalette.dark.pillDotGlowAlpha, greaterThan(0));
    });

    test('glows less in daylight', () {
      // A glow is light in the dark and a shadow in daylight; the same alpha
      // cannot do both.
      expect(
        BoardPalette.light.edgeGlowAlpha,
        lessThan(BoardPalette.dark.edgeGlowAlpha),
      );
    });
  });

  group('ScoreboardMatchScreen theming', () {
    Future<void> pumpThemed(WidgetTester tester, ThemeData theme) async {
      tester.view.physicalSize = const Size(1600, 740);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final match = _match();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          nostrCryptoProvider.overrideWithValue(FakeNostrCrypto()),
          nostrServiceProvider.overrideWithValue(_OfflineNostrService()),
          screenWakelockProvider.overrideWithValue(const NoopScreenWakelock()),
          scoreboardMatchesProvider.overrideWithValue([match]),
        ],
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScoreboardMatchScreen(matchId: match.id),
        ),
      ));
      await tester.pump();
    }

    Color boardBackground(WidgetTester tester) {
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      return scaffold.backgroundColor!;
    }

    testWidgets('a light app paints the board on 3A\'s surface',
        (tester) async {
      // Act
      await pumpThemed(tester, AppTheme.lightTheme);

      // Assert
      expect(boardBackground(tester), BoardPalette.light.background);
    });

    testWidgets('a dark app keeps the original surface', (tester) async {
      // Act
      await pumpThemed(tester, AppTheme.darkTheme);

      // Assert
      expect(boardBackground(tester), BoardPalette.dark.background);
    });

    testWidgets('the fighter names are legible against the light surface',
        (tester) async {
      // The failure this guards against is the cheap version of the change —
      // swap the background and leave the text white on near-white.
      //
      // Act
      await pumpThemed(tester, AppTheme.lightTheme);

      // Assert
      final name = tester.widget<Text>(find.text('BUCHECHA'));
      expect(name.style!.color, BoardPalette.light.text);
      expect(name.style!.color, isNot(Colors.white));
    });
  });

  group('ScoreboardMatchScreen wakelock', () {
    /// Records every request, repeats included — deduplicating here would make
    /// "it keeps asking" unobservable, which is the lesson the control screen's
    /// fake taught the hard way.
    Future<void> pumpBoardWith(
      WidgetTester tester,
      _RecordingWakelock wakelock,
      Match match,
    ) async {
      tester.view.physicalSize = const Size(1600, 740);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        ScoreboardMatchScreen(matchId: match.id),
        overrides: [
          screenWakelockProvider.overrideWithValue(wakelock),
          scoreboardMatchesProvider.overrideWithValue([match]),
        ],
      ));
      await tester.pump();
    }

    testWidgets('holds the screen from the moment the board opens',
        (tester) async {
      // Arrange + Act
      final wakelock = _RecordingWakelock();
      await pumpBoardWith(tester, wakelock, _match());

      // Assert
      expect(wakelock.requests, isNotEmpty);
      expect(wakelock.requests.every((on) => on), isTrue);
    });

    testWidgets('holds it for a match that has not started', (tester) async {
      // Waiting for the first bell is watching, not idling.
      final wakelock = _RecordingWakelock();
      await pumpBoardWith(
        tester,
        wakelock,
        _match(status: MatchStatus.waiting),
      );

      expect(wakelock.requests, contains(true));
      expect(wakelock.requests, isNot(contains(false)));
    });

    testWidgets('holds it for a finished match too', (tester) async {
      // The one place this deliberately differs from the control screen: a
      // finished board is left up to be read across a room, and it must not go
      // dark mid-read.
      final wakelock = _RecordingWakelock();
      await pumpBoardWith(
        tester,
        wakelock,
        _match(
          status: MatchStatus.finished,
          winner: MatchWinner.f2,
          method: MatchMethod.submission,
        ),
      );

      expect(wakelock.requests, contains(true));
      expect(wakelock.requests, isNot(contains(false)));
    });

    testWidgets('keeps re-asserting, so a dropped request is retried',
        (tester) async {
      // Arrange
      final wakelock = _RecordingWakelock();
      await pumpBoardWith(tester, wakelock, _match());
      final atStart = wakelock.requests.length;

      // Act — a quiet minute, nobody touching anything
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Assert — asking again is the only way a request the platform dropped
      // ever gets made again
      expect(wakelock.requests.length, greaterThan(atStart));
      expect(wakelock.requests, isNot(contains(false)));
    });

    testWidgets('releases the screen when the viewer leaves', (tester) async {
      // Arrange
      final wakelock = _RecordingWakelock();
      await pumpBoardWith(tester, wakelock, _match());

      // Act
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Assert
      expect(wakelock.requests.last, isFalse);
    });
  });
}
