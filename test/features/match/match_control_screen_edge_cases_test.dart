import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/match/match_control_screen.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/features/match/providers/match_control_provider.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/services/wakelock/screen_wakelock.dart';
import 'package:choke/shared/theme/app_theme.dart';

import '../../support/nostr_fakes.dart';

/// Fake NostrService that skips relay publishing; [gate] holds a publish in
/// flight until completed (slow relay).
class _FakeNostrService extends NostrService {
  _FakeNostrService()
      : super(KeyManager(crypto: FakeNostrCrypto()),
            crypto: FakeNostrCrypto(), backend: FakeRelayBackend());

  Completer<void>? gate;

  @override
  Future<void> publishAddressableEvent({
    required String dTag,
    required String content,
    List<List<String>> additionalTags = const [],
  }) async {
    final g = gate;
    if (g != null) await g.future;
  }
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

/// Hold a rail button until the subtract fires, as a referee does.
Future<void> hold(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  await tester.pump(); // first ticker frame (t = 0)
  await tester.pump(const Duration(milliseconds: 1100));
  await gesture.up();
  await tester.pump();
}

void main() {
  late MatchControlNotifier notifier;
  late _FakeNostrService nostr;
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    nostr = _FakeNostrService();
  });

  Widget wrap(Widget home, Match match) {
    notifier = MatchControlNotifier(match, nostr);
    return ProviderScope(
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
        home: home,
      ),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, Match match) async {
    // Landscape phone viewport
    tester.view.physicalSize = const Size(1600, 740);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(MatchControlScreen(match: match), match));
  }

  /// Pump a host page with the control screen pushed on top, so popping has
  /// somewhere to land — as it does in the app.
  Future<void> pumpPushed(WidgetTester tester, Match match) async {
    tester.view.physicalSize = const Size(1600, 740);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => MatchControlScreen(match: match)),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
      match,
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  group('the full scoring rails', () {
    testWidgets('+3, +4, advantage and penalty all score their fighter',
        (tester) async {
      // Arrange
      await pumpScreen(tester, _runningMatch());

      // Act — one of each on fighter 1's rail
      await tester.tap(find.text('+3').first);
      await tester.tap(find.text('+4').first);
      await tester.tap(find.text(l10n.advantage.toUpperCase()).first);
      await tester.tap(find.text(l10n.penalty.toUpperCase()).first);
      await tester.pump();

      // Assert
      final match = notifier.state.match;
      expect(match.f1Pt3, 1);
      expect(match.f1Pt4, 1);
      expect(match.f1Adv, 1);
      expect(match.f1Pen, 1);
    });

    testWidgets('holding any rail button takes the score back off',
        (tester) async {
      // Arrange — one of each already on the card (mis-taps happen)
      await pumpScreen(
        tester,
        _runningMatch().copyWith(f1Pt3: 1, f1Pt4: 1, f1Adv: 1, f1Pen: 1),
      );

      // Act — hold each button for over a second
      await hold(tester, find.text('+3').first);
      await hold(tester, find.text('+4').first);
      await hold(tester, find.text(l10n.advantage.toUpperCase()).first);
      await hold(tester, find.text(l10n.penalty.toUpperCase()).first);

      // Assert — every mis-tap is reversible from the same button
      final match = notifier.state.match;
      expect(match.f1Pt3, 0);
      expect(match.f1Pt4, 0);
      expect(match.f1Adv, 0);
      expect(match.f1Pen, 0);
    });
  });

  group('publish indicator', () {
    testWidgets('a spinner shows while a publish is in flight', (tester) async {
      // Arrange — a slow relay holds the publish open
      nostr.gate = Completer<void>();
      await pumpScreen(tester, _runningMatch());
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Act — a score goes out
      await tester.tap(find.text('+2').first);
      await tester.pump();

      // Assert — the referee can see the board has not converged yet
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Act — the relay accepts
      nostr.gate!.complete();
      nostr.gate = null;
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('clock expiry while the screen is up', () {
    testWidgets('a level match whose clock runs out asks for the outcome',
        (tester) async {
      // Arrange — a waiting zero-duration match: the shortest possible route
      // to "the clock expired underneath the open screen"
      final waiting = _runningMatch().copyWith(
        status: MatchStatus.waiting,
        startAt: null,
        duration: 0,
      );
      await pumpScreen(tester, waiting);

      // Act — start it; regulation time is instantly over, and the score is
      // level, so the scoreboard cannot decide it
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      // Assert — asked, not decided: inventing a winner the data does not
      // have is exactly what this sheet exists to prevent
      expect(notifier.state.awaitsOutcome, isTrue);
      expect(find.text(l10n.outcomeTitle), findsOneWidget);
      expect(notifier.state.match.status, MatchStatus.inProgress);
    });
  });

  group('leaving the screen', () {
    testWidgets('the back button simply leaves a match that is not running',
        (tester) async {
      // Arrange — a waiting match: nothing on it can be lost yet
      final waiting = _runningMatch().copyWith(
        status: MatchStatus.waiting,
        startAt: null,
      );
      await pumpPushed(tester, waiting);
      expect(find.byType(MatchControlScreen), findsOneWidget);

      // Act
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Assert — no dialog in the way
      expect(find.byType(MatchControlScreen), findsNothing);
    });

    testWidgets(
        'the back button asks before leaving a running match, '
        'and Stay stays', (tester) async {
      // Arrange — leaving mid-match abandons a live scoreboard
      await pumpPushed(tester, _runningMatch());

      // Act
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(l10n.leaveMatchQuestion), findsOneWidget);

      // Act — the referee thinks better of it
      await tester.tap(find.text(l10n.stay));
      await tester.pumpAndSettle();

      // Assert — still refereeing
      expect(find.text(l10n.leaveMatchQuestion), findsNothing);
      expect(find.byType(MatchControlScreen), findsOneWidget);
    });

    testWidgets('Leave leaves the running match', (tester) async {
      // Arrange
      await pumpPushed(tester, _runningMatch());
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Act — confirmed on purpose
      await tester.tap(find.text(l10n.leave));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(MatchControlScreen), findsNothing);
    });

    testWidgets('the system back gesture is intercepted the same way',
        (tester) async {
      // Arrange — Android back must not be a loophole around the guard
      await pumpScreen(tester, _runningMatch());

      // Act
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Assert — same question, same protection
      expect(find.text(l10n.leaveMatchQuestion), findsOneWidget);
    });
  });
}
