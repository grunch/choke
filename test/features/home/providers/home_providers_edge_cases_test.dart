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

  /// The author `_echoOf` stamps by default. The feed drops anything from
  /// anybody else, so a service with no identity would drop every event these
  /// tests push through it.
  @override
  String? get userPubkey => 'pk';
}

Match _match({String id = 'abcd'}) {
  return Match(
    id: id,
    status: MatchStatus.inProgress,
    startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    duration: 300,
    f1Name: 'Pana',
    f2Name: 'Buchecha',
    f1Color: '#1BA34E',
    f2Color: '#F5B800',
  );
}

NostrEvent _event({
  required String dTag,
  required int createdAt,
  String? content,
  int kind = 31415,
}) {
  return NostrEvent(
    // Unique per (match, timestamp): Nostr clients dedupe by event id, so a
    // shared hardcoded id would make future id-based dedup silently drop
    // events these tests rely on.
    id: 'e-$dTag-$createdAt',
    pubkey: 'pk',
    createdAt: createdAt,
    kind: kind,
    tags: [
      ['d', dTag],
    ],
    content: content ?? _match(id: dTag).toJsonString(),
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

  group('MatchFeedNotifier resilience', () {
    test('an unparseable 31415 event is skipped, not fatal', () async {
      // Arrange — anyone can publish garbage under our kind; one bad event
      // must not kill the subscription that feeds the whole home screen
      nostr.controller.add(
        _event(dTag: 'abcd', createdAt: 1000, content: 'not json'),
      );
      await Future<void>.delayed(Duration.zero);

      // Act — a well-formed event follows on the same stream
      nostr.controller.add(
        _event(dTag: 'beef', createdAt: 1001),
      );
      await Future<void>.delayed(Duration.zero);

      // Assert — the bad event vanished, the good one landed
      expect(feed.state.single.id, 'beef');
    });

    test('getCreatedAt reports the stamp for a known match and null otherwise',
        () {
      // Arrange
      feed.addLocal(_match(id: 'abcd'));

      // Act + Assert — the timestamp is what the 24h feed filter keys on
      expect(feed.getCreatedAt('abcd'), isNotNull);
      expect(feed.getCreatedAt('ffff'), isNull);
    });
  });

  group('recentMatchListProvider', () {
    test('keeps fresh matches and drops those older than 24 hours', () async {
      // Arrange — one match created now, one whose event is 25 hours old
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(nostr),
        ],
      );
      addTearDown(container.dispose);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      container.read(matchFeedProvider.notifier).addLocal(_match(id: 'abcd'));
      nostr.controller.add(
        _event(dTag: 'beef', createdAt: now - 90000),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(matchFeedProvider), hasLength(2));

      // Act
      final recent = container.read(recentMatchListProvider);

      // Assert — yesterday's boards do not clutter today's home screen
      expect(recent.map((m) => m.id), ['abcd']);
    });
  });
}
