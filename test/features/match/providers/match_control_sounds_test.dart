import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/features/match/models/match_outcome.dart';
import 'package:choke/features/match/providers/match_control_provider.dart';
import 'package:choke/services/audio/match_sounds.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/nostr_service.dart';

import '../../../support/nostr_fakes.dart';

/// A [NostrService] that never touches a relay.
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

/// Records which cues were asked for, in order.
class _RecordingSounds implements MatchSounds {
  final List<String> played = [];
  int warmUps = 0;
  bool disposed = false;

  @override
  Future<void> warmUp() async => warmUps++;

  @override
  Future<void> playStart() async => played.add('start');

  @override
  Future<void> playEnd() async => played.add('end');

  @override
  Future<void> dispose() async => disposed = true;
}

Match _match({
  MatchStatus status = MatchStatus.inProgress,
  int duration = 300,
  int? startAtOffset = 0,
  int f1Pt2 = 0,
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return Match(
    id: 'abcd',
    status: status,
    startAt: startAtOffset == null ? null : now + startAtOffset,
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
  late _RecordingSounds sounds;
  late MatchControlNotifier notifier;

  setUp(() {
    nostr = _FakeNostrService();
    sounds = _RecordingSounds();
  });

  tearDown(() async {
    // Let queued publish futures settle before disposing
    await Future<void>.delayed(Duration.zero);
    notifier.dispose();
  });

  group('defaults', () {
    test('a notifier built without sounds runs silent, not broken', () async {
      // Every other test in the suite constructs a notifier this way, so the
      // default must never reach for a platform channel.
      notifier = MatchControlNotifier(
        _match(status: MatchStatus.waiting, startAtOffset: null),
        nostr,
      );

      notifier.startMatch();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.isRunning, isTrue);
    });
  });

  group('start bell', () {
    test('starting a match rings the bell', () async {
      notifier = MatchControlNotifier(
        _match(status: MatchStatus.waiting, startAtOffset: null),
        nostr,
        null,
        sounds,
      );

      notifier.startMatch();
      await Future<void>.delayed(Duration.zero);

      expect(sounds.played, ['start']);
    });

    test('a match that is already running does not ring on open', () async {
      notifier = MatchControlNotifier(_match(), nostr, null, sounds);
      await Future<void>.delayed(Duration.zero);

      // Reopening the screen mid-match is not the fight starting.
      expect(sounds.played, isEmpty);
    });

    test('resuming a paused clock does not ring again', () async {
      notifier = MatchControlNotifier(
        _match(status: MatchStatus.waiting, startAtOffset: null),
        nostr,
        null,
        sounds,
      );
      notifier.startMatch();
      notifier.pauseMatch();

      notifier.resumeMatch();
      await Future<void>.delayed(Duration.zero);

      // One bell per fight. A stoppage is the same fight carrying on, and a
      // second bell would read to the mat as a second match.
      expect(sounds.played, ['start']);
    });

    test('the cues are loaded up front, not on the first press', () {
      notifier = MatchControlNotifier(_match(), nostr, null, sounds);

      expect(sounds.warmUps, 1);
    });
  });

  group('end horn', () {
    test('the horn sounds when the clock runs out', () async {
      notifier = MatchControlNotifier(
        _match(duration: 1, f1Pt2: 1),
        nostr,
        null,
        sounds,
      );

      await Future<void>.delayed(const Duration(milliseconds: 1600));

      expect(sounds.played, ['end']);
      expect(notifier.state.match.status, MatchStatus.finished);
    });

    test('a level match still gets its horn while it waits on the referee',
        () async {
      notifier = MatchControlNotifier(_match(duration: 1), nostr, null, sounds);

      await Future<void>.delayed(const Duration(milliseconds: 1600));

      // Regulation time ended whether or not the scoreboard can name a winner.
      // This is the case where the mat most needs telling: everyone is still
      // grappling and the clock is spent.
      expect(sounds.played, ['end']);
      expect(notifier.state.awaitsOutcome, isTrue);
    });

    test('a match whose time expired while the app was closed stays silent',
        () async {
      // Started ten minutes ago, five minute duration: over long before the
      // notifier existed.
      notifier = MatchControlNotifier(
        _match(duration: 300, startAtOffset: -600),
        nostr,
        null,
        sounds,
      );
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.remainingSeconds, 0);
      expect(sounds.played, isEmpty,
          reason:
              'a horn here announces a match that ended in somebody\'s bag');
    });

    test('finishing early by submission does not sound the horn', () async {
      notifier = MatchControlNotifier(_match(), nostr, null, sounds);

      notifier.finishWith(const MatchOutcome(
        winner: MatchWinner.f1,
        method: MatchMethod.submission,
        submission: 'armbar',
      ));
      await Future<void>.delayed(Duration.zero);

      // The horn marks the end of regulation time, and this match never
      // reached it.
      expect(sounds.played, isEmpty);
    });

    test('cancelling a match does not sound the horn', () async {
      notifier = MatchControlNotifier(_match(), nostr, null, sounds);

      notifier.cancelMatch();
      await Future<void>.delayed(Duration.zero);

      expect(sounds.played, isEmpty);
    });
  });
}
