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
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/crypto/nostr_crypto.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/services/wakelock/screen_wakelock.dart';
import 'package:choke/shared/theme/app_theme.dart';
import 'package:choke/shared/widgets/match_card.dart';

import '../../support/nostr_fakes.dart';
import '../../support/share_channel.dart';

/// The relays are not part of what these tests are about; the feed just needs
/// something that answers.
class _OfflineNostrService extends NostrService {
  _OfflineNostrService()
      : super(KeyManager(crypto: FakeNostrCrypto()),
            crypto: FakeNostrCrypto(), backend: FakeRelayBackend());

  @override
  Stream<NostrEvent> get eventStream => const Stream.empty();

  @override
  void subscribeToAuthor(String authorPubkey, {String? subscriptionId}) {}

  @override
  void unsubscribe(String subscriptionId) {}

  @override
  List<NostrEvent> cachedEventsOf(int kind, String pubkey) => const [];
}

const _watched =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

/// The two links, spelled out rather than built from the same helpers the code
/// uses. Asserting against `matchShareUrl(...)` would pass however the URL is
/// assembled; these fail if the shape of either one moves.
const _boardUrl = 'https://bjjscore.live/?npub=npub1fake';
const _matchUrl = 'https://bjjscore.live/?npub=npub1fake&match=abcd';

Match _match() => Match(
      id: 'abcd',
      status: MatchStatus.inProgress,
      startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      duration: 300,
      f1Name: 'Buchecha',
      f2Name: 'Roger Gracie',
      f1Color: '#1BA34E',
      f2Color: '#F5B800',
    );

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      nostrCryptoProvider.overrideWithValue(FakeNostrCrypto()),
      nostrServiceProvider.overrideWithValue(_OfflineNostrService()),
      // The real one talks to a method channel nothing answers in a test.
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

/// The list, with a board being watched and one match on it.
Future<void> _pumpList(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'choke:scoreboard-pubkey': _watched});
  await tester.pumpWidget(_wrap(
    const ScoreboardScreen(),
    overrides: [
      scoreboardMatchesProvider.overrideWithValue([_match()]),
      scoreboardFilteredMatchesProvider.overrideWithValue([_match()]),
    ],
  ));
  await tester.pump();
  await tester.pump(); // the saved pubkey is restored asynchronously
}

/// The wall board for one match, with the same board being watched.
///
/// `pumpAndSettle` is unusable here: the live status dot animates for as long
/// as the match is running, so a settled frame never arrives. Every wait in
/// this file is a fixed pump for that reason.
Future<void> _pumpBoard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 740);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'choke:scoreboard-pubkey': _watched});
  await tester.pumpWidget(_wrap(
    const ScoreboardMatchScreen(matchId: 'abcd'),
    overrides: [
      scoreboardMatchesProvider.overrideWithValue([_match()]),
    ],
  ));
  await tester.pump();
  await tester.pump(); // the saved pubkey is restored asynchronously
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MatchCard share affordance', () {
    testWidgets('renders nothing extra without a callback', (tester) async {
      // Arrange + Act — the home feed's card, which this change must not touch
      await tester.pumpWidget(_wrap(
        Scaffold(body: MatchCard(match: _match())),
      ));
      await tester.pump();

      // Assert
      expect(find.byTooltip(l10n.scoreboardShareMatch), findsNothing);
      expect(find.byIcon(Icons.ios_share), findsNothing);
    });

    testWidgets('offers a share icon when given a callback', (tester) async {
      // Arrange
      var shared = 0;

      // Act
      await tester.pumpWidget(_wrap(
        Scaffold(body: MatchCard(match: _match(), onShare: () => shared++)),
      ));
      await tester.pump();
      await tester.tap(find.byTooltip(l10n.scoreboardShareMatch));
      await tester.pump();

      // Assert — and the card's own tap target is untouched by the icon's
      expect(shared, 1);
    });

    testWidgets('stays quieter than the card it sits on', (tester) async {
      // Arrange + Act — a list of ten cards each shouting "share" is a list
      // nobody reads, so the affordance recedes until it is looked for.
      await tester.pumpWidget(_wrap(
        Scaffold(body: MatchCard(match: _match(), onShare: () {})),
      ));
      await tester.pump();

      // Assert — muted, and smaller than the fighters' names
      final icon = tester.widget<Icon>(find.byIcon(Icons.ios_share));
      final name = tester.widget<Text>(find.text('Buchecha'));
      expect(icon.size, isNotNull);
      expect(icon.size!, lessThan(name.style!.fontSize!));
      expect(icon.color, ChokeTokens.dark.faint);
    });

    testWidgets('is quiet to look at without being small to hit',
        (tester) async {
      // Arrange — quiet is a matter of size, weight and colour; the thing you
      // tap has to clear Material's 48x48 either way, and it sits next to a
      // much larger competing target, so a near miss opens the match instead
      // of sharing it.
      var shared = 0;
      await tester.pumpWidget(_wrap(
        Scaffold(body: MatchCard(match: _match(), onShare: () => shared++)),
      ));
      await tester.pump();

      // Act + Assert — the tap target, not the glyph
      final target = tester.getRect(find.byType(IconButton));
      final glyph = tester.getRect(find.byIcon(Icons.ios_share));
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
      expect(glyph.height, lessThan(target.height));

      // A tap a pixel inside the corner is nowhere near the glyph, and still
      // shares. `constraints` on an IconButton cannot shrink this — only
      // `MaterialTapTargetSize` can — which is why none is set.
      await tester.tapAt(target.topLeft + const Offset(1, 1));
      await tester.pump();
      expect(shared, 1);
    });
  });

  group('ScoreboardScreen match sharing', () {
    testWidgets('shares a link naming the match, not the board',
        (tester) async {
      // Arrange
      final calls = mockShareChannel(tester);
      await _pumpList(tester);

      // Act
      await tester.tap(find.byTooltip(l10n.scoreboardShareMatch));
      await tester.pump();

      // Assert — the id travels with the organizer, because an id alone names
      // nothing, and the raw hex key never leaves the device.
      expect(calls, hasLength(1));
      final text = calls.single['text'] as String;
      expect(text, contains(_matchUrl));
      expect(text, contains('&match=abcd'));
      expect(text, contains(l10n.scoreboardShareMatchMessage));
      expect(text, isNot(contains(_watched)));
    });

    testWidgets('sends a different link than sharing the board does',
        (tester) async {
      // Arrange — "share the board" and "share this match" produce different
      // links, and a user who cannot tell them apart sends the wrong one. They
      // no longer sit inches apart — the board's lives inside the QR dialog —
      // but what they send still has to stay distinguishable.
      final calls = mockShareChannel(tester);
      await _pumpList(tester);

      // Act — the board, from inside the code's dialog, then out of it
      await tester.tap(find.byTooltip(l10n.showQr));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.scoreboardShareBoard));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();

      // Act — and the match, from its card
      await tester.tap(find.byTooltip(l10n.scoreboardShareMatch));
      await tester.pump();

      // Assert
      expect(calls, hasLength(2));
      final board = calls.first['text'] as String;
      final match = calls.last['text'] as String;
      expect(board, contains(_boardUrl));
      expect(board, isNot(contains('match=')));
      expect(match, contains(_matchUrl));
      expect(board, isNot(match));
      // And neither is labelled a bare "Share"
      expect(calls.first['subject'], l10n.scoreboardShareBoard);
      expect(calls.last['subject'], l10n.scoreboardShareMatch);
    });

    testWidgets('surfaces a share sheet failure instead of crashing',
        (tester) async {
      // Arrange
      mockShareChannel(tester, fail: true);
      await _pumpList(tester);

      // Act
      await tester.tap(find.byTooltip(l10n.scoreboardShareMatch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert
      expect(find.text(l10n.shareFailed), findsOneWidget);
    });
  });

  group('ScoreboardMatchScreen sharing', () {
    testWidgets('shares the match being watched', (tester) async {
      // Arrange
      final calls = mockShareChannel(tester);
      await _pumpBoard(tester);

      // Act
      await tester.tap(find.byTooltip(l10n.scoreboardShareMatch));
      await tester.pump();

      // Assert
      expect(calls, hasLength(1));
      final text = calls.single['text'] as String;
      expect(text, contains(_matchUrl));
      expect(text, contains('&match=abcd'));
      expect(text, isNot(contains(_watched)));
    });

    testWidgets('goes straight to the share sheet, with no menu in the way',
        (tester) async {
      // Arrange — this is the "look at this" reflex; a chooser in front of it
      // costs more than it offers.
      final calls = mockShareChannel(tester);
      await _pumpBoard(tester);

      // Act
      await tester.tap(find.byTooltip(l10n.scoreboardShareMatch));
      await tester.pump();

      // Assert
      expect(calls, hasLength(1));
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('carries no QR — the credit line already does that job',
        (tester) async {
      // Arrange + Act — when this screen is the projection the audience is
      // already reading bjjscore.live along the bottom of it.
      await _pumpBoard(tester);

      // Assert
      expect(find.byIcon(Icons.qr_code_2), findsNothing);
    });

    testWidgets('sits opposite Back, as its pair', (tester) async {
      // Arrange + Act
      await _pumpBoard(tester);

      // Assert — same offsets, mirrored, so the two chrome items read together
      final back = tester.widget<Positioned>(find.ancestor(
        of: find.text(l10n.goBack),
        matching: find.byType(Positioned),
      ));
      final share = tester.widget<Positioned>(find.ancestor(
        of: find.byTooltip(l10n.scoreboardShareMatch),
        matching: find.byType(Positioned),
      ));
      expect(back.top, 8);
      expect(back.left, 8);
      expect(share.top, back.top);
      expect(share.right, 8);
    });

    testWidgets('offers no share with no board to name', (tester) async {
      // Arrange — nothing watched means no npub, and a match id on its own
      // names nothing.
      tester.view.physicalSize = const Size(1600, 740);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const ScoreboardMatchScreen(matchId: 'abcd'),
        overrides: [
          scoreboardMatchesProvider.overrideWithValue([_match()]),
        ],
      ));
      await tester.pump();

      // Assert
      expect(find.byTooltip(l10n.scoreboardShareMatch), findsNothing);
    });

    testWidgets('surfaces a share sheet failure instead of crashing',
        (tester) async {
      // Arrange
      mockShareChannel(tester, fail: true);
      await _pumpBoard(tester);

      // Act
      await tester.tap(find.byTooltip(l10n.scoreboardShareMatch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert
      expect(find.text(l10n.shareFailed), findsOneWidget);
    });
  });
}
