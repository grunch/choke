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

/// Fake NostrService that skips relay publishing entirely
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

Match _runningMatch() {
  return Match(
    id: 'abcd',
    status: MatchStatus.inProgress,
    startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    duration: 300,
    f1Name: 'Pana',
    f2Name: 'Buchecha',
    f1Color: '#1BA34E',
    f2Color: '#F5B800',
  );
}

/// Hold the Finish button until it fires, as a referee does.
Future<void> holdFinish(WidgetTester tester, AppLocalizations l10n) async {
  final label = '${l10n.finish} · ${l10n.holdHint}';
  final gesture = await tester.startGesture(tester.getCenter(find.text(label)));
  await tester.pump(); // first ticker frame (t = 0)
  await tester.pump(const Duration(milliseconds: 1100));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  late MatchControlNotifier notifier;

  setUp(() {
    // The submission list is persisted, so adding one from the picker writes to
    // SharedPreferences — a plugin that does not exist in a widget test unless
    // it is mocked.
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester, Match match) async {
    // Landscape phone viewport
    tester.view.physicalSize = const Size(1600, 740);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    notifier = MatchControlNotifier(match, _FakeNostrService());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchControlProvider.overrideWith((ref) => notifier),
          // The real one talks to a method channel that nothing answers in a
          // test, leaving a call pending for as long as the process lives.
          screenWakelockProvider.overrideWithValue(const NoopScreenWakelock()),
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

  testWidgets('shows both fighters with their own scoring rails',
      (tester) async {
    // Arrange + Act
    await pumpScreen(tester, _runningMatch());

    // Assert
    expect(find.text('Pana'), findsOneWidget);
    expect(find.text('Buchecha'), findsOneWidget);
    expect(find.text('+2'), findsNWidgets(2));
    expect(find.text('+3'), findsNWidgets(2));
    expect(find.text('+4'), findsNWidgets(2));
  });

  testWidgets('tapping +2 on fighter 1 rail adds two points', (tester) async {
    // Arrange
    await pumpScreen(tester, _runningMatch());

    // Act
    await tester.tap(find.text('+2').first);
    await tester.pump();

    // Assert
    expect(notifier.state.match.f1Score, 2);
    expect(notifier.state.match.f2Score, 0);
  });

  testWidgets('holding +2 on fighter 1 rail subtracts two points',
      (tester) async {
    // Arrange
    await pumpScreen(tester, _runningMatch());
    await tester.tap(find.text('+2').first);
    await tester.tap(find.text('+2').first);
    await tester.pump();
    expect(notifier.state.match.f1Score, 4);

    // Act: press and hold for over a second
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('+2').first));
    await tester.pump(); // first ticker frame (t = 0)
    await tester.pump(const Duration(milliseconds: 1100));
    await gesture.up();
    await tester.pump();

    // Assert
    expect(notifier.state.match.f1Score, 2);
  });

  testWidgets('holding finish asks how the match ended', (tester) async {
    // Arrange
    await pumpScreen(tester, _runningMatch());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Act
    await holdFinish(tester, l10n);

    // Assert — the hold no longer ends the match on its own. A match that
    // stopped with only a status would publish a scoreboard that can name the
    // wrong fighter, which is the bug this sheet exists to remove.
    expect(notifier.state.match.status, MatchStatus.inProgress);
    expect(find.text(l10n.outcomeTitle), findsOneWidget);
  });

  testWidgets('a submission ends the match against the scoreboard',
      (tester) async {
    // Arrange — Pana leads 4–0…
    await pumpScreen(tester, _runningMatch().copyWith(f1Pt4: 1));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Act — …and Buchecha submits him. Two taps: the method, then the fighter.
    await holdFinish(tester, l10n);
    await tester.tap(find.text(l10n.outcomeSubmission));
    await tester.pumpAndSettle();
    // The fighter's own colour, in a dialog — not the name on the scoreboard,
    // which reads identically.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Buchecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.skip)); // the technique is optional
    await tester.pumpAndSettle();

    // Assert — the fighter who was losing on the scoreboard is the winner
    final match = notifier.state.match;
    expect(match.status, MatchStatus.finished);
    expect(match.winner, MatchWinner.f2);
    expect(match.method, MatchMethod.submission);
    expect(match.f1Score, 4, reason: 'the raw record is still the record');
  });

  testWidgets('the technique is tapped, never typed', (tester) async {
    // Arrange — the screen is locked to landscape, where the on-screen keyboard
    // covers the dialog and a referee is typing one-handed over two people on
    // the mat. That is the whole reason the techniques are chips.
    await pumpScreen(tester, _runningMatch());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Act — finish by submission, pick the fighter
    await holdFinish(tester, l10n);
    await tester.tap(find.text(l10n.outcomeSubmission));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Buchecha'));
    await tester.pumpAndSettle();

    // Assert — the techniques are there to tap, and nothing asks for the keyboard
    expect(find.text(l10n.subArmbar), findsOneWidget);
    expect(find.text(l10n.subRearNakedChoke), findsOneWidget);
    expect(
      find.byType(TextField),
      findsNothing,
      reason: 'a keyboard in landscape is exactly what this replaced',
    );

    // Act — one tap on the technique
    await tester.tap(find.text(l10n.subArmbar));
    await tester.pumpAndSettle();

    // Assert — the referee tapped 'Armbar'; the event says `armbar`, which is
    // what a scoreboard in any language reads back.
    final match = notifier.state.match;
    expect(match.method, MatchMethod.submission);
    expect(match.submission, 'armbar');
  });

  testWidgets('a technique the app has never heard of is still recordable',
      (tester) async {
    // Arrange — no list survives contact with BJJ, so the escape hatch lives in
    // the picker itself: a referee finds out a technique is missing at the
    // moment they look for it, with two fighters waiting. Settings is not an
    // answer to that.
    await pumpScreen(tester, _runningMatch());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await holdFinish(tester, l10n);
    await tester.tap(find.text(l10n.outcomeSubmission));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Buchecha'));
    await tester.pumpAndSettle();

    // Act — 'Other…', then type it
    await tester.tap(find.text(l10n.outcomeSubmissionOther));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'baratoplata');
    await tester.tap(find.text(l10n.outcomeConfirm));
    await tester.pumpAndSettle();

    // Assert — recorded verbatim, in one pass, without leaving the mat
    final match = notifier.state.match;
    expect(match.status, MatchStatus.finished);
    expect(match.method, MatchMethod.submission);
    expect(match.submission, 'baratoplata');
  });

  testWidgets('the scoreboard result is one tap', (tester) async {
    // Arrange — Pana is ahead, so the sheet offers exactly that
    await pumpScreen(tester, _runningMatch().copyWith(f1Pt2: 1));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Act
    await holdFinish(tester, l10n);
    await tester.tap(find.textContaining(l10n.outcomePoints));
    await tester.pumpAndSettle();

    // Assert
    expect(notifier.state.match.winner, MatchWinner.f1);
    expect(notifier.state.match.method, MatchMethod.points);
  });

  testWidgets('dismissing the sheet leaves the match open', (tester) async {
    // Arrange — a referee who opened it by mistake, or who wants to fix the
    // score first
    await pumpScreen(tester, _runningMatch());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await holdFinish(tester, l10n);

    // Act
    await tester.tapAt(const Offset(10, 10)); // the scrim
    await tester.pumpAndSettle();

    // Assert — an undecided match is not a finished one
    expect(notifier.state.match.status, MatchStatus.inProgress);
    expect(notifier.state.match.winner, isNull);
  });

  testWidgets('the scoreboard shows the points a penalty conceded',
      (tester) async {
    // Arrange — Buchecha has three penalties, which give Pana two points
    await pumpScreen(tester, _runningMatch().copyWith(f1Pt2: 1, f2Pen: 3));

    // Assert — 2 scored + 2 conceded. Seeing that jump is how the referee knows
    // the penalty landed; the penalty badge still shows Buchecha's raw count.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('P:3'), findsOneWidget);
  });

  testWidgets(
      'waiting match shows an inline start button, not a blocking overlay',
      (tester) async {
    // Arrange — a freshly created match, not yet started
    final waiting = _runningMatch().copyWith(
      status: MatchStatus.waiting,
      startAt: null,
    );

    // Act
    await pumpScreen(tester, waiting);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Assert — the blocking overlay is gone (no full "Start match" text button);
    // instead the clock's play button offers the start, and the match content
    // stays visible so the referee can review the fighters before starting.
    expect(find.text(l10n.startMatch), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.text('Pana'), findsWidgets);
    expect(find.text('Buchecha'), findsWidgets);
  });

  testWidgets('tapping the play button starts a waiting match', (tester) async {
    // Arrange
    final waiting = _runningMatch().copyWith(
      status: MatchStatus.waiting,
      startAt: null,
    );
    await pumpScreen(tester, waiting);

    // Act — the same control used for pause/resume starts the match
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    // Assert
    expect(notifier.state.match.status, MatchStatus.inProgress);
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('a waiting match can be cancelled without starting it',
      (tester) async {
    // Arrange — a match created with wrong details, not yet started
    final waiting = _runningMatch().copyWith(
      status: MatchStatus.waiting,
      startAt: null,
    );
    await pumpScreen(tester, waiting);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Act — hold the Cancel button as a referee would
    final label = '${l10n.cancel} · ${l10n.holdHint}';
    final gesture =
        await tester.startGesture(tester.getCenter(find.text(label)));
    await tester.pump(); // first ticker frame (t = 0)
    await tester.pump(const Duration(milliseconds: 1100));
    await gesture.up();
    await tester.pumpAndSettle();

    // Assert — cancelled without ever starting
    expect(notifier.state.match.status, MatchStatus.canceled);
  });

  testWidgets('running match offers a pause button next to the clock',
      (tester) async {
    // Arrange + Act
    await pumpScreen(tester, _runningMatch());

    // Assert
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('tapping pause stops the clock and offers resume',
      (tester) async {
    // Arrange
    await pumpScreen(tester, _runningMatch());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Act
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    // Assert
    expect(notifier.state.isPaused, isTrue);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text(l10n.statusPaused), findsOneWidget);
  });

  testWidgets('tapping resume restarts the clock', (tester) async {
    // Arrange
    await pumpScreen(tester, _runningMatch());
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    // Act
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    // Assert
    expect(notifier.state.isPaused, isFalse);
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('a waiting match has no pause button', (tester) async {
    // Arrange
    final waiting = _runningMatch().copyWith(
      status: MatchStatus.waiting,
      startAt: null,
    );

    // Act
    await pumpScreen(tester, waiting);

    // Assert
    expect(find.byIcon(Icons.pause), findsNothing);
  });

  testWidgets('scoring rails stay live while paused', (tester) async {
    // Arrange
    await pumpScreen(tester, _runningMatch());
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    // Act — the referee awards a takedown during the stoppage
    await tester.tap(find.text('+2').first);
    await tester.pump();

    // Assert
    expect(notifier.state.match.f1Score, 2);
  });

  testWidgets('a finished match says how it ended, not just that it did',
      (tester) async {
    // Arrange — Pana leads 4–0 on the scoreboard, and lost to an armbar
    final startAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 180;
    final finished = _runningMatch().copyWith(
      status: MatchStatus.finished,
      startAt: startAt,
      f1Pt4: 1,
      winner: MatchWinner.f2,
      method: MatchMethod.submission,
      submission: 'armbar',
      endedAt: startAt + 120,
    );
    await pumpScreen(tester, finished);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Assert — the footer names the fighter who won, not the bigger number, and
    // names the technique in the reader's language. The event carries the
    // canonical `armbar`; a human reads 'Armbar' here and 腕十字固め in Tokyo,
    // off the same event.
    expect(
      find.text('Buchecha · ${l10n.outcomeSubmissionOf(l10n.subArmbar)}'),
      findsOneWidget,
    );
    expect(finished.submission, 'armbar', reason: 'the wire stays canonical');
  });

  testWidgets('a wrong result can be corrected', (tester) async {
    // Arrange — the clock closed it on points, against the wrong fighter (a
    // penalty entered against the wrong man, say). Without this, the mistake is
    // published and permanent.
    final startAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 300;
    final finished = _runningMatch().copyWith(
      status: MatchStatus.finished,
      startAt: startAt,
      f1Pt2: 1,
      winner: MatchWinner.f1,
      method: MatchMethod.points,
      endedAt: startAt + 300,
    );
    await pumpScreen(tester, finished);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Act
    await tester.tap(find.text(l10n.outcomeAmend));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.outcomeSubmission));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Buchecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.skip));
    await tester.pumpAndSettle();

    // Assert — the result is replaced, and republished: the event is
    // addressable, so the correction supersedes the mistake on every relay
    final match = notifier.state.match;
    expect(match.winner, MatchWinner.f2);
    expect(match.method, MatchMethod.submission);
    expect(match.status, MatchStatus.finished);
  });

  testWidgets('a canceled match has nothing to amend', (tester) async {
    // Arrange — a canceled match is not a result; it is the absence of one
    final canceled = _runningMatch().copyWith(status: MatchStatus.canceled);
    await pumpScreen(tester, canceled);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Assert
    expect(find.text(l10n.outcomeAmend), findsNothing);
  });

  testWidgets('reopening a match whose clock already expired asks at once',
      (tester) async {
    // Arrange — the referee closed the app mid-match and came back. The
    // notifier settles the expiry in its constructor, before this screen
    // exists, so a listener that only reports *changes* would never fire — and
    // the match would sit dead at 00:00 until someone thought to hold Finish.
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expired = _runningMatch().copyWith(
      duration: 300,
      startAt: now - 600, // level, so it cannot decide itself
    );

    // Act
    await pumpScreen(tester, expired);
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Assert
    expect(notifier.state.awaitsOutcome, isTrue);
    expect(find.text(l10n.outcomeTitle), findsOneWidget);
  });

  testWidgets(
      'an outcome chosen after the match finished behind the sheet is '
      'not lost', (tester) async {
    // Arrange — the referee opens the sheet, and the clock runs out underneath
    // it: the notifier finishes the match on points, on its own, while the
    // sheet is still up. (Driven directly here, because the provider's clock
    // reads the real wall clock and cannot be advanced by the test.)
    await pumpScreen(tester, _runningMatch().copyWith(f1Pt2: 1));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await holdFinish(tester, l10n);

    notifier.finishWith(
      const MatchOutcome.onScoreboard(MatchWinner.f1, MatchMethod.points),
    );
    await tester.pump();

    // Act — and *then* the referee says it was a submission, by the other man
    await tester.tap(find.text(l10n.outcomeSubmission));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Buchecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.skip));
    await tester.pumpAndSettle();

    // Assert — the referee's answer wins. Deciding from the state the sheet was
    // *opened* with would have called finishWith on a match that was already
    // finished — a silent no-op — and the submission would simply have
    // vanished, leaving the wrong fighter published as the winner.
    final match = notifier.state.match;
    expect(match.winner, MatchWinner.f2);
    expect(match.method, MatchMethod.submission);
  });
}
