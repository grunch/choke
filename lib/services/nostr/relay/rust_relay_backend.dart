import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../src/rust/api/crypto.dart' as rust_crypto;
import '../../../src/rust/api/relay.dart' as rust;
import '../nostr_service.dart' show NostrEvent;
import 'nostr_relay_backend.dart';

/// [NostrRelayBackend] over `nostr-sdk`'s relay pool, reached through
/// flutter_rust_bridge.
///
/// Rust owns the sockets, the reconnection and the NIP-01 framing. What this
/// class owns is the small amount of state the interface promises
/// *synchronously* — which relays exist, and which are up — because callers ask
/// those questions on the hot path (deciding where to publish a score) and
/// cannot await an FFI round-trip to find out.
///
/// That view is fed by the Rust status stream, which reports connections *and*
/// disconnections. A stream that only announced connections would leave the
/// view permanently optimistic: the app would go on publishing into a relay
/// that had left, and the referee would never know.
///
/// See docs/specs/nostr-sdk-migration.md.
class RustRelayBackend implements NostrRelayBackend {
  final _eventController = StreamController<NostrEvent>.broadcast();
  final _relayConnectedController = StreamController<String>.broadcast();

  /// Every relay this backend was asked to hold, connected or not. Kept here
  /// rather than read back from Rust because convergence is measured against
  /// it, and it must not flicker with the network.
  final Set<String> _relayUrls = {};

  /// The subset currently up, per the Rust status stream.
  final Set<String> _connected = {};

  /// Publishes awaiting a verdict, by relay. `nostr-sdk` does not expose its
  /// in-flight table, and the caller needs the answer to avoid sending a slow
  /// relay the same event twice, so it is tracked on this side.
  final Map<String, Set<String>> _awaitingOk = {};

  StreamSubscription<rust_crypto.SignedEventData>? _events;
  StreamSubscription<rust.RelayStatusData>? _status;

  RustRelayBackend() {
    _events = rust.relayEventStream().listen(
          (event) => _eventController.add(_toNostrEvent(event)),
          onError: (Object e) =>
              debugPrint('RustRelayBackend: event stream: $e'),
        );

    _status = rust.relayStatusStream().listen(
          _onStatusChange,
          onError: (Object e) =>
              debugPrint('RustRelayBackend: status stream: $e'),
        );
  }

  void _onStatusChange(rust.RelayStatusData change) {
    // The Rust status stream is process-wide, and a relay's connection task can
    // still be (re)connecting when this backend removes it. A late `connected`
    // for a relay already dropped from _relayUrls must not resurrect it in
    // _connected, or connectedRelays would hand NostrService a relay the user
    // removed — publishing scores to it while convergence no longer counts it.
    if (!_relayUrls.contains(change.url)) return;

    if (change.connected) {
      _connected.add(change.url);
      _relayConnectedController.add(change.url);
      debugPrint('RustRelayBackend: connected ${change.url}');
    } else {
      _connected.remove(change.url);
      debugPrint('RustRelayBackend: disconnected ${change.url}');
    }
  }

  /// Whether [url] answers a relay's WebSocket handshake within [timeout].
  ///
  /// Settings vets a URL with this before saving it. Static, because it
  /// deliberately does not touch this backend's pool: the handshake happens in
  /// the Rust crate on a throwaway client (`relay_probe`), so a candidate URL
  /// inherits no subscriptions and leaves nothing behind if the user walks
  /// away. Dart opens no socket here — relay networking stays in Rust.
  static Future<bool> probe(String url, {required Duration timeout}) {
    return rust.relayProbe(url: url, timeoutMs: timeout.inMilliseconds);
  }

  @override
  Stream<NostrEvent> get events => _eventController.stream;

  @override
  Stream<String> get onRelayConnected => _relayConnectedController.stream;

  @override
  List<String> get relayUrls => _relayUrls.toList();

  @override
  List<String> get connectedRelays => _connected.toList();

  @override
  Future<void> addRelay(String url) async {
    if (!_relayUrls.add(url)) return;
    try {
      await rust.relayAdd(url: url);
    } catch (_) {
      // Registering it failed outright — do not leave a phantom in the
      // convergence set, or every match would wait forever on a relay that
      // does not exist.
      _relayUrls.remove(url);
      rethrow;
    }
  }

  @override
  void removeRelay(String url) {
    _relayUrls.remove(url);
    _connected.remove(url);
    _awaitingOk.remove(url);
    unawaited(rust.relayRemove(url: url));
  }

  @override
  Future<void> reconnectAll() => rust.relayReconnectAll();

  @override
  void subscribe(String subscriptionId, Filter filter) {
    unawaited(
      rust.relaySubscribe(
        subscriptionId: subscriptionId,
        filter: rust.FilterData(
          kinds: Uint16List.fromList(filter.kinds ?? const []),
          authors: filter.authors ?? const [],
          ids: filter.ids ?? const [],
          since: filter.since,
          until: filter.until,
          limit: filter.limit,
        ),
      ),
    );
  }

  @override
  void unsubscribe(String subscriptionId) {
    unawaited(rust.relayUnsubscribe(subscriptionId: subscriptionId));
  }

  @override
  Future<bool> publish(String relayUrl, NostrEvent event) async {
    final inFlight = _awaitingOk.putIfAbsent(relayUrl, () => <String>{});
    inFlight.add(event.id);
    try {
      return await rust.relayPublish(
        url: relayUrl,
        event: _toSignedEventData(event),
      );
    } finally {
      inFlight.remove(event.id);
    }
  }

  @override
  bool isAwaitingOk(String relayUrl, String eventId) =>
      _awaitingOk[relayUrl]?.contains(eventId) ?? false;

  @override
  void disconnect() {
    _connected.clear();
    unawaited(rust.relayDisconnect());
  }

  @override
  void dispose() {
    _events?.cancel();
    _status?.cancel();

    // Drop this backend's own relays rather than calling disconnect(): the Rust
    // pool is process-wide, and tearing down every socket in it is not this
    // instance's business.
    for (final url in _relayUrls.toList()) {
      removeRelay(url);
    }

    _eventController.close();
    _relayConnectedController.close();
  }

  static NostrEvent _toNostrEvent(rust_crypto.SignedEventData event) {
    return NostrEvent(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      kind: event.kind,
      tags: event.tags,
      content: event.content,
      sig: event.sig,
    );
  }

  static rust_crypto.SignedEventData _toSignedEventData(NostrEvent event) {
    return rust_crypto.SignedEventData(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      kind: event.kind,
      tags: event.tags,
      content: event.content,
      sig: event.sig,
    );
  }
}
