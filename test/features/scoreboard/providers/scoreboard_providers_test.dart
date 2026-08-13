import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/features/scoreboard/providers/scoreboard_providers.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/nostr_service.dart';

import '../../../support/nostr_fakes.dart';

/// A service whose event stream the test drives, and which records what the
/// scoreboard asked the relays for.
class _SpyNostrService extends NostrService {
  _SpyNostrService()
      : super(KeyManager(crypto: FakeNostrCrypto()),
            crypto: FakeNostrCrypto(), backend: FakeRelayBackend());

  final controller = StreamController<NostrEvent>.broadcast();
  final subscribed = <String>[];
  final unsubscribed = <String>[];

  /// What the service has already seen and would not replay on the stream.
  final cached = <NostrEvent>[];

  @override
  List<NostrEvent> cachedEventsOf(int kind, String pubkey) =>
      cached.where((e) => e.kind == kind && e.pubkey == pubkey).toList();

  @override
  Stream<NostrEvent> get eventStream => controller.stream;

  @override
  void subscribeToAuthor(String authorPubkey, {String? subscriptionId}) {
    subscribed.add(authorPubkey);
  }

  @override
  void unsubscribe(String subscriptionId) => unsubscribed.add(subscriptionId);
}

Match _match({String id = 'abcd', int f1Pt2 = 0}) {
  return Match(
    id: id,
    status: MatchStatus.inProgress,
    startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    duration: 300,
    f1Name: 'Pana',
    f2Name: 'Buchecha',
    f1Color: '#1BA34E',
    f2Color: '#F5B800',
    f1Pt2: f1Pt2,
  );
}

NostrEvent _eventOf(Match match,
    {required String pubkey, int? createdAt, String id = 'e1'}) {
  return NostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    kind: 31415,
    tags: [
      ['d', match.id],
    ],
    content: match.toJsonString(),
    sig: '',
  );
}

void main() {
  const watched =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  group('parsePubkey', () {
    final crypto = FakeNostrCrypto();

    test('takes a bare hex key', () {
      // Arrange
      final hex = 'A' * 64;

      // Act
      final parsed = parsePubkey(hex, crypto);

      // Assert — normalised, so one key never reads as two different ones
      expect(parsed, 'a' * 64);
    });

    test('takes an npub and returns its hex', () {
      // Act
      final parsed = parsePubkey('npub1fake', crypto);

      // Assert
      expect(parsed, watched);
    });

    test('ignores the whitespace that pasting tends to bring', () {
      // Act & Assert
      expect(parsePubkey('  npub1fake\n', crypto), watched);
      expect(parsePubkey(' ${'a' * 64} ', crypto), 'a' * 64);
    });

    test('refuses anything that is neither', () {
      // Act & Assert
      expect(parsePubkey('', crypto), isNull);
      expect(parsePubkey('   ', crypto), isNull);
      expect(parsePubkey('not a key', crypto), isNull);
      expect(parsePubkey('a' * 63, crypto), isNull, reason: 'too short');
      expect(parsePubkey('z' * 64, crypto), isNull, reason: 'not hex');
    });
  });

  group('ScoreboardFeedNotifier', () {
    late _SpyNostrService nostr;

    setUp(() => nostr = _SpyNostrService());
    tearDown(() => nostr.controller.close());

    test('asks the relays for the watched author', () {
      // Act
      final feed = ScoreboardFeedNotifier(nostr, watched);
      addTearDown(feed.dispose);

      // Assert
      expect(nostr.subscribed, [watched]);
    });

    test('takes a match the watched author published', () async {
      // Arrange
      final feed = ScoreboardFeedNotifier(nostr, watched);
      addTearDown(feed.dispose);

      // Act
      nostr.controller.add(_eventOf(_match(f1Pt2: 1), pubkey: watched));
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(feed.state.single.f1Pt2, 1);
    });

    test('ignores a match somebody else published', () async {
      // Arrange — the user's own subscription shares this stream
      final feed = ScoreboardFeedNotifier(nostr, watched);
      addTearDown(feed.dispose);

      // Act
      nostr.controller.add(_eventOf(_match(), pubkey: 'c' * 64));
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(feed.state, isEmpty);
    });

    test('keeps the newest revision, not the last one to arrive', () async {
      // Arrange — an addressable event is republished as the match is scored,
      // and relays can replay an older revision after a newer one
      final feed = ScoreboardFeedNotifier(nostr, watched);
      addTearDown(feed.dispose);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act
      nostr.controller
          .add(_eventOf(_match(f1Pt2: 2), pubkey: watched, createdAt: now));
      await Future<void>.delayed(Duration.zero);
      nostr.controller.add(
          _eventOf(_match(f1Pt2: 1), pubkey: watched, createdAt: now - 30));
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(feed.state.single.f1Pt2, 2);
    });

    test('does nothing at all when no pubkey is being watched', () async {
      // Act
      final feed = ScoreboardFeedNotifier(nostr, null);
      addTearDown(feed.dispose);
      nostr.controller.add(_eventOf(_match(), pubkey: watched));
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(nostr.subscribed, isEmpty);
      expect(feed.state, isEmpty);
    });

    test('closes the subscription it opened when it goes away', () {
      // Arrange
      final feed = ScoreboardFeedNotifier(nostr, watched);

      // Act
      feed.dispose();

      // Assert — otherwise every pubkey the user tried keeps streaming
      expect(nostr.unsubscribed, hasLength(1));
      expect(nostr.unsubscribed.single, startsWith('sb_'));
    });

    test('uses a subscription id a relay will actually accept', () {
      // A NIP-01 subscription id is capped at 64 characters and a relay drops
      // the whole REQ over it — nos.lol answers `CLOSED … "ERROR: bad req:
      // invalid subscription id"`. `scoreboard_` plus a 64-character pubkey came
      // to 75, and the section received nothing at all while publishing and the
      // app's own subscription both looked fine.
      //
      // Arrange
      final feed = ScoreboardFeedNotifier(nostr, watched);

      // Act
      feed.dispose();

      // Assert
      expect(nostr.unsubscribed.single.length, lessThanOrEqualTo(64));
    });

    test('tells two watched authors apart', () {
      // Arrange — a shared id would let one feed's teardown close the other's
      // subscription
      const other =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

      // Act
      ScoreboardFeedNotifier(nostr, watched).dispose();
      ScoreboardFeedNotifier(nostr, other).dispose();

      // Assert
      expect(nostr.unsubscribed.first, isNot(nostr.unsubscribed.last));
    });

    test('does not close a subscription it never opened', () {
      // Arrange
      final feed = ScoreboardFeedNotifier(nostr, null);

      // Act
      feed.dispose();

      // Assert
      expect(nostr.unsubscribed, isEmpty);
    });
  });

  group('WatchedPubkeyNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('remembers the pubkey it was given', () async {
      // Arrange
      final notifier = WatchedPubkeyNotifier();
      addTearDown(notifier.dispose);

      // Act
      await notifier.watch(watched);

      // Assert
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('choke:scoreboard-pubkey'), watched);
      expect(notifier.state, watched);
    });

    test('restores a saved pubkey, so a tournament survives a relaunch',
        () async {
      // Arrange
      SharedPreferences.setMockInitialValues(
        {'choke:scoreboard-pubkey': watched},
      );

      // Act
      final notifier = WatchedPubkeyNotifier();
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(notifier.state, watched);
    });

    test('a pubkey pasted while the saved one loads is not overwritten',
        () async {
      // Arrange
      SharedPreferences.setMockInitialValues(
        {'choke:scoreboard-pubkey': 'd' * 64},
      );
      final notifier = WatchedPubkeyNotifier();
      addTearDown(notifier.dispose);

      // Act — the user is faster than the disk
      await notifier.watch(watched);
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(notifier.state, watched);
    });

    test('forgets the pubkey when watching stops', () async {
      // Arrange
      SharedPreferences.setMockInitialValues(
        {'choke:scoreboard-pubkey': watched},
      );
      final notifier = WatchedPubkeyNotifier();
      addTearDown(notifier.dispose);

      // Act
      await notifier.watch(null);

      // Assert
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('choke:scoreboard-pubkey'), isNull);
      expect(notifier.state, isNull);
    });
  });

  group('scoreboardMatchesProvider', () {
    late _SpyNostrService nostr;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      nostr = _SpyNostrService();
      container = ProviderContainer(overrides: [
        nostrServiceProvider.overrideWithValue(nostr),
      ]);
      await container.read(watchedPubkeyProvider.notifier).watch(watched);
      // Realise the feed so it is listening before any event is pushed.
      container.read(scoreboardFeedProvider);
    });

    tearDown(() async {
      container.dispose();
      await nostr.controller.close();
    });

    Future<void> push(Match match, int createdAt) async {
      nostr.controller
          .add(_eventOf(match, pubkey: watched, createdAt: createdAt));
      await Future<void>.delayed(Duration.zero);
    }

    test('puts the live match first, whatever order it arrived in', () async {
      // Arrange
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act — the finished one is newer, so newest-first alone would lead with it
      await push(_match(id: 'aaa1'), now - 100);
      await push(
        _match(id: 'bbb2').copyWith(status: MatchStatus.finished),
        now,
      );

      // Assert — on a board, the fight in progress is the point
      final matches = container.read(scoreboardMatchesProvider);
      expect(matches.map((m) => m.id), ['aaa1', 'bbb2'],
          reason: 'aaa1 is live, bbb2 is finished');
    });

    test('orders matches of equal standing newest first', () async {
      // Arrange
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act
      await push(_match(id: 'ccc3'), now - 500);
      await push(_match(id: 'ddd4'), now - 10);

      // Assert
      final matches = container.read(scoreboardMatchesProvider);
      expect(matches.map((m) => m.id), ['ddd4', 'ccc3'],
          reason: 'ddd4 is the newer of the two');
    });

    test('drops a match older than the age limit', () async {
      // Arrange — a scoreboard is about the mats now, not yesterday
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act
      await push(_match(id: 'eee5'), now - 60);
      await push(_match(id: 'fff6'), now - scoreboardMaxAgeSeconds - 60);

      // Assert
      final matches = container.read(scoreboardMatchesProvider);
      expect(matches.map((m) => m.id), ['eee5'],
          reason: 'fff6 is a day and a minute old');
    });

    test('drops a match that ages out with no further events', () async {
      // The window is derived from the clock at build time, and this provider
      // only rebuilds when the feed changes. An organizer who posts a card and
      // then goes quiet used to leave it on the board forever: nothing was ever
      // going to arrive and re-run the comparison that would drop it.
      //
      // Arrange — fresh when first read, one second short of the limit
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await push(_match(id: 'abc7'), now - scoreboardMaxAgeSeconds + 1);
      expect(
        container.read(scoreboardMatchesProvider).map((m) => m.id),
        ['abc7'],
        reason: 'it has to start on the board for ageing out to mean anything',
      );

      // Act — cross the boundary without the organizer publishing anything
      await Future<void>.delayed(const Duration(seconds: 2));

      // Assert
      expect(container.read(scoreboardMatchesProvider), isEmpty);
    });
  });

  group('ScoreboardFeedNotifier hydration', () {
    late _SpyNostrService nostr;

    setUp(() => nostr = _SpyNostrService());
    tearDown(() => nostr.controller.close());

    test('starts from what the app already knows about this author', () {
      // Arrange — watched once before, so the service holds the latest state
      // and will drop the relay's replay of it as no newer
      nostr.cached.add(_eventOf(_match(f1Pt2: 2), pubkey: watched));

      // Act — watch that author again
      final feed = ScoreboardFeedNotifier(nostr, watched);
      addTearDown(feed.dispose);

      // Assert — leaving and coming back used to show an empty board until the
      // author happened to score again
      expect(feed.state.single.f1Pt2, 2);
    });

    test('does not take cached matches belonging to another author', () {
      // Arrange
      nostr.cached.add(_eventOf(_match(), pubkey: 'c' * 64));

      // Act
      final feed = ScoreboardFeedNotifier(nostr, watched);
      addTearDown(feed.dispose);

      // Assert
      expect(feed.state, isEmpty);
    });

    test('a live event still supersedes the cached one', () async {
      // Arrange
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      nostr.cached.add(
          _eventOf(_match(f1Pt2: 1), pubkey: watched, createdAt: now - 60));
      final feed = ScoreboardFeedNotifier(nostr, watched);
      addTearDown(feed.dispose);

      // Act
      nostr.controller
          .add(_eventOf(_match(f1Pt2: 3), pubkey: watched, createdAt: now));
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(feed.state.single.f1Pt2, 3);
    });
  });

  group('WatchedPubkeyNotifier stop-watching race', () {
    test('a restore in flight does not undo an explicit stop', () async {
      // Arrange — a saved pubkey is on its way back from disk
      SharedPreferences.setMockInitialValues(
        {'choke:scoreboard-pubkey': watched},
      );
      final notifier = WatchedPubkeyNotifier();
      addTearDown(notifier.dispose);

      // Act — the user stops watching before the restore lands. Both "nobody
      // has chosen" and "chose to stop" are null, so the restore must not read
      // the second as the first.
      await notifier.watch(null);
      await Future<void>.delayed(Duration.zero);

      // Assert — the board they just closed must not come back
      expect(notifier.state, isNull);
    });
  });

  group('ScoreboardFeedNotifier equal-timestamp revisions', () {
    late _SpyNostrService nostr;

    setUp(() => nostr = _SpyNostrService());
    tearDown(() => nostr.controller.close());

    /// Push two revisions of one match, stamped the same second, in [order].
    Future<List<int>> deliver(List<String> order) async {
      final feed = ScoreboardFeedNotifier(nostr, watched);
      addTearDown(feed.dispose);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      const scores = {'aaaa': 2, 'ffff': 5};
      for (final id in order) {
        nostr.controller.add(_eventOf(
          _match(f1Pt2: scores[id]!),
          pubkey: watched,
          createdAt: now,
          id: id,
        ));
        await Future<void>.delayed(Duration.zero);
      }
      return feed.state.map((m) => m.f1Pt2).toList();
    }

    test('settle on the same revision whichever order they arrive in',
        () async {
      // Two valid revisions created in one second — a referee scoring twice —
      // delivered in opposite orders by two relays. Resolving by arrival would
      // leave two phones showing different scores for the same match, with no
      // way to tell which is right.
      //
      // Act
      final oneWay = await deliver(['aaaa', 'ffff']);
      final theOther = await deliver(['ffff', 'aaaa']);

      // Assert — and NIP-01 says the lowest id is the one they agree on
      expect(oneWay, theOther);
      expect(oneWay, [2], reason: 'aaaa < ffff');
    });

    test('a genuinely newer revision still wins', () async {
      // Arrange
      final feed = ScoreboardFeedNotifier(nostr, watched);
      addTearDown(feed.dispose);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act — the newer one carries the HIGHER id, so an id-only rule would
      // wrongly keep the old one
      nostr.controller.add(_eventOf(_match(f1Pt2: 1),
          pubkey: watched, createdAt: now, id: 'aaaa'));
      await Future<void>.delayed(Duration.zero);
      nostr.controller.add(_eventOf(_match(f1Pt2: 4),
          pubkey: watched, createdAt: now + 1, id: 'ffff'));
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(feed.state.single.f1Pt2, 4);
    });
  });

  group('scoreboardIsLiveProvider', () {
    late _SpyNostrService nostr;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      nostr = _SpyNostrService();
      container = ProviderContainer(overrides: [
        nostrServiceProvider.overrideWithValue(nostr),
      ]);
      await container.read(watchedPubkeyProvider.notifier).watch(watched);
      container.read(scoreboardFeedProvider);
    });

    tearDown(() async {
      container.dispose();
      await nostr.controller.close();
    });

    /// Deliver [match] to the feed.
    ///
    /// [eventId] and [createdAt] matter whenever a test revises a match it has
    /// already pushed: a revision only supersedes the held one if it is newer,
    /// or equal and lower-id. Reusing the defaults would have the feed drop the
    /// second push and leave a test asserting against the first.
    Future<void> push(
      Match match, {
      int? createdAt,
      String eventId = 'e1',
    }) async {
      nostr.controller.add(
        _eventOf(match, pubkey: watched, createdAt: createdAt, id: eventId),
      );
      await Future<void>.delayed(Duration.zero);
    }

    test('is not live with nothing on the board', () {
      // Arrange + Act + Assert
      expect(container.read(scoreboardIsLiveProvider), isFalse);
    });

    test('is live while a fight is in progress', () async {
      // Arrange + Act
      await push(_match());

      // Assert
      expect(container.read(scoreboardIsLiveProvider), isTrue);
    });

    test('is live while a fight is only waiting to start', () async {
      // Arrange + Act — the card is posted, the mat has not begun
      await push(_match().copyWith(status: MatchStatus.waiting));

      // Assert
      expect(container.read(scoreboardIsLiveProvider), isTrue);
    });

    test('stays live in the gap between two fights', () async {
      // Arrange
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await push(_match(id: 'aaa1'), createdAt: now);
      await push(
        _match(id: 'bbb2').copyWith(status: MatchStatus.waiting),
        createdAt: now,
        eventId: 'e2',
      );

      // Act — the running one ends, the queued one has not started
      await push(
        _match(id: 'aaa1').copyWith(status: MatchStatus.finished, endedAt: now),
        createdAt: now + 1,
        eventId: 'e3',
      );

      // Assert — this gap is the whole reason the hold exists
      expect(
        container.read(scoreboardMatchesProvider).map((m) => m.status),
        containsAll([MatchStatus.finished, MatchStatus.waiting]),
        reason: 'the revision has to have landed for this to mean anything',
      );
      expect(container.read(scoreboardIsLiveProvider), isTrue);
    });

    test('goes quiet once every fight is finished', () async {
      // Arrange
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await push(_match(id: 'aaa1'), createdAt: now);
      expect(container.read(scoreboardIsLiveProvider), isTrue);

      // Act
      await push(
        _match(id: 'aaa1').copyWith(status: MatchStatus.finished, endedAt: now),
        createdAt: now + 1,
        eventId: 'e2',
      );

      // Assert
      expect(container.read(scoreboardIsLiveProvider), isFalse);
    });

    test('goes quiet for a board of canceled fights', () async {
      // Arrange + Act
      await push(_match().copyWith(status: MatchStatus.canceled));

      // Assert — canceled is as over as finished: nothing is coming
      expect(container.read(scoreboardIsLiveProvider), isFalse);
    });

    test('ignores the status filter the list is showing', () async {
      // Arrange
      await push(_match());

      // Act — the spectator narrows the list to today's results
      container.read(scoreboardStatusFilterProvider.notifier).state = {
        MatchStatus.finished,
      };

      // Assert — the chips are a display choice; the event is still running
      expect(container.read(scoreboardFilteredMatchesProvider), isEmpty);
      expect(container.read(scoreboardIsLiveProvider), isTrue);
    });

    test('goes quiet when the board ages out under the viewer', () async {
      // The case the hold exists to bound. A spectator sitting on a board whose
      // organizer stopped publishing must not keep the display pinned once that
      // board is a day old — and nothing is going to arrive to make it notice.
      //
      // Arrange — live when first read, one second short of the limit
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await push(
        _match().copyWith(status: MatchStatus.waiting),
        createdAt: now - scoreboardMaxAgeSeconds + 1,
      );
      expect(container.read(scoreboardIsLiveProvider), isTrue);

      // Act
      await Future<void>.delayed(const Duration(seconds: 2));

      // Assert
      expect(container.read(scoreboardIsLiveProvider), isFalse);
    });

    test('goes quiet when the only waiting fight ages out', () async {
      // Arrange — a card whose organizer never closed it must not read as live
      // forever
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act
      await push(
        _match().copyWith(status: MatchStatus.waiting),
        createdAt: now - scoreboardMaxAgeSeconds - 60,
      );

      // Assert
      expect(container.read(scoreboardIsLiveProvider), isFalse);
    });
  });
}
