import 'dart:async';

import 'package:choke/services/nostr/crypto/nostr_crypto.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/services/nostr/relay/nostr_relay_backend.dart';

/// Stand-ins for tests that construct a [NostrService] but never publish
/// through it — screen tests, provider tests, the timestamp tests.
///
/// They exist because `NostrService` now *requires* its crypto and its
/// transport. That is deliberate: the defaults it used to carry pointed at the
/// legacy implementations, and once those were deleted a default could only
/// have been a lie. A test that does not care says so, here, out loud.
class FakeNostrCrypto implements NostrCrypto {
  @override
  String generatePrivateKey() => 'f' * 64;

  @override
  String getPublicKey(String privateKeyHex) => 'e' * 64;

  @override
  String npubEncode(String publicKeyHex) => 'npub1fake';

  @override
  String nsecEncode(String privateKeyHex) => 'nsec1fake';

  @override
  String? nsecDecode(String nsec) => nsec == 'nsec1fake' ? 'f' * 64 : null;

  @override
  String? npubDecode(String npub) => npub == 'npub1fake' ? 'b' * 64 : null;

  @override
  NostrEvent finishEvent(UnsignedNostrEvent event, String privateKeyHex) {
    return NostrEvent(
      id: 'a' * 64,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      kind: event.kind,
      tags: event.tags,
      content: event.content,
      sig: 'b' * 128,
    );
  }

  @override
  bool verifyEvent(NostrEvent event) => true;
}

/// A transport that records every call made to it, so a test can assert on
/// what `NostrService` asked of its backend — which relays it added, what it
/// subscribed to, where it published — without any sockets existing.
///
/// Incoming traffic is simulated by adding to [eventsController] (a relay
/// delivered an event) or [connectedController] (a relay (re)connected).
class RecordingRelayBackend implements NostrRelayBackend {
  final eventsController = StreamController<NostrEvent>.broadcast();
  final connectedController = StreamController<String>.broadcast();

  final List<String> addedRelays = [];
  final List<String> removedRelays = [];
  final Map<String, Filter> subscriptions = {};
  final List<String> unsubscribed = [];
  final List<(String url, String eventId)> publishes = [];
  int disconnectCalls = 0;
  int reconnectCalls = 0;

  /// What [relayUrls] and [connectedRelays] report; a test sets these to model
  /// the pool's state.
  List<String> configuredRelays = [];
  List<String> connected = [];

  /// The verdict [publish] returns per relay; defaults to accepting.
  Future<bool> Function(String url, NostrEvent event)? onPublish;

  @override
  Stream<NostrEvent> get events => eventsController.stream;

  @override
  Stream<String> get onRelayConnected => connectedController.stream;

  @override
  List<String> get relayUrls => configuredRelays;

  @override
  List<String> get connectedRelays => connected;

  @override
  Future<void> addRelay(String url) async {
    addedRelays.add(url);
  }

  @override
  void removeRelay(String url) => removedRelays.add(url);

  @override
  Future<void> reconnectAll() async {
    reconnectCalls++;
  }

  @override
  void subscribe(String subscriptionId, Filter filter) {
    subscriptions[subscriptionId] = filter;
  }

  @override
  void unsubscribe(String subscriptionId) => unsubscribed.add(subscriptionId);

  @override
  Future<bool> publish(String relayUrl, NostrEvent event) {
    publishes.add((relayUrl, event.id));
    final handler = onPublish;
    if (handler != null) return handler(relayUrl, event);
    return Future.value(true);
  }

  @override
  bool isAwaitingOk(String relayUrl, String eventId) => false;

  @override
  void disconnect() => disconnectCalls++;

  @override
  void dispose() {
    eventsController.close();
    connectedController.close();
  }
}

/// A transport that is wired up and connected to nothing.
class FakeRelayBackend implements NostrRelayBackend {
  final _events = StreamController<NostrEvent>.broadcast();
  final _connected = StreamController<String>.broadcast();

  @override
  Stream<NostrEvent> get events => _events.stream;

  @override
  Stream<String> get onRelayConnected => _connected.stream;

  @override
  List<String> get relayUrls => const [];

  @override
  List<String> get connectedRelays => const [];

  @override
  Future<void> addRelay(String url) async {}

  @override
  void removeRelay(String url) {}

  @override
  Future<void> reconnectAll() async {}

  @override
  void subscribe(String subscriptionId, Filter filter) {}

  @override
  void unsubscribe(String subscriptionId) {}

  @override
  Future<bool> publish(String relayUrl, NostrEvent event) async => true;

  @override
  bool isAwaitingOk(String relayUrl, String eventId) => false;

  @override
  void disconnect() {}

  @override
  void dispose() {
    _events.close();
    _connected.close();
  }
}
