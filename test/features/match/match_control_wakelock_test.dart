import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/match/match_control_screen.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/features/match/models/match_outcome.dart';
import 'package:choke/features/match/providers/match_control_provider.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/services/wakelock/screen_wakelock.dart';
import 'package:choke/shared/theme/app_theme.dart';

import '../../support/nostr_fakes.dart';

/// Fake NostrService that skips relay publishing entirely.
class _FakeNostrService extends NostrService {
  _FakeNostrService()
      : super(KeyManager(crypto: FakeNostrCrypto()),
            crypto: FakeNostrCrypto(), backend: FakeRelayBackend());

  @override
  Future<void> publishAddressableEvent({
    required String dTag,
    required String content,
    List<List<String>> additionalTags = const [],
  }) async {}
}

/// Records what the screen asked of the platform, in order.
///
/// Every request is kept, including repeats. Deduplicating here — which is what
/// the real implementation does internally — would hide the screen's actual
/// behaviour behind the fake and make "it was never asked twice" impossible to
/// observe, so that guarantee is tested against the service instead.
class _RecordingWakelock implements ScreenWakelock {
  final List<bool> requests = [];

  /// Whether the screen is being held awake, or null if the screen never asked
  /// for anything either way.
  bool? get held => requests.isEmpty ? null : requests.last;

  @override
  Future<void> keepAwake(bool on) async => requests.add(on);
}

Match _runningMatch() => Match(
      id: 'abcd',
      status: MatchStatus.inProgress,
      startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      duration: 300,
      f1Name: 'Pana',
      f2Name: 'Buchecha',
      f1Color: '#1BA34E',
      f2Color: '#F5B800',
    );

void main() {
  late _RecordingWakelock wakelock;
  late MatchControlNotifier notifier;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    wakelock = _RecordingWakelock();
  });

  Future<void> pumpScreen(WidgetTester tester, Match match) async {
    // Landscape phone viewport, which is what the match screen locks itself to.
    tester.view.physicalSize = const Size(1600, 740);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    notifier = MatchControlNotifier(match, _FakeNostrService());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchControlProvider.overrideWith((ref) => notifier),
          screenWakelockProvider.overrideWithValue(wakelock),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MatchControlScreen(match: match),
        ),
      ),
    );
  }

  testWidgets('holds the screen awake while a match is on the mat',
      (tester) async {
    // Arrange + Act
    await pumpScreen(tester, _runningMatch());

    // Assert: a minute with no scoring must not put the phone to sleep
    expect(wakelock.held, isTrue);
  });

  testWidgets('keeps holding it through a minute of no scoring at all',
      (tester) async {
    // Arrange
    await pumpScreen(tester, _runningMatch());

    // Act: nothing happens on the mat for a minute
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // Assert: never once asked to let the screen go, which is the whole point
    expect(wakelock.held, isTrue);
    expect(wakelock.requests, everyElement(isTrue));
  });

  testWidgets('re-asserts the hold as the clock ticks, so a dropped request '
      'gets made again', (tester) async {
    // Arrange
    await pumpScreen(tester, _runningMatch());
    final atStart = wakelock.requests.length;

    // Act
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Assert: the screen keeps asking rather than assuming the first one landed
    // — a platform that refused the hold gets another chance every second.
    expect(wakelock.requests.length, greaterThan(atStart));
  });

  testWidgets('holds it while the clock is paused', (tester) async {
    // Arrange
    await pumpScreen(tester, _runningMatch());

    // Act: fighters off the mat, referee conferring
    notifier.pauseMatch();
    await tester.pump();

    // Assert
    expect(wakelock.held, isTrue);
  });

  testWidgets('lets the screen sleep once the match is over', (tester) async {
    // Arrange
    await pumpScreen(tester, _runningMatch());
    expect(wakelock.held, isTrue);

    // Act
    notifier.finishWith(
      const MatchOutcome(winner: MatchWinner.f1, method: MatchMethod.points),
    );
    await tester.pump();

    // Assert: the result can sit on the table without draining the battery
    expect(wakelock.held, isFalse);
  });

  testWidgets('lets it sleep when the referee leaves the screen',
      (tester) async {
    // Arrange
    await pumpScreen(tester, _runningMatch());
    expect(wakelock.held, isTrue);

    // Act: navigate away, tearing the screen down
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    // Assert
    expect(wakelock.held, isFalse);
  });

  testWidgets('never holds it for a match that is already decided',
      (tester) async {
    // Arrange + Act: opening a finished match to check or amend the result
    await pumpScreen(
      tester,
      _runningMatch().copyWith(
        status: MatchStatus.finished,
        winner: MatchWinner.f1,
        method: MatchMethod.points,
        endedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ),
    );

    // Assert: never asked for a hold at all, not even once
    expect(wakelock.requests, everyElement(isFalse));
    expect(wakelock.held, isNot(isTrue));
  });
}
