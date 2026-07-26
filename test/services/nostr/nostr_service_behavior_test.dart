import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/nostr_service.dart';

import '../../support/nostr_fakes.dart';

/// A key manager with no identity at all — both keys are null.
class _NoKeyManager extends KeyManager {
  _NoKeyManager() : super(crypto: FakeNostrCrypto());

  @override
  Future<String?> getPublicKeyHex() async => null;

  @override
  Future<String?> getPrivateKeyHex() async => null;
}

/// A key manager with a fixed in-memory identity, never touching storage.
class _FixedKeyManager extends KeyManager {
  _FixedKeyManager() : super(crypto: FakeNostrCrypto());

  @override
  Future<String?> getPublicKeyHex() async => 'e' * 64;

  @override
  Future<String?> getPrivateKeyHex() async => 'f' * 64;
}

/// Crypto that signs but then disowns its own signature.
class _RejectingCrypto extends FakeNostrCrypto {
  @override
  bool verifyEvent(NostrEvent event) => false;
}

NostrEvent _event({
  String id = 'a1',
  String pubkey = 'p1',
  int kind = 31415,
  int createdAt = 1000,
  List<List<String>> tags = const [],
  String content = '{}',
}) {
  return NostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    kind: kind,
    tags: tags,
    content: content,
    sig: 'b' * 128,
  );
}

void main() {
  late RecordingRelayBackend backend;
  late NostrService service;

  setUp(() {
    backend = RecordingRelayBackend();
    service = NostrService(
      _FixedKeyManager(),
      crypto: FakeNostrCrypto(),
      backend: backend,
      // Long enough that the background resend sweep never fires mid-test;
      // resend behavior is driven explicitly through reconnect signals.
      resendInterval: const Duration(minutes: 5),
    );
  });

  tearDown(() => service.dispose());

  group('NostrEvent JSON', () {
    test('fromJson reads the wire form toJson writes', () {
      // Arrange
      final original = _event(
        tags: [
          ['d', 'abcd'],
          ['expiration', '9999999999'],
        ],
        content: '{"status":"finished"}',
      );

      // Act
      final decoded = NostrEvent.fromJson(original.toJson());

      // Assert
      expect(decoded.id, original.id);
      expect(decoded.pubkey, original.pubkey);
      expect(decoded.createdAt, original.createdAt);
      expect(decoded.kind, original.kind);
      expect(decoded.tags, original.tags);
      expect(decoded.content, original.content);
      expect(decoded.sig, original.sig);
    });
  });

  group('initialize', () {
    test('dials the default relays when none are configured', () async {
      // Act
      await service.initialize();

      // Assert — the two shipped defaults, in order. Neither may be a relay
      // that rate-limits a scoring burst; see RelayConfigService.defaultRelays.
      expect(backend.addedRelays, [
        'wss://nos.lol',
        'wss://relay.primal.net',
      ]);
    });

    test('dials exactly the relays it is given instead of the defaults',
        () async {
      // Act
      await service.initialize(relayUrls: ['wss://example.test']);

      // Assert
      expect(backend.addedRelays, ['wss://example.test']);
    });
  });

  group('backend passthroughs', () {
    test('removeRelay forwards to the transport', () {
      // Act
      service.removeRelay('wss://gone.test');

      // Assert
      expect(backend.removedRelays, ['wss://gone.test']);
    });

    test('connectedRelays reports the transport view', () {
      // Arrange
      backend.connected = ['wss://up.test'];

      // Assert
      expect(service.connectedRelays, ['wss://up.test']);
    });

    test('disconnect forwards to the transport', () {
      // Act
      service.disconnect();

      // Assert
      expect(backend.disconnectCalls, 1);
    });

    test('unsubscribe forwards to the transport', () {
      // Act
      service.unsubscribe('some_sub');

      // Assert
      expect(backend.unsubscribed, ['some_sub']);
    });
  });

  group('subscriptions', () {
    test('subscribeToUserEvents throws when there is no identity yet',
        () async {
      // Arrange — a service whose key manager has no keys
      final keyless = NostrService(
        _NoKeyManager(),
        crypto: FakeNostrCrypto(),
        backend: backend,
      );
      addTearDown(keyless.dispose);

      // Act + Assert
      await expectLater(keyless.subscribeToUserEvents(), throwsException);
      expect(backend.subscriptions, isEmpty);
    });

    test('subscribeToUserEvents asks for the user\'s own kind 31415 events',
        () async {
      // Act
      await service.subscribeToUserEvents();

      // Assert
      final filter = backend.subscriptions['user_events'];
      expect(filter, isNotNull);
      expect(filter!.kinds, [31415]);
      expect(filter.authors, ['e' * 64]);
    });

    test('subscribeToAuthor derives a subscription id from the author', () {
      // Act
      service.subscribeToAuthor('c' * 64);

      // Assert — the id names the author, but only as much of it as fits: NIP-01
      // caps a subscription id at 64 characters and a relay drops the whole REQ
      // over it, so a full pubkey in the id would never receive an event.
      final id = backend.subscriptions.keys.single;
      expect(id, startsWith('author_'));
      expect(id.length, lessThanOrEqualTo(64));
      expect(id, contains('cccc'));

      final filter = backend.subscriptions[id];
      expect(filter!.kinds, [31415]);
      expect(filter.authors, ['c' * 64],
          reason: 'the filter still carries the whole key');
    });

    test('subscribeToAuthor honors an explicit subscription id', () {
      // Act
      service.subscribeToAuthor('c' * 64, subscriptionId: 'board');

      // Assert
      expect(backend.subscriptions.containsKey('board'), isTrue);
    });
  });

  group('incoming events', () {
    test('drops an event whose NIP-40 expiration has passed', () async {
      // Arrange
      final seen = <NostrEvent>[];
      service.eventStream.listen(seen.add);

      // Act — expired long ago
      backend.eventsController.add(_event(tags: [
        ['expiration', '1'],
      ]));
      await pumpEventQueue();

      // Assert
      expect(seen, isEmpty);
    });

    test('keeps an event whose expiration lies in the future', () async {
      // Arrange
      final seen = <NostrEvent>[];
      service.eventStream.listen(seen.add);
      final future = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;

      // Act
      backend.eventsController.add(_event(tags: [
        ['expiration', '$future'],
      ]));
      await pumpEventQueue();

      // Assert
      expect(seen, hasLength(1));
    });

    test('keeps an event whose expiration tag is unparseable', () async {
      // Arrange — a malformed tag must not silence a valid event
      final seen = <NostrEvent>[];
      service.eventStream.listen(seen.add);

      // Act
      backend.eventsController.add(_event(tags: [
        ['expiration', 'not-a-number'],
      ]));
      await pumpEventQueue();

      // Assert
      expect(seen, hasLength(1));
    });

    test('caches an addressable event and serves it back by address', () async {
      // Act
      backend.eventsController.add(_event(tags: [
        ['d', 'abcd'],
      ]));
      await pumpEventQueue();

      // Assert
      final cached = service.getAddressableEvent('31415', 'p1', 'abcd');
      expect(cached, isNotNull);
      expect(cached!.id, 'a1');
    });

    test('ignores an addressable event older than the cached one', () async {
      // Arrange — the relay echoes an old state after a newer one arrived
      final seen = <NostrEvent>[];
      service.eventStream.listen(seen.add);
      backend.eventsController.add(_event(
        id: 'newer',
        createdAt: 2000,
        tags: [
          ['d', 'abcd'],
        ],
      ));
      await pumpEventQueue();

      // Act
      backend.eventsController.add(_event(
        id: 'older',
        createdAt: 1000,
        tags: [
          ['d', 'abcd'],
        ],
      ));
      await pumpEventQueue();

      // Assert — the older event is noise, not history
      expect(seen.map((e) => e.id), ['newer']);
      expect(service.getAddressableEvent('31415', 'p1', 'abcd')!.id, 'newer');
    });

    test('forwards a kind 31415 event without a d-tag but does not cache it',
        () async {
      // Arrange
      final seen = <NostrEvent>[];
      service.eventStream.listen(seen.add);

      // Act
      backend.eventsController.add(_event());
      await pumpEventQueue();

      // Assert
      expect(seen, hasLength(1));
      expect(service.getAddressableEvent('31415', 'p1', ''), isNull);
    });

    test('evicts the oldest cached address once the cache exceeds 1000',
        () async {
      // Arrange + Act — 1001 distinct matches flow in
      for (var i = 0; i <= 1000; i++) {
        backend.eventsController.add(_event(
          id: 'id$i',
          createdAt: 1000 + i,
          tags: [
            ['d', 'd$i'],
          ],
        ));
      }
      await pumpEventQueue(times: 1200);

      // Assert — the first address was evicted, the second survives
      expect(service.getAddressableEvent('31415', 'p1', 'd0'), isNull);
      expect(service.getAddressableEvent('31415', 'p1', 'd1'), isNotNull);
    });
  });

  group('publishEvent', () {
    test('throws when no relay is connected, keeping the state pending',
        () async {
      // Arrange
      backend.configuredRelays = ['wss://a'];
      backend.connected = [];

      // Act + Assert
      await expectLater(
        service.publishEvent(_event(tags: [
          ['d', 'abcd'],
        ])),
        throwsException,
      );
      expect(backend.publishes, isEmpty);
    });

    test('succeeds when one relay accepts even though another errors',
        () async {
      // Arrange — relay a explodes, relay b accepts
      backend.configuredRelays = ['wss://a', 'wss://b'];
      backend.connected = ['wss://a', 'wss://b'];
      backend.onPublish = (url, event) async {
        if (url == 'wss://a') throw Exception('socket died');
        return true;
      };

      // Act — must not throw: one acceptance is enough for the caller
      await service.publishEvent(_event(tags: [
        ['d', 'abcd'],
      ]));

      // Assert — both relays were attempted
      expect(backend.publishes.map((p) => p.$1),
          containsAll(['wss://a', 'wss://b']));
    });

    test('returns on the first acceptance, without waiting for a silent relay',
        () async {
      // Arrange — a accepts at once; b takes the event and never answers.
      // A relay going quiet is not hypothetical: nostr-sdk waits a full 10s
      // for an OK before giving up, and the referee's next tap queues behind
      // this call.
      backend.configuredRelays = ['wss://a', 'wss://b'];
      backend.connected = ['wss://a', 'wss://b'];
      final silent = Completer<bool>();
      addTearDown(() => silent.complete(false));
      backend.onPublish = (url, event) =>
          url == 'wss://a' ? Future<bool>.value(true) : silent.future;

      // Act + Assert — one acceptance is the documented success condition, so
      // the call must come back on it rather than on the slowest relay
      await service
          .publishEvent(_event(tags: [
            ['d', 'abcd'],
          ]))
          .timeout(
            const Duration(seconds: 1),
            onTimeout: () => fail('publishEvent waited for the silent relay'),
          );

      // Assert — b was still asked; it is simply not waited on
      expect(backend.publishes.map((p) => p.$1),
          containsAll(['wss://a', 'wss://b']));
    });

    test('throws when every relay rejects the event', () async {
      // Arrange
      backend.configuredRelays = ['wss://a'];
      backend.connected = ['wss://a'];
      backend.onPublish = (url, event) async => false;

      // Act + Assert
      await expectLater(
        service.publishEvent(_event(tags: [
          ['d', 'abcd'],
        ])),
        throwsException,
      );
    });
  });

  group('resend sweep', () {
    test('backs off while a relay keeps refusing, instead of hammering it',
        () async {
      // Arrange — a relay that refuses everything, which is exactly what a
      // rate-limited relay does: `max 5 events per minute per IP` is a fast,
      // repeated no. Retrying it on a fixed heartbeat only spends the limit.
      final sweeper = NostrService(
        _FixedKeyManager(),
        crypto: FakeNostrCrypto(),
        backend: backend,
        resendInterval: const Duration(milliseconds: 50),
      );
      addTearDown(sweeper.dispose);
      backend.configuredRelays = ['wss://a', 'wss://b'];
      backend.connected = ['wss://a', 'wss://b'];
      // a accepts (so the publish succeeds), b never will — b keeps the state
      // pending and the sweep alive.
      backend.onPublish = (url, event) async => url == 'wss://a';

      // Act — one publish, then let the sweep run for 400ms
      await sweeper.publishEvent(_event(tags: [
        ['d', 'abcd'],
      ]));
      final afterPublish = backend.publishes.length;
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Assert — at a flat 50ms the sweep would have fired ~8 times; doubling
      // (50, 100, 200, 400) gets through 3. The bound is loose enough to
      // survive a slow machine and still fail a fixed heartbeat.
      final sweeps = backend.publishes.length - afterPublish;
      expect(sweeps, lessThanOrEqualTo(5),
          reason: 'sweep did not back off: $sweeps resends in 400ms');
      expect(sweeps, greaterThan(0), reason: 'sweep never ran at all');
    });

    test('a reconnect brings the backed-off sweep back to full pace', () async {
      // Arrange — b refuses everything, so the sweep backs off: at a 100ms
      // base the intervals run 100, 200, 400, and by ~750ms the next sweep is
      // already 800ms away. a accepts, so the publish itself succeeds.
      final sweeper = NostrService(
        _FixedKeyManager(),
        crypto: FakeNostrCrypto(),
        backend: backend,
        resendInterval: const Duration(milliseconds: 100),
      );
      addTearDown(sweeper.dispose);
      backend.configuredRelays = ['wss://a', 'wss://b', 'wss://c'];
      backend.connected = ['wss://a', 'wss://b', 'wss://c'];
      backend.onPublish = (url, event) async => url != 'wss://b';

      await sweeper.publishEvent(_event(tags: [
        ['d', 'abcd'],
      ]));
      await Future<void>.delayed(const Duration(milliseconds: 750));
      final beforeReconnect =
          backend.publishes.where((p) => p.$1 == 'wss://b').length;

      // Act — a DIFFERENT relay comes back, so what is measured is the
      // rescheduled sweep rather than the reconnect's own immediate resend
      backend.connectedController.add('wss://c');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      // Assert — b was swept again inside the window. Left at the old pace the
      // next sweep would still be ~750ms out, and a relay that just came back
      // would sit unserved through a backoff it had nothing to do with.
      final sweepsAfter =
          backend.publishes.where((p) => p.$1 == 'wss://b').length -
              beforeReconnect;
      expect(sweepsAfter, greaterThan(0),
          reason: 'the pending timer kept the backed-off delay');
    });

    test('sweeps relays at once, so a silent one cannot stall the others',
        () async {
      // Arrange — the silent relay is FIRST, so a sequential sweep never
      // reaches the second one
      final silent = Completer<bool>();
      addTearDown(() => silent.complete(false));
      final sweeper = NostrService(
        _FixedKeyManager(),
        crypto: FakeNostrCrypto(),
        backend: backend,
        resendInterval: const Duration(milliseconds: 50),
      );
      addTearDown(sweeper.dispose);
      backend.configuredRelays = ['wss://silent', 'wss://slowpoke', 'wss://c'];
      backend.connected = ['wss://silent', 'wss://slowpoke', 'wss://c'];
      backend.onPublish = (url, event) {
        if (url == 'wss://silent') return silent.future;
        // c accepts, so the publish itself succeeds; slowpoke refuses, which
        // keeps the state pending and the sweep running.
        return Future<bool>.value(url == 'wss://c');
      };

      // Act
      await sweeper.publishEvent(_event(tags: [
        ['d', 'abcd'],
      ]));
      final afterPublish = backend.publishes.length;
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Assert — slowpoke was reached even though silent never answered
      final resent = backend.publishes.skip(afterPublish).map((p) => p.$1);
      expect(resent, contains('wss://slowpoke'));
    });
  });

  group('convergence on reconnect', () {
    test('resends the pending latest state to a relay that comes back',
        () async {
      // Arrange — b is configured but down, so the publish leaves it pending
      backend.configuredRelays = ['wss://a', 'wss://b'];
      backend.connected = ['wss://a'];
      await service.publishEvent(_event(tags: [
        ['d', 'abcd'],
      ]));
      expect(backend.publishes, hasLength(1));

      // Act — b reconnects
      backend.connected = ['wss://a', 'wss://b'];
      backend.connectedController.add('wss://b');
      await pumpEventQueue();

      // Assert — the same event went out again, to b this time
      expect(backend.publishes, hasLength(2));
      expect(backend.publishes.last.$1, 'wss://b');
    });

    test('swallows a resend failure and keeps the state pending', () async {
      // Arrange — as above, but b's socket dies during the resend
      backend.configuredRelays = ['wss://a', 'wss://b'];
      backend.connected = ['wss://a'];
      await service.publishEvent(_event(tags: [
        ['d', 'abcd'],
      ]));
      backend.onPublish = (url, event) async {
        throw Exception('still broken');
      };

      // Act — must not surface: convergence retries, it does not crash.
      // Keep the connected view consistent with the event we emit: a relay
      // that announces itself connected must also report as connected.
      backend.connected = ['wss://a', 'wss://b'];
      backend.connectedController.add('wss://b');
      await pumpEventQueue();

      // Assert — the resend was attempted and survived the failure; a later
      // reconnect still finds the state pending and retries
      expect(backend.publishes, hasLength(2));
      backend.onPublish = null;
      backend.connectedController.add('wss://b');
      await pumpEventQueue();
      expect(backend.publishes, hasLength(3));
    });
  });

  group('publishAddressableEvent', () {
    test('throws when the identity keys are missing', () async {
      // Arrange
      final keyless = NostrService(
        _NoKeyManager(),
        crypto: FakeNostrCrypto(),
        backend: backend,
      );
      addTearDown(keyless.dispose);

      // Act + Assert
      await expectLater(
        keyless.publishAddressableEvent(dTag: 'abcd', content: '{}'),
        throwsException,
      );
    });

    test('refuses to publish an event that fails self-verification', () async {
      // Arrange — a malformed signature must fail loudly here, not silently
      // at the relay
      final selfDoubting = NostrService(
        _FixedKeyManager(),
        crypto: _RejectingCrypto(),
        backend: backend,
      );
      addTearDown(selfDoubting.dispose);
      backend.configuredRelays = ['wss://a'];
      backend.connected = ['wss://a'];

      // Act + Assert
      await expectLater(
        selfDoubting.publishAddressableEvent(dTag: 'abcd', content: '{}'),
        throwsException,
      );
      expect(backend.publishes, isEmpty);
    });

    test('signs, tags and publishes the addressable event', () async {
      // Arrange
      backend.configuredRelays = ['wss://a'];
      backend.connected = ['wss://a'];

      // Act
      await service.publishAddressableEvent(
        dTag: 'abcd',
        content: '{"status":"finished"}',
        additionalTags: [
          ['expiration', '9999999999'],
        ],
      );

      // Assert — one publish went out, carrying the signed event
      expect(backend.publishes, hasLength(1));
      expect(backend.publishes.single.$1, 'wss://a');
    });
  });

  test('nostrServiceProvider refuses to build without an override', () {
    // Arrange — a default service would mean a second relay pool competing
    // with the real one
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Act + Assert
    expect(
      () => container.read(nostrServiceProvider),
      throwsUnimplementedError,
    );
  });

  group('addressable replacement through the service', () {
    // The bug was never that the rule was wrong; it was two call sites
    // disagreeing about it, and this was one of them. It also changed
    // behaviour here in a way nothing observed: an equal-timestamp event used
    // to be dropped unconditionally, so it never reached eventStream, and a
    // lower-id one is now forwarded.
    const lowId = 'aaaa11111111111111111111111111111111111111111111111111111111';
    const highId = 'ffff11111111111111111111111111111111111111111111111111111111';

    /// Deliver two revisions of one match, stamped the same second, in [ids]
    /// order, and report which ids reached the stream.
    Future<List<String>> deliver(List<String> ids) async {
      final backend = RecordingRelayBackend();
      final service = NostrService(
        KeyManager(crypto: FakeNostrCrypto()),
        crypto: FakeNostrCrypto(),
        backend: backend,
      );
      addTearDown(service.dispose);

      final seen = <NostrEvent>[];
      service.eventStream.listen(seen.add);

      for (final id in ids) {
        backend.eventsController.add(_event(
          id: id,
          createdAt: 1000,
          tags: [
            ['d', 'abcd'],
          ],
        ));
        await pumpEventQueue();
      }
      return seen.map((e) => e.id).toList();
    }

    test('the lowest id ends up held, whichever order they arrive in',
        () async {
      // Act
      final lowFirst = await deliver([lowId, highId]);
      final highFirst = await deliver([highId, lowId]);

      // Assert — what is HELD is the same either way, which is the property
      // that stops two devices showing different scores
      expect(lowFirst.last, lowId);
      expect(highFirst.last, lowId);
    });

    test('the loser of a tie is not forwarded', () async {
      // Act
      final lowFirst = await deliver([lowId, highId]);

      // Assert — the high id arrived second and lost, so consumers never see it
      expect(lowFirst, [lowId]);
    });

    test('the winner of a tie is forwarded when it arrives second', () async {
      // Act
      final highFirst = await deliver([highId, lowId]);

      // Assert — both reach the stream, in order, and the last one is the
      // winner. Consumers downstream follow the last they are given.
      expect(highFirst, [highId, lowId]);
    });
  });

  group('addressableSupersedes', () {
    // NIP-01: a replacement needs a strictly newer created_at, and on a tie the
    // event with the LOWEST id wins.
    bool wins(int newAt, String newId, int oldAt, String oldId) =>
        addressableSupersedes(
          arrivingCreatedAt: newAt,
          arrivingId: newId,
          heldCreatedAt: oldAt,
          heldId: oldId,
        );

    test('a newer timestamp replaces an older one', () {
      expect(wins(200, 'ffff', 100, 'aaaa'), isTrue);
    });

    test('an older timestamp never replaces a newer one', () {
      expect(wins(100, 'aaaa', 200, 'ffff'), isFalse,
          reason: 'not even with the lower id');
    });

    test('on a tie the lowest id wins', () {
      expect(wins(100, 'aaaa', 100, 'ffff'), isTrue);
      expect(wins(100, 'ffff', 100, 'aaaa'), isFalse);
    });

    test('the same event does not replace itself', () {
      expect(wins(100, 'aaaa', 100, 'aaaa'), isFalse);
    });

    test('works on real 64-character ids, not just short fixtures', () {
      // The short ids elsewhere in this group would pass a rule that broke on
      // the length or shape of an actual event id.
      const low = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
      const high = 'f1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
      expect(wins(100, low, 100, high), isTrue);
      expect(wins(100, high, 100, low), isFalse);
    });

    test('case does not decide it', () {
      // Lexicographic order only matches numeric order when both sides agree on
      // case: 'A'.compareTo('a') is -1. An id that arrived uppercase would
      // otherwise order backwards and bring back the divergence this removes.
      expect(wins(100, 'AAAA', 100, 'ffff'), isTrue);
      expect(wins(100, 'FFFF', 100, 'aaaa'), isFalse);
      expect(wins(100, 'AAAA', 100, 'aaaa'), isFalse,
          reason: 'the same id in another case is still the same id');
    });

    test('the outcome does not depend on which arrived first', () {
      // The whole point: two devices seeing the pair in opposite orders must
      // end up holding the same revision.
      const early = (at: 100, id: 'aaaa');
      const late = (at: 100, id: 'ffff');

      // Device A sees `late` first, then `early`.
      final aKeepsEarly = wins(early.at, early.id, late.at, late.id);
      // Device B sees `early` first, then `late`.
      final bKeepsEarly = !wins(late.at, late.id, early.at, early.id);

      expect(aKeepsEarly, isTrue);
      expect(bKeepsEarly, isTrue);
    });
  });
}
