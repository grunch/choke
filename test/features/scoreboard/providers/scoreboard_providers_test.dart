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

NostrEvent _eventOf(Match match, {required String pubkey, int? createdAt}) {
  return NostrEvent(
    id: 'e1',
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
  const watched = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

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

    test('closes its subscription when it goes away', () {
      // Arrange
      final feed = ScoreboardFeedNotifier(nostr, watched);

      // Act
      feed.dispose();

      // Assert — otherwise every pubkey the user tried keeps streaming
      expect(nostr.unsubscribed, ['scoreboard_$watched']);
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
  });
}
