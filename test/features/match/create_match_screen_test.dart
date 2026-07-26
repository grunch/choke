import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/match/create_match_screen.dart';
import 'package:choke/features/match/match_control_screen.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/services/wakelock/screen_wakelock.dart';
import 'package:choke/shared/theme/app_theme.dart';

import '../../support/nostr_fakes.dart';

/// Fake NostrService that records publishes instead of hitting relays.
///
/// [failuresRemaining] makes the next N publishes throw (relay down).
/// [gate] holds a publish in flight until completed (slow relay).
class _FakeNostrService extends NostrService {
  _FakeNostrService()
      : super(KeyManager(crypto: FakeNostrCrypto()),
            crypto: FakeNostrCrypto(), backend: FakeRelayBackend());

  int publishCount = 0;
  final List<String> publishedContents = [];
  int failuresRemaining = 0;
  Completer<void>? gate;

  Match get lastPublishedMatch => Match.fromJsonString(publishedContents.last);

  @override
  Future<void> publishAddressableEvent({
    required String dTag,
    required String content,
    List<List<String>> additionalTags = const [],
  }) async {
    final g = gate;
    if (g != null) await g.future;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw Exception('relay down');
    }
    publishCount++;
    publishedContents.add(content);
  }
}

void main() {
  late _FakeNostrService nostr;
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    // The duration provider and the match-control screen both persist through
    // SharedPreferences, which needs mocking in a widget test.
    SharedPreferences.setMockInitialValues({});
    nostr = _FakeNostrService();
  });

  Widget wrap(Widget home) {
    return ProviderScope(
      overrides: [
        nostrServiceProvider.overrideWithValue(nostr),
        // Creating a match lands on the control screen, which holds the screen
        // awake. The real one talks to a method channel nothing answers here,
        // and its timeout would outlive the test as a pending timer.
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

  Future<void> pumpScreen(WidgetTester tester) async {
    // A viewport tall and wide enough for both this form and the landscape
    // control screen it navigates to.
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const CreateMatchScreen()));
  }

  Future<void> enterNames(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Pana');
    await tester.enterText(find.byType(TextFormField).at(1), 'Buchecha');
  }

  /// The tappable color dot of [color], one per fighter card.
  Finder colorDot(Color color) {
    return find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          decoration.color == color;
    });
  }

  testWidgets('renders both fighter cards, durations and the create button',
      (tester) async {
    // Arrange + Act
    await pumpScreen(tester);

    // Assert — everything a referee needs to set up a bout is on one screen
    expect(find.text(l10n.newMatch), findsOneWidget);
    expect(find.text(l10n.fighter1.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.fighter2.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.vs.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.matchDuration.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.createMatch), findsOneWidget);
    // Every duration up to 10:00 is reachable without scrolling a carousel
    expect(find.text('03:00'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
  });

  testWidgets('empty fighter names block creation with a message each',
      (tester) async {
    // Arrange
    await pumpScreen(tester);

    // Act — the referee taps Create without naming anyone
    await tester.tap(find.text(l10n.createMatch));
    await tester.pump();

    // Assert — both fields say so, and nothing was published: a nameless
    // match on the relays would be an unidentifiable scoreboard
    expect(find.text(l10n.fighter1NameRequired), findsOneWidget);
    expect(find.text(l10n.fighter2NameRequired), findsOneWidget);
    expect(nostr.publishCount, 0);
  });

  testWidgets('whitespace-only names are not names', (tester) async {
    // Arrange
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '   ');
    await tester.enterText(find.byType(TextFormField).at(1), 'Buchecha');

    // Act
    await tester.tap(find.text(l10n.createMatch));
    await tester.pump();

    // Assert
    expect(find.text(l10n.fighter1NameRequired), findsOneWidget);
    expect(nostr.publishCount, 0);
  });

  testWidgets('creating publishes the match and moves to the control screen',
      (tester) async {
    // Arrange
    await pumpScreen(tester);
    await enterNames(tester);

    // Act
    await tester.tap(find.text(l10n.createMatch));
    await tester.pumpAndSettle();

    // Assert — published once with the defaults, then straight to the mat
    expect(find.byType(MatchControlScreen), findsOneWidget);
    expect(nostr.publishCount, 1);
    final match = nostr.lastPublishedMatch;
    expect(match.f1Name, 'Pana');
    expect(match.f2Name, 'Buchecha');
    expect(match.status, MatchStatus.waiting,
        reason: 'created, not started — the referee starts it on the mat');
    expect(match.duration, 300, reason: 'the default duration is 5:00');
    expect(match.f1Color, '#1BA34E', reason: 'palette default: green');
    expect(match.f2Color, '#F5B800', reason: 'palette default: gold');
  });

  testWidgets('a tapped duration is the duration that is published',
      (tester) async {
    // Arrange
    await pumpScreen(tester);
    await enterNames(tester);

    // Act — pick the longest option, then create
    await tester.ensureVisible(find.text('10:00'));
    await tester.tap(find.text('10:00'));
    await tester.pump();
    await tester.tap(find.text(l10n.createMatch));
    await tester.pumpAndSettle();

    // Assert
    expect(nostr.lastPublishedMatch.duration, 600);
  });

  testWidgets('tapped color dots become the published fighter colors',
      (tester) async {
    // Arrange
    await pumpScreen(tester);
    await enterNames(tester);

    // Act — purple for fighter 1, white for fighter 2 (each card has its
    // own row of dots; first match is fighter 1's card, last is fighter 2's)
    await tester.tap(colorDot(BJJColors.purple).first);
    await tester.pump();
    await tester.tap(colorDot(BJJColors.white).last);
    await tester.pump();
    await tester.tap(find.text(l10n.createMatch));
    await tester.pumpAndSettle();

    // Assert — the hex on the wire is exactly the dot that was tapped, so
    // every other device shows the fighters in the colors the referee chose
    final match = nostr.lastPublishedMatch;
    expect(match.f1Color, '#9C27B0');
    expect(match.f2Color, '#FFFFFF');
  });

  testWidgets('a failed publish offers retry instead of losing the match',
      (tester) async {
    // Arrange — the relay rejects the first attempt
    nostr.failuresRemaining = 1;
    await pumpScreen(tester);
    await enterNames(tester);

    // Act
    await tester.tap(find.text(l10n.createMatch));
    await tester.pumpAndSettle();

    // Assert — still on the form, told why, offered a way forward
    expect(find.byType(MatchControlScreen), findsNothing);
    expect(find.text(l10n.couldNotPublishMatch), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);

    // Act — the referee taps retry once the relay is back
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    // Assert — the retry publishes and proceeds; nothing was typed twice
    expect(nostr.publishCount, 1);
    expect(find.byType(MatchControlScreen), findsOneWidget);
  });

  testWidgets('the create button shows progress while the publish is in flight',
      (tester) async {
    // Arrange — a slow relay
    nostr.gate = Completer<void>();
    await pumpScreen(tester);
    await enterNames(tester);

    // Act
    await tester.tap(find.text(l10n.createMatch));
    await tester.pump();

    // Assert — a spinner replaces the label so the button cannot be
    // double-tapped into publishing two matches
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(l10n.createMatch), findsNothing);

    // Act — the relay answers
    nostr.gate!.complete();
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(MatchControlScreen), findsOneWidget);
  });

  testWidgets('the back button returns without creating anything',
      (tester) async {
    // Arrange — the screen is pushed on top of a host page, as in the app
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateMatchScreen()),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateMatchScreen), findsOneWidget);

    // Act
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    // Assert — back on the host, and nothing went out to the relays
    expect(find.byType(CreateMatchScreen), findsNothing);
    expect(nostr.publishCount, 0);
  });
}
