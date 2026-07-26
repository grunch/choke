import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/home/providers/home_providers.dart';
import 'package:choke/features/match/models/match.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/nostr_service.dart';

import '../../../support/nostr_fakes.dart';

/// NostrService whose event stream can be fed from the test (relay echoes).
class _StreamNostrService extends NostrService {
  _StreamNostrService()
      : super(KeyManager(crypto: FakeNostrCrypto()),
            crypto: FakeNostrCrypto(), backend: FakeRelayBackend());

  final controller = StreamController<NostrEvent>.broadcast();

  @override
  Stream<NostrEvent> get eventStream => controller.stream;
}

/// A service that already knows who it is, as one does after
/// `subscribeToUserEvents`.
class _IdentifiedNostrService extends _StreamNostrService {
  _IdentifiedNostrService(this._me);

  final String _me;

  @override
  String? get userPubkey => _me;
}

Match _match({int f1Pt2 = 0, MatchStatus status = MatchStatus.inProgress}) {
  return Match(
    id: 'abcd',
    status: status,
    startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    duration: 300,
    f1Name: 'Pana',
    f2Name: 'Buchecha',
    f1Color: '#1BA34E',
    f2Color: '#F5B800',
    f1Pt2: f1Pt2,
  );
}

NostrEvent _echoOf(Match match, int createdAt, {String pubkey = 'pk'}) {
  return NostrEvent(
    id: 'e1',
    pubkey: pubkey,
    createdAt: createdAt,
    kind: 31415,
    tags: [
      ['d', match.id],
    ],
    content: match.toJsonString(),
    sig: '',
  );
}

void main() {
  late _StreamNostrService nostr;
  late MatchFeedNotifier feed;

  setUp(() {
    nostr = _StreamNostrService();
    feed = MatchFeedNotifier(nostr);
  });

  tearDown(() async {
    feed.dispose();
    await nostr.controller.close();
  });

  group('MatchFeedNotifier author filter', () {
    // The scoreboard section subscribes to whatever pubkey the user pastes, and
    // every subscription shares one event stream that says nothing about which
    // filter matched. Without an author check, watching somebody else's matches
    // would quietly file them into this user's own feed.
    test('ignores a match published by somebody else', () async {
      // Arrange
      final nostr = _IdentifiedNostrService('me');
      final feed = MatchFeedNotifier(nostr);
      addTearDown(() async {
        feed.dispose();
        await nostr.controller.close();
      });
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act — a match arriving from the pubkey the scoreboard is watching
      nostr.controller.add(_echoOf(_match(), now, pubkey: 'someone-else'));
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(feed.state, isEmpty);
    });

    test('keeps a match this user published', () async {
      // Arrange
      final nostr = _IdentifiedNostrService('me');
      final feed = MatchFeedNotifier(nostr);
      addTearDown(() async {
        feed.dispose();
        await nostr.controller.close();
      });
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act
      nostr.controller.add(_echoOf(_match(), now, pubkey: 'me'));
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(feed.state, hasLength(1));
    });

    test('accepts events while the app still does not know who it is', () async {
      // Arrange — before subscribeToUserEvents there is no other subscription to
      // confuse this feed with, and dropping here would lose the user's own
      // opening events: a relay does not send them again.
      final nostr = _StreamNostrService();
      final feed = MatchFeedNotifier(nostr);
      addTearDown(() async {
        feed.dispose();
        await nostr.controller.close();
      });
      expect(nostr.userPubkey, isNull);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act
      nostr.controller.add(_echoOf(_match(), now, pubkey: 'whoever'));
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(feed.state, hasLength(1));
    });
  });

  group('MatchFeedNotifier', () {
    test('a local update supersedes a relay echo with a future timestamp',
        () async {
      // Arrange — published events carry a per-match monotonic created_at
      // that can run ahead of the wall clock; the relay echoes one back
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      nostr.controller.add(_echoOf(_match(f1Pt2: 1), now + 5));
      await Future<void>.delayed(Duration.zero);
      expect(feed.state.single.f1Pt2, 1);

      // Act — the operator keeps scoring on this device
      feed.addLocal(_match(f1Pt2: 2));

      // Assert — the home feed always shows what the operator just did
      expect(feed.state.single.f1Pt2, 2);
    });

    test('two local updates within the same second: the newest wins', () {
      // Arrange + Act
      feed.addLocal(_match(f1Pt2: 1));
      feed.addLocal(_match(f1Pt2: 2));

      // Assert
      expect(feed.state.single.f1Pt2, 2);
    });

    test('an older relay event does not override newer local state', () async {
      // Arrange
      feed.addLocal(_match(f1Pt2: 3));
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Act — a stale echo arrives late
      nostr.controller.add(_echoOf(_match(f1Pt2: 1), now - 60));
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(feed.state.single.f1Pt2, 3);
    });
  });

  group('statusFilter default', () {
    test('shows only active matches (waiting + in progress) by default', () {
      // Arrange
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Assert
      expect(
        container.read(statusFilterProvider),
        {MatchStatus.waiting, MatchStatus.inProgress},
      );
    });

    test('filtered list hides finished and canceled matches by default', () {
      // Arrange — one match of every status is available
      final container = ProviderContainer(
        overrides: [
          recentMatchListProvider.overrideWithValue([
            _match(status: MatchStatus.waiting),
            _match(status: MatchStatus.inProgress),
            _match(status: MatchStatus.finished),
            _match(status: MatchStatus.canceled),
          ]),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final visible = container.read(filteredMatchListProvider);

      // Assert — finished/canceled are hidden until the user opts in
      expect(
        visible.map((m) => m.status).toSet(),
        {MatchStatus.waiting, MatchStatus.inProgress},
      );
    });

    test('tapping a hidden filter reveals its matches', () {
      // Arrange — only a finished match exists, hidden by default
      final container = ProviderContainer(
        overrides: [
          recentMatchListProvider.overrideWithValue([
            _match(status: MatchStatus.finished),
          ]),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(filteredMatchListProvider), isEmpty);

      // Act — the user taps the "finished" filter chip
      container.read(statusFilterProvider.notifier).update(
            (selected) => {...selected, MatchStatus.finished},
          );

      // Assert
      expect(
        container.read(filteredMatchListProvider).single.status,
        MatchStatus.finished,
      );
    });
  });
}
