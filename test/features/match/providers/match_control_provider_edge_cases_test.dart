import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/home/providers/home_providers.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/features/match/providers/match_control_provider.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/nostr_service.dart';

import '../../../support/nostr_fakes.dart';

/// Fake NostrService that records publishes instead of hitting relays.
class _FakeNostrService extends NostrService {
  _FakeNostrService()
      : super(KeyManager(crypto: FakeNostrCrypto()),
            crypto: FakeNostrCrypto(), backend: FakeRelayBackend());

  final List<String> publishedContents = [];

  @override
  Future<void> publishAddressableEvent({
    required String dTag,
    required String content,
    List<List<String>> additionalTags = const [],
  }) async {
    publishedContents.add(content);
  }
}

Match _match({
  MatchStatus status = MatchStatus.inProgress,
  int? startAt,
  int duration = 300,
  int f1Pt2 = 0,
}) {
  return Match(
    id: 'abcd',
    status: status,
    startAt: startAt,
    duration: duration,
    f1Name: 'Pana',
    f2Name: 'Buchecha',
    f1Color: '#1BA34E',
    f2Color: '#F5B800',
    f1Pt2: f1Pt2,
  );
}

void main() {
  late _FakeNostrService nostr;
  MatchControlNotifier? notifier;

  setUp(() {
    nostr = _FakeNostrService();
  });

  tearDown(() async {
    // Let queued publish futures settle before disposing. Provider-group
    // tests hand ownership to their container, which disposes for them.
    await Future<void>.delayed(Duration.zero);
    notifier?.dispose();
    notifier = null;
  });

  group('clock initialisation', () {
    test('an in-progress match with startAt 0 gets its full duration', () {
      // Arrange — startAt 0 is the sentinel a freshly created match carries
      // before anyone presses start; the clock must not read as if the match
      // began in 1970
      final n = notifier = MatchControlNotifier(
        _match(startAt: 0),
        nostr,
      );

      // Assert
      expect(n.state.remainingSeconds, 300);
    });
  });

  group('subtract on fighter 2', () {
    test('subtractAdv and subtractPen decrement fighter 2 counts', () {
      // Arrange — fighter 2 has an advantage and a penalty on the card
      final n = notifier = MatchControlNotifier(
        _match(startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000),
        nostr,
      );
      n.scoreAdv(2);
      n.scorePen(2);

      // Act — the referee reverses both (mis-taps happen mid-match)
      n.subtractAdv(2);
      n.subtractPen(2);

      // Assert
      expect(n.state.match.f2Adv, 0);
      expect(n.state.match.f2Pen, 0);
    });
  });

  group('time up without a start timestamp', () {
    test('a scored zero-duration match without startAt still gets an endedAt',
        () {
      // Arrange — an event some other client authored: in progress, no
      // start_at, and a clock with nothing left. The real expiry cannot be
      // derived from startAt, so "now" is the best available answer.
      final n = notifier = MatchControlNotifier(
        _match(startAt: null, duration: 0, f1Pt2: 1),
        nostr,
      );

      // Assert — the scoreboard decides (2–0), and the ending is stamped
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final match = n.state.match;
      expect(match.status, MatchStatus.finished);
      expect(match.winner, MatchWinner.f1);
      expect(match.method, MatchMethod.points);
      expect(match.endedAt, isNotNull);
      expect((match.endedAt! - now).abs() <= 5, isTrue,
          reason: 'endedAt falls back to now, not to a derived expiry');
    });
  });

  group('pausing an already-expired clock', () {
    test('pause on a clock that ran out asks for the outcome instead',
        () async {
      // Arrange — a one-second match, level on points, whose clock runs out
      // for real. The scoreboard cannot decide it, so it stays open and
      // awaiting an outcome.
      final n = notifier = MatchControlNotifier(
        _match(
          startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          duration: 1,
        ),
        nostr,
      );
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(n.state.awaitsOutcome, isTrue);
      expect(n.state.match.status, MatchStatus.inProgress);

      // Act — the referee taps pause anyway (the button was on screen when
      // the clock hit zero)
      n.pauseMatch();

      // Assert — a match whose clock is done cannot be paused: it stays
      // open, unpaused, still waiting for the referee's answer
      expect(n.state.match.pausedAt, isNull);
      expect(n.state.isPaused, isFalse);
      expect(n.state.awaitsOutcome, isTrue);
      expect(n.state.remainingSeconds, 0);
    });
  });

  group('providers', () {
    test('activeMatchProvider starts unset', () {
      // Arrange
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Assert
      expect(container.read(activeMatchProvider), isNull);
    });

    test('matchControlProvider refuses to build without an active match', () {
      // Arrange — reading the control provider before a match is selected is
      // a programming error, and must fail loudly instead of controlling a
      // match that does not exist
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(_FakeNostrService()),
        ],
      );
      addTearDown(container.dispose);

      // Act + Assert
      expect(
        () => container.read(matchControlProvider),
        throwsA(isA<StateError>()),
      );
    });

    test('reopening an expired match through the provider does not throw',
        () async {
      // Arrange — the control screen reads this provider from initState, so
      // the notifier is created mid-build. An in-progress match whose clock
      // already ran out settles itself in the constructor, and settling
      // publishes: Riverpod forbids touching the feed provider while this one
      // is still being created.
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(nostr),
        ],
      );
      addTearDown(container.dispose);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      container.read(activeMatchProvider.notifier).state =
          _match(startAt: now - 600, duration: 300, f1Pt2: 1);

      // Act
      final state = container.read(matchControlProvider);

      // Assert — the clock is settled, and the feed still learns about it
      expect(state.match.status, MatchStatus.finished);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(matchFeedProvider).map((m) => m.id),
        contains('abcd'),
      );
    });

    test('matchControlProvider builds a notifier for the active match', () {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(nostr),
        ],
      );
      addTearDown(container.dispose);
      final match = _match(status: MatchStatus.waiting, startAt: null);
      container.read(activeMatchProvider.notifier).state = match;

      // Act
      final state = container.read(matchControlProvider);

      // Assert — the notifier controls exactly the match that was selected
      expect(state.match.id, match.id);
      expect(state.isWaiting, isTrue);
      expect(state.remainingSeconds, match.duration);
    });
  });
}
