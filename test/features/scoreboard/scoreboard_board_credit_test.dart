import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/features/scoreboard/providers/scoreboard_providers.dart';
import 'package:choke/features/scoreboard/board_palette.dart';
import 'package:choke/features/scoreboard/scoreboard_match_screen.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'package:choke/services/deep_links/share_link.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/crypto/nostr_crypto.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/services/wakelock/screen_wakelock.dart';
import 'package:choke/shared/theme/app_theme.dart';

import '../../support/nostr_fakes.dart';

/// The relays are not part of what these tests are about; the feed just needs
/// something that answers.
class _OfflineNostrService extends NostrService {
  _OfflineNostrService()
      : super(KeyManager(crypto: FakeNostrCrypto()),
            crypto: FakeNostrCrypto(), backend: FakeRelayBackend());

  final controller = StreamController<NostrEvent>.broadcast();

  @override
  Stream<NostrEvent> get eventStream => controller.stream;

  @override
  void subscribeToAuthor(String authorPubkey, {String? subscriptionId}) {}

  @override
  void unsubscribe(String subscriptionId) {}

  @override
  List<NostrEvent> cachedEventsOf(int kind, String pubkey) => const [];
}

Match _match({
  MatchStatus status = MatchStatus.inProgress,
  MatchWinner? winner,
  MatchMethod? method,
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
    winner: winner,
    method: method,
    endedAt: status == MatchStatus.finished
        ? DateTime.now().millisecondsSinceEpoch ~/ 1000
        : null,
  );
}

Widget _wrap(Widget child, ThemeData theme, List<Override> overrides) {
  return ProviderScope(
    overrides: [
      nostrCryptoProvider.overrideWithValue(FakeNostrCrypto()),
      nostrServiceProvider.overrideWithValue(_OfflineNostrService()),
      // The real one talks to a method channel nothing answers in a test.
      screenWakelockProvider.overrideWithValue(const NoopScreenWakelock()),
      ...overrides,
    ],
    child: MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  Future<void> pumpBoard(
    WidgetTester tester,
    Match match, {
    ThemeData? theme,
  }) async {
    // Landscape, which is the orientation this screen asks the device for.
    tester.view.physicalSize = const Size(1600, 740);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      ScoreboardMatchScreen(matchId: match.id),
      theme ?? AppTheme.darkTheme,
      [
        scoreboardMatchesProvider.overrideWithValue([match])
      ],
    ));
    await tester.pump();
  }

  /// The label above the domain, as the board renders it.
  Future<String> label() async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    return l10n.boardLiveCredit.toUpperCase();
  }

  group('ScoreboardMatchScreen live credit', () {
    testWidgets('sends the room to the domain, under a label', (tester) async {
      // Arrange + Act — the audience watches this screen for a whole match
      await pumpBoard(tester, _match());

      // Assert — the address is the message; the label only says what it is
      expect(find.text(kShareLinkHost), findsOneWidget);
      expect(find.text(await label()), findsOneWidget);
    });

    testWidgets('never lets a translation carry the domain', (tester) async {
      // Arrange + Act — the domain is rendered from kShareLinkHost, so the one
      // the room is told to visit is the one the app answers for. A translator
      // who typed it into a string could put a dead address on a wall.
      await pumpBoard(tester, _match());

      // Assert
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(l10n.boardLiveCredit, isNot(contains(kShareLinkHost)));
      }
    });

    testWidgets('reads the domain louder than its label', (tester) async {
      // Arrange + Act — the domain is what somebody has to remember
      await pumpBoard(tester, _match());

      // Assert
      final domain = tester.widget<Text>(find.text(kShareLinkHost));
      final caption = tester.widget<Text>(find.text(await label()));
      expect(domain.style!.fontSize, greaterThan(caption.style!.fontSize!));
      expect(domain.style!.color, BoardPalette.dark.text);
      expect(caption.style!.color, BoardPalette.dark.label);
    });

    testWidgets('stays quieter than the score', (tester) async {
      // Arrange + Act — promotion must never compete with what is being scored
      await pumpBoard(tester, _match());

      // Assert — the fighters' points dwarf it, which is the whole hierarchy
      final domain = tester.widget<Text>(find.text(kShareLinkHost));
      final score = tester.widget<Text>(find.text('0').first);
      expect(domain.style!.fontSize, lessThan(score.style!.fontSize!));
    });

    testWidgets('keeps the credit legible on the light board', (tester) async {
      // Arrange + Act — design 3A paints the board on a near-white surface
      await pumpBoard(tester, _match(), theme: AppTheme.lightTheme);

      // Assert
      final domain = tester.widget<Text>(find.text(kShareLinkHost));
      expect(domain.style!.color, BoardPalette.light.text);
      expect(domain.style!.color, isNot(BoardPalette.dark.text));
    });

    testWidgets('still credits the board once a match is over', (tester) async {
      // Arrange — a finished board is left up to be read across a room, which
      // is the longest anybody looks at it.
      final done = _match(
        status: MatchStatus.finished,
        winner: MatchWinner.f2,
        method: MatchMethod.points,
      );

      // Act
      await pumpBoard(tester, done);

      // Assert — and the banner announcing the winner is still there
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.scoreboardWinner.toUpperCase()), findsOneWidget);
      expect(find.text(kShareLinkHost), findsOneWidget);
    });
  });
}
