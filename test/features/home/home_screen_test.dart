import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/home/home_screen.dart';
import 'package:choke/features/home/providers/home_providers.dart';
import 'package:choke/features/match/create_match_screen.dart';
import 'package:choke/features/match/match_control_screen.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/features/match/providers/match_control_provider.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/services/wakelock/screen_wakelock.dart';
import 'package:choke/shared/theme/app_theme.dart';

import '../../support/nostr_fakes.dart';

/// A NostrService that never reaches a relay, so tapping into the match
/// control screen cannot try to publish anything.
class _FakeNostrService extends NostrService {
  _FakeNostrService()
      : super(
          KeyManager(crypto: FakeNostrCrypto()),
          crypto: FakeNostrCrypto(),
          backend: FakeRelayBackend(),
        );

  @override
  Future<void> publishAddressableEvent({
    required String dTag,
    required String content,
    List<List<String>> additionalTags = const [],
  }) async {}
}

Match _match({
  required String id,
  required MatchStatus status,
  int f1Pt2 = 0,
  int f1Adv = 0,
  int f1Pen = 0,
  int f2Pt2 = 0,
  int f2Adv = 0,
  int f2Pen = 0,
  MatchWinner? winner,
  MatchMethod? method,
  String? submission,
  int? endedAt,
}) {
  return Match(
    id: id,
    status: status,
    startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    duration: 300,
    f1Name: 'Pana',
    f2Name: 'Buchecha',
    f1Color: '#1BA34E',
    f2Color: '#F5B800',
    f1Pt2: f1Pt2,
    f1Adv: f1Adv,
    f1Pen: f1Pen,
    f2Pt2: f2Pt2,
    f2Adv: f2Adv,
    f2Pen: f2Pen,
    winner: winner,
    method: method,
    submission: submission,
    endedAt: endedAt,
  );
}

void main() {
  late AppLocalizations l10n;
  late ProviderContainer container;
  late _FakeNostrService service;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = _FakeNostrService();
    container = ProviderContainer(
      overrides: [
        nostrServiceProvider.overrideWithValue(service),
        matchControlProvider.overrideWith(
          (ref) => MatchControlNotifier(
            _match(id: 'aaaa', status: MatchStatus.inProgress),
            service,
          ),
        ),
        // Tapping through to the control screen would otherwise reach a real
        // method channel that nothing answers in a test.
        screenWakelockProvider.overrideWithValue(const NoopScreenWakelock()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    service.dispose();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    // A tall phone viewport so the list, cards and FAB all fit
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  void addMatch(Match match) {
    container.read(matchFeedProvider.notifier).addLocal(match);
  }

  /// The tappable status filter card, found by the accessibility label it
  /// exposes: "<status>: <count>".
  Finder statusCard(String label, int count) => find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '$label: $count',
      );

  testWidgets('shows the empty state when no match exists', (tester) async {
    // Act
    await pumpHome(tester);

    // Assert — mascot copy invites creating the first match
    expect(find.text(l10n.noMatchesYet), findsOneWidget);
    expect(find.text(l10n.createNewOne), findsOneWidget);
    expect(find.text(l10n.appTitle), findsOneWidget);
    expect(find.text(l10n.homeSubtitle), findsOneWidget);
  });

  testWidgets('lists active matches and hides finished ones by default',
      (tester) async {
    // Arrange — one match per status
    addMatch(_match(id: 'aaaa', status: MatchStatus.waiting));
    addMatch(_match(id: 'bbbb', status: MatchStatus.inProgress));
    addMatch(_match(
      id: 'cccc',
      status: MatchStatus.finished,
      winner: MatchWinner.f1,
      method: MatchMethod.submission,
      submission: 'armbar',
      endedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ));
    addMatch(_match(id: 'dddd', status: MatchStatus.canceled));

    // Act
    await pumpHome(tester);

    // Assert — only waiting + in-progress cards render
    expect(find.text('#aaaa'), findsOneWidget);
    expect(find.text('#bbbb'), findsOneWidget);
    expect(find.text('#cccc'), findsNothing);
    expect(find.text('#dddd'), findsNothing);
  });

  testWidgets('every status card shows its count of recent matches',
      (tester) async {
    // Arrange — two waiting, one finished
    addMatch(_match(id: 'aaaa', status: MatchStatus.waiting));
    addMatch(_match(id: 'bbbb', status: MatchStatus.waiting));
    addMatch(_match(
      id: 'cccc',
      status: MatchStatus.finished,
      winner: MatchWinner.f2,
      method: MatchMethod.points,
      endedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ));

    // Act
    await pumpHome(tester);

    // Assert — semantics labels carry "<status>: <count>"
    expect(statusCard(l10n.statusWaiting, 2), findsOneWidget);
    expect(statusCard(l10n.statusFinished, 1), findsOneWidget);
    expect(statusCard(l10n.statusCanceled, 0), findsOneWidget);
  });

  testWidgets('tapping a status card toggles that status into the filter',
      (tester) async {
    // Arrange — a finished match, hidden by the default filter
    addMatch(_match(
      id: 'cccc',
      status: MatchStatus.finished,
      winner: MatchWinner.f1,
      method: MatchMethod.submission,
      submission: 'armbar',
      endedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ));
    await pumpHome(tester);
    expect(find.text('#cccc'), findsNothing);

    // Act — select the Finished filter card
    await tester.tap(statusCard(l10n.statusFinished, 1));
    await tester.pump();

    // Assert — the finished match appears, with its outcome line
    expect(find.text('#cccc'), findsOneWidget);
    expect(
      find.textContaining(l10n.outcomeSubmissionOf('Armbar')),
      findsOneWidget,
    );

    // Act — deselect it again
    await tester.tap(statusCard(l10n.statusFinished, 1));
    await tester.pump();

    // Assert
    expect(find.text('#cccc'), findsNothing);
  });

  testWidgets('a live match card shows scores, advantages and penalties',
      (tester) async {
    // Arrange — f1 leads 4 points with an advantage; f2 carries a penalty
    addMatch(_match(
      id: 'bbbb',
      status: MatchStatus.inProgress,
      f1Pt2: 2,
      f1Adv: 1,
      f2Pen: 1,
    ));

    // Act
    await pumpHome(tester);

    // Assert
    expect(find.text('Pana'), findsOneWidget);
    expect(find.text('Buchecha'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // f1 effective points
    expect(find.text('A:1'), findsOneWidget); // f1 advantage badge
    expect(find.text('P:1'), findsOneWidget); // f2 penalty badge
    expect(find.text(l10n.vs), findsOneWidget);
    expect(find.text(l10n.statusInProgress), findsNWidgets(2));
  });

  testWidgets('a canceled match card is dimmed and lights up no score',
      (tester) async {
    // Arrange — reveal canceled matches through the filter
    addMatch(_match(id: 'dddd', status: MatchStatus.canceled, f1Pt2: 2));
    await pumpHome(tester);
    await tester.tap(statusCard(l10n.statusCanceled, 1));
    await tester.pump();

    // Assert — the card renders behind a dimming opacity
    final opacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.text('#dddd'),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, closeTo(.72, .001));
    expect(find.text(l10n.statusCanceled), findsWidgets);
  });

  testWidgets('a drawn match names no winner but describes the draw',
      (tester) async {
    // Arrange — level match called a draw: method without winner
    addMatch(_match(
      id: 'eeee',
      status: MatchStatus.finished,
      method: MatchMethod.draw,
      endedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ));
    await pumpHome(tester);

    // Act
    await tester.tap(statusCard(l10n.statusFinished, 1));
    await tester.pump();

    // Assert — the outcome line shows the draw without a fighter name
    expect(find.text(l10n.outcomeDraw), findsOneWidget);
  });

  testWidgets('the FAB opens the create match screen', (tester) async {
    // Arrange
    await pumpHome(tester);

    // Act
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(CreateMatchScreen), findsOneWidget);
  });

  testWidgets('tapping a match card opens its control screen', (tester) async {
    // Arrange — landscape viewport, as the control screen expects. A waiting
    // match keeps the control screen's clock (a periodic Timer) from running.
    // A plain ProviderScope owns the container here so the control notifier
    // is disposed with the tree, unlike the shared container above.
    tester.view.physicalSize = const Size(1600, 740);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final match = _match(id: 'bbbb', status: MatchStatus.waiting);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nostrServiceProvider.overrideWithValue(service),
          matchControlProvider.overrideWith(
            (ref) => MatchControlNotifier(match, service),
          ),
          screenWakelockProvider.overrideWithValue(const NoopScreenWakelock()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const HomeScreen(),
        ),
      ),
    );
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
      listen: false,
    );
    scope.read(matchFeedProvider.notifier).addLocal(match);
    await tester.pump();

    // Act
    await tester.tap(find.text('#bbbb'));
    await tester.pumpAndSettle();

    // Assert — the tapped match became the active one and the screen opened
    expect(find.byType(MatchControlScreen), findsOneWidget);
    expect(scope.read(activeMatchProvider)?.id, 'bbbb');
  });
}
