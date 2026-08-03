import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/features/scoreboard/providers/scoreboard_providers.dart';
import 'package:choke/features/scoreboard/scoreboard_screen.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'package:choke/services/deep_links/share_link.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/crypto/nostr_crypto.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/services/wakelock/screen_wakelock.dart';
import 'package:choke/shared/theme/app_theme.dart';
import 'package:choke/shared/widgets/qr_dialog.dart';

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

/// The link the fake crypto's npub encodes to. Spelled out rather than built,
/// so a change to how the URL is assembled fails here too.
const _sharedUrl = 'https://bjjscore.live/?npub=npub1fake';

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

/// The screen with a board already being watched, which is the only state the
/// share actions exist in.
Future<void> _pumpWatching(WidgetTester tester) async {
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
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ScoreboardScreen sharing', () {
    testWidgets('offers nothing to share until a board is being watched',
        (tester) async {
      // Arrange + Act — the welcome state, no pubkey watched
      await tester.pumpWidget(_wrap(const ScoreboardScreen()));
      await tester.pump();

      // Assert — sharing "the board" with no board named would hand somebody a
      // link to nothing.
      expect(find.byTooltip(l10n.scoreboardShareBoard), findsNothing);
      expect(find.byTooltip(l10n.showQr), findsNothing);
    });

    testWidgets('opens the share sheet with a link to the watched board',
        (tester) async {
      // Arrange
      final calls = mockShareChannel(tester);
      await _pumpWatching(tester);

      // Act
      await tester.tap(find.byTooltip(l10n.scoreboardShareBoard));
      await tester.pumpAndSettle();

      // Assert — the spectator gets a link, never the raw hex key
      expect(calls, hasLength(1));
      final sharedText = calls.single['text'] as String;
      expect(sharedText, contains(_sharedUrl));
      expect(sharedText, contains(l10n.scoreboardShareBoardMessage));
      expect(sharedText, isNot(contains(_watched)));
    });

    testWidgets('surfaces a share sheet failure instead of crashing',
        (tester) async {
      // Arrange
      mockShareChannel(tester, fail: true);
      await _pumpWatching(tester);

      // Act
      await tester.tap(find.byTooltip(l10n.scoreboardShareBoard));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(l10n.shareFailed), findsOneWidget);
    });

    testWidgets('shows a QR of the same link, for projecting at the venue',
        (tester) async {
      // Arrange
      await _pumpWatching(tester);

      // Act
      await tester.tap(find.byTooltip(l10n.showQr));
      await tester.pumpAndSettle();

      // Assert — the code carries the share link, and the link is legible
      // underneath it for anyone whose camera will not scan.
      expect(find.byType(QrImageView), findsOneWidget);
      final dialog = tester.widget<QrDialog>(find.byType(QrDialog));
      expect(dialog.data, _sharedUrl);
      expect(find.text(_sharedUrl), findsOneWidget);
      expect(find.text(l10n.scoreboardQrTitle), findsOneWidget);

      // Act — and it closes
      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('copies the link under the code when it is tapped',
        (tester) async {
      // Arrange — the other way a link leaves this screen when the camera in
      // the room will not scan
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
      await _pumpWatching(tester);
      await tester.tap(find.byTooltip(l10n.showQr));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text(_sharedUrl));
      await tester.pumpAndSettle();

      // Assert — the same link the code carries, and the user was told
      expect(copied, [_sharedUrl]);
      expect(find.text(l10n.copiedToClipboard(l10n.link)), findsOneWidget);
    });

    testWidgets('offers nothing to share behind a broken link', (tester) async {
      // Arrange — a link named a board and could not be read. Sharing the board
      // underneath it would pass on the substitution the state exists to stop.
      await _pumpWatching(tester);
      final context = tester.element(find.byType(ScoreboardScreen));
      final container = ProviderScope.containerOf(context);

      // Act
      container.read(brokenShareLinkProvider.notifier).state = true;
      await tester.pump();

      // Assert
      expect(find.byTooltip(l10n.scoreboardShareBoard), findsNothing);
      expect(find.byTooltip(l10n.showQr), findsNothing);
    });
  });
}
