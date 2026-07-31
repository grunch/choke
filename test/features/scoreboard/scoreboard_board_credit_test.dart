import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/features/scoreboard/providers/scoreboard_providers.dart';
import 'package:choke/features/scoreboard/board_palette.dart';
import 'package:choke/features/scoreboard/scoreboard_match_screen.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
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

  Future<String> credit() async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    return l10n.boardLiveCredit;
  }

  group('ScoreboardMatchScreen live credit', () {
    testWidgets('credits bjjscore.live on the wall board', (tester) async {
      // Arrange + Act — the audience watches this screen for a whole match
      await pumpBoard(tester, _match());

      // Assert
      expect(find.text(await credit()), findsOneWidget);
    });

    testWidgets('names the brand in every language', (tester) async {
      // Arrange + Act — the domain is the product; it is never translated
      await pumpBoard(tester, _match());

      // Assert
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(l10n.boardLiveCredit, contains('bjjscore.live'));
      }
    });

    testWidgets('keeps the credit legible on the light board', (tester) async {
      // Arrange + Act — design 3A paints the board on a near-white surface
      await pumpBoard(tester, _match(), theme: AppTheme.lightTheme);

      // Assert
      final text = tester.widget<Text>(find.text(await credit()));
      expect(text.style!.color, BoardPalette.light.label);
      expect(text.style!.color, isNot(BoardPalette.dark.label));
    });

    testWidgets('stays quieter than the fighters names', (tester) async {
      // Arrange + Act — promotion must never compete with the score
      await pumpBoard(tester, _match());

      // Assert
      final text = tester.widget<Text>(find.text(await credit()));
      expect(text.style!.color, BoardPalette.dark.label);
      expect(text.style!.color, isNot(BoardPalette.dark.text));
    });

    testWidgets('does not cover the winner banner once a match is over',
        (tester) async {
      // Arrange — the banner is the one thing a whole room reads at once
      final done = _match(
        status: MatchStatus.finished,
        winner: MatchWinner.f2,
        method: MatchMethod.points,
      );

      // Act
      await pumpBoard(tester, done);

      // Assert
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.scoreboardWinner.toUpperCase()), findsOneWidget);
      expect(find.text(await credit()), findsOneWidget);
      // The banner is painted after the credit, so it wins any overlap.
      final stack = tester.widget<Stack>(
        find
            .descendant(
              of: find.byType(LayoutBuilder),
              matching: find.byType(Stack),
            )
            .first,
      );
      final creditIndex = stack.children.indexWhere(
        (w) => find
            .descendant(
                of: find.byWidget(w), matching: find.text(l10n.boardLiveCredit))
            .evaluate()
            .isNotEmpty,
      );
      final bannerIndex = stack.children.indexWhere(
        (w) => find
            .descendant(
                of: find.byWidget(w),
                matching: find.text(l10n.scoreboardWinner.toUpperCase()))
            .evaluate()
            .isNotEmpty,
      );
      expect(creditIndex, greaterThanOrEqualTo(0));
      expect(bannerIndex, greaterThan(creditIndex));
    });
  });
}
