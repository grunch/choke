import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/features/scoreboard/providers/scoreboard_providers.dart';
import 'package:choke/features/scoreboard/scoreboard_screen.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
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

/// Records what the board asked of the platform, in order and in full —
/// repeats included, because "it keeps asking" must stay observable. A release
/// records as a final false.
class _RecordingWakelock implements ScreenWakelock {
  final List<bool> requests = [];

  /// Whether the screen is being held awake, or null if it never asked for
  /// anything either way.
  bool? get held => requests.isEmpty ? null : requests.last;

  @override
  ScreenWakelockLease lease() => _RecordingLease(this);
}

class _RecordingLease implements ScreenWakelockLease {
  _RecordingLease(this._owner);

  final _RecordingWakelock _owner;

  @override
  Future<void> keepAwake(bool on) async => _owner.requests.add(on);

  @override
  Future<void> release() async => _owner.requests.add(false);
}

/// The board the test drives, standing in for what the relays would deliver.
///
/// A [StateProvider] rather than a fixed override because the point of most of
/// these tests is what happens when the board *changes* under the screen: a
/// fight ends, the next one appears, the event runs out of matches.
final _board = StateProvider<List<Match>>((ref) => const []);

Match _match(String id, MatchStatus status) => Match(
      id: id,
      status: status,
      startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      duration: 300,
      f1Name: 'Buchecha',
      f2Name: 'Roger Gracie',
      f1Color: '#1BA34E',
      f2Color: '#F5B800',
      endedAt: status == MatchStatus.finished
          ? DateTime.now().millisecondsSinceEpoch ~/ 1000
          : null,
    );

void main() {
  late _RecordingWakelock wakelock;
  late WidgetRef ref;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    wakelock = _RecordingWakelock();
  });

  /// Put the board on screen with [matches] on it, on the scoreboard tab unless
  /// told otherwise.
  Future<void> pumpBoard(
    WidgetTester tester, {
    List<Match> matches = const [],
    AppTab tab = AppTab.scoreboard,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nostrCryptoProvider.overrideWithValue(FakeNostrCrypto()),
          nostrServiceProvider.overrideWithValue(_OfflineNostrService()),
          screenWakelockProvider.overrideWithValue(wakelock),
          _board.overrideWith((ref) => matches),
          scoreboardMatchesProvider.overrideWith((ref) => ref.watch(_board)),
          selectedTabProvider.overrideWith((ref) => tab),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(builder: (context, r, _) {
            ref = r;
            return const ScoreboardScreen();
          }),
        ),
      ),
    );
    await tester.pump();
  }

  /// Replace what is on the board, the way an arriving relay event would.
  Future<void> setBoard(WidgetTester tester, List<Match> matches) async {
    ref.read(_board.notifier).state = matches;
    await tester.pump();
  }

  Future<void> selectTab(WidgetTester tester, AppTab tab) async {
    ref.read(selectedTabProvider.notifier).state = tab;
    await tester.pump();
  }

  testWidgets('holds the screen while a fight is running on the watched board',
      (tester) async {
    // Arrange + Act
    await pumpBoard(tester, matches: [_match('aaaa', MatchStatus.inProgress)]);

    // Assert
    expect(wakelock.held, isTrue);
  });

  testWidgets('holds it in the gap between two fights', (tester) async {
    // Arrange: one fight running, one queued behind it
    await pumpBoard(tester, matches: [
      _match('aaaa', MatchStatus.inProgress),
      _match('bbbb', MatchStatus.waiting),
    ]);
    expect(wakelock.held, isTrue);

    // Act: the running one ends and nobody touches the phone. This is the whole
    // bug — a spectator casting the board to a TV had to re-share the screen
    // every time the mat took a minute between fights.
    await setBoard(tester, [
      _match('aaaa', MatchStatus.finished),
      _match('bbbb', MatchStatus.waiting),
    ]);

    // Assert
    expect(wakelock.held, isTrue);
  });

  testWidgets('holds it for a board that has not started yet', (tester) async {
    // Arrange + Act: the organizer has posted the card, the mat has not begun
    await pumpBoard(tester, matches: [_match('aaaa', MatchStatus.waiting)]);

    // Assert
    expect(wakelock.held, isTrue);
  });

  testWidgets('lets it sleep once every fight on the board is done',
      (tester) async {
    // Arrange
    await pumpBoard(tester, matches: [_match('aaaa', MatchStatus.inProgress)]);
    expect(wakelock.held, isTrue);

    // Act: the last fight of the event ends
    await setBoard(tester, [_match('aaaa', MatchStatus.finished)]);

    // Assert: a board nobody is going to update should not pin the display of a
    // phone left face-up on a table
    expect(wakelock.held, isFalse);
  });

  testWidgets('lets it sleep when every fight left was canceled',
      (tester) async {
    // Arrange + Act
    await pumpBoard(tester, matches: [_match('aaaa', MatchStatus.canceled)]);

    // Assert: canceled is as over as finished — there is nothing coming
    expect(wakelock.requests, everyElement(isFalse));
  });

  testWidgets('never holds it with no board being watched', (tester) async {
    // Arrange + Act
    await pumpBoard(tester);

    // Assert: the welcome screen is not a reason to keep a phone awake
    expect(wakelock.held, isNot(isTrue));
  });

  testWidgets('holds it even while the status filter hides the live fights',
      (tester) async {
    // Arrange
    await pumpBoard(tester, matches: [_match('aaaa', MatchStatus.inProgress)]);

    // Act: the spectator looks through today's results instead of the mat
    ref.read(scoreboardStatusFilterProvider.notifier).state = {
      MatchStatus.finished,
    };
    await tester.pump();

    // Assert: which statuses the list shows is a display choice. The event is
    // still live, and the phone still has to stay awake for it.
    expect(wakelock.held, isTrue);
  });

  testWidgets('lets it sleep while the user is on another tab', (tester) async {
    // Arrange + Act: a live board, but the user is reading settings
    await pumpBoard(
      tester,
      matches: [_match('aaaa', MatchStatus.inProgress)],
      tab: AppTab.settings,
    );

    // Assert: this screen stays alive in the IndexedStack behind every other
    // tab, so voting on the feed alone would hold the display up for a board
    // nobody is looking at.
    expect(wakelock.requests, everyElement(isFalse));
  });

  testWidgets('picks the hold up again when the user comes back to the board',
      (tester) async {
    // Arrange
    await pumpBoard(
      tester,
      matches: [_match('aaaa', MatchStatus.inProgress)],
      tab: AppTab.home,
    );
    expect(wakelock.held, isNot(isTrue));

    // Act
    await selectTab(tester, AppTab.scoreboard);

    // Assert
    expect(wakelock.held, isTrue);
  });

  testWidgets('drops the hold when the user leaves for another tab',
      (tester) async {
    // Arrange
    await pumpBoard(tester, matches: [_match('aaaa', MatchStatus.inProgress)]);
    expect(wakelock.held, isTrue);

    // Act
    await selectTab(tester, AppTab.account);

    // Assert
    expect(wakelock.held, isFalse);
  });

  testWidgets('lets it sleep when the screen is torn down', (tester) async {
    // Arrange
    await pumpBoard(tester, matches: [_match('aaaa', MatchStatus.inProgress)]);
    expect(wakelock.held, isTrue);

    // Act
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    // Assert
    expect(wakelock.held, isFalse);
  });
}
