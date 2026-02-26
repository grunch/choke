import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../key_management/key_manager.dart';

/// Nostr Event model
class NostrEvent {
  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String sig;

  NostrEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    required this.sig,
  });

  factory NostrEvent.fromJson(Map<String, dynamic> json) {
    return NostrEvent(
      id: json['id'] as String,
      pubkey: json['pubkey'] as String,
      createdAt: json['created_at'] as int,
      kind: json['kind'] as int,
      tags: (json['tags'] as List<dynamic>)
          .map((t) => (t as List<dynamic>).map((e) => e as String).toList())
          .toList(),
      content: json['content'] as String,
      sig: json['sig'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': kind,
      'tags': tags,
      'content': content,
      'sig': sig,
    };
  }
}

/// Filter for Nostr subscriptions
class Filter {
  final List<int>? kinds;
  final List<String>? authors;
  final List<String>? ids;
  final String? search;
  final int? since;
  final int? until;
  final int? limit;

  Filter({
    this.kinds,
    this.authors,
    this.ids,
    this.search,
    this.since,
    this.until,
    this.limit,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (kinds != null) map['kinds'] = kinds;
    if (authors != null) map['authors'] = authors;
    if (ids != null) map['ids'] = ids;
    if (search != null) map['search'] = search;
    if (since != null) map['since'] = since;
    if (until != null) map['until'] = until;
    if (limit != null) map['limit'] = limit;
    return map;
  }
}

/// Represents a Nostr relay connection
class RelayConnection {
  final String url;
  bool isConnected = false;
  WebSocket? _socket;
  final _messageController = StreamController<NostrEvent>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  Timer? _reconnectTimer;
  final Set<String> _activeSubscriptions = {};
  final Map<String, Filter> _subscriptionFilters = {};

  RelayConnection(this.url);

  Stream<NostrEvent> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  Future<void> connect() async {
    try {
      _socket = await WebSocket.connect(url);
      isConnected = true;
      _connectionController.add(true);
      debugPrint('NostrService: Connected to $url');

      _socket!.listen(
        (data) => _handleMessage(data),
        onError: (error) {
          debugPrint('NostrService: Error on $url: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('NostrService: Disconnected from $url');
          _handleDisconnect();
        },
      );

      // Resubscribe to active subscriptions after reconnection
      for (final entry in _subscriptionFilters.entries) {
        _subscribe(entry.key, entry.value);
      }
    } catch (e) {
      debugPrint('NostrService: Failed to connect to $url: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as List<dynamic>;
      if (message.isEmpty) return;

      final type = message[0] as String;
      if (type == 'EVENT' && message.length >= 3) {
        final eventData = message[2] as Map<String, dynamic>;
        final event = NostrEvent.fromJson(eventData);
        _messageController.add(event);
      }
    } catch (e) {
      debugPrint('NostrService: Error parsing message: $e');
    }
  }

  void _handleDisconnect() {
    if (!isConnected) return;
    isConnected = false;
    _connectionController.add(false);
    _socket?.close();
    _socket = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('NostrService: Attempting reconnect to $url');
      connect();
    });
  }

  void subscribe(String subscriptionId, Filter filter) {
    _activeSubscriptions.add(subscriptionId);
    _subscriptionFilters[subscriptionId] = filter;
    if (!isConnected) return;
    _subscribe(subscriptionId, filter);
  }

  void _subscribe(String subscriptionId, Filter filter) {
    final message = jsonEncode([
      'REQ',
      subscriptionId,
      filter.toJson(),
    ]);
    _socket?.add(message);
  }

  void unsubscribe(String subscriptionId) {
    _activeSubscriptions.remove(subscriptionId);
    _subscriptionFilters.remove(subscriptionId);
    if (!isConnected) return;

    final message = jsonEncode(['CLOSE', subscriptionId]);
    _socket?.add(message);
  }

  Future<void> publish(NostrEvent event) async {
    if (!isConnected) {
      throw Exception('Not connected to relay $url');
    }

    final message = jsonEncode(['EVENT', event.toJson()]);
    _socket?.add(message);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _socket?.close();
    isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}

/// Service for managing Nostr relay connections and event handling
class NostrService {
  final KeyManager _keyManager;
  final Map<String, RelayConnection> _relays = {};
  final _eventController = StreamController<NostrEvent>.broadcast();
  final Map<String, NostrEvent> _addressableEvents = {};

  NostrService(this._keyManager);

  Stream<NostrEvent> get eventStream => _eventController.stream;

  /// Connect to default relays on app start
  Future<void> initialize() async {
    await addRelay('wss://relay.mostro.network');
    await addRelay('wss://nos.lol');
  }

  /// Add a custom relay
  Future<void> addRelay(String url) async {
    if (_relays.containsKey(url)) {
      debugPrint('NostrService: Relay $url already exists');
      return;
    }

    final relay = RelayConnection(url);
    _relays[url] = relay;

    // Listen to events from this relay
    relay.messageStream.listen((event) {
      _handleIncomingEvent(event);
    });

    await relay.connect();
  }

  /// Remove a relay
  void removeRelay(String url) {
    final relay = _relays.remove(url);
    relay?.dispose();
  }

  /// Subscribe to kind 31925 events for the current user
  Future<void> subscribeToUserEvents() async {
    final publicKey = await _keyManager.getPublicKeyHex();
    if (publicKey == null) {
      throw Exception('No public key available');
    }

    final filter = Filter(
      kinds: [31925],
      authors: [publicKey],
    );

    for (final relay in _relays.values) {
      relay.subscribe('user_events', filter);
    }
  }

  /// Subscribe to kind 31925 events from a specific author
  void subscribeToAuthor(String authorPubkey, {String? subscriptionId}) {
    final filter = Filter(
      kinds: [31925],
      authors: [authorPubkey],
    );

    final subId = subscriptionId ?? 'author_$authorPubkey';
    for (final relay in _relays.values) {
      relay.subscribe(subId, filter);
    }
  }

  /// Unsubscribe from a subscription
  void unsubscribe(String subscriptionId) {
    for (final relay in _relays.values) {
      relay.unsubscribe(subscriptionId);
    }
  }

  /// Handle incoming events with addressable event logic
  void _handleIncomingEvent(NostrEvent event) {
    // Check for NIP-40 expiration
    final expirationTag = event.tags.firstWhere(
      (tag) => tag.isNotEmpty && tag[0] == 'expiration',
      orElse: () => [],
    );
    if (expirationTag.isNotEmpty && expirationTag.length > 1) {
      final expiration = int.tryParse(expirationTag[1]);
      if (expiration != null &&
          expiration < DateTime.now().millisecondsSinceEpoch ~/ 1000) {
        debugPrint('NostrService: Ignoring expired event ${event.id}');
        return;
      }
    }

    // Addressable event replacement logic (kind, pubkey, d-tag)
    if (event.kind == 31925) {
      final dTag = event.tags.firstWhere(
        (tag) => tag.isNotEmpty && tag[0] == 'd',
        orElse: () => [],
      );
      if (dTag.isNotEmpty && dTag.length > 1) {
        final addressKey = '${event.kind}:${event.pubkey}:${dTag[1]}';

        // Check if we have a newer version
        final existing = _addressableEvents[addressKey];
        if (existing != null && existing.createdAt >= event.createdAt) {
          debugPrint('NostrService: Ignoring older event $addressKey');
          return;
        }

        _addressableEvents[addressKey] = event;
      }
    }

    _eventController.add(event);
  }

  /// Publish a signed event to all connected relays
  Future<void> publishEvent(NostrEvent event) async {
    final connectedRelays = _relays.values.where((r) => r.isConnected).toList();

    if (connectedRelays.length < 2) {
      throw Exception('Need at least 2 connected relays for redundancy');
    }

    final futures = connectedRelays.map((relay) => relay.publish(event));
    await Future.wait(futures);
  }

  /// Create and publish a kind 31925 addressable event
  Future<void> publishAddressableEvent({
    required String dTag,
    required String content,
    List<List<String>> additionalTags = const [],
  }) async {
    final privateKey = await _keyManager.getPrivateKeyHex();
    final publicKey = await _keyManager.getPublicKeyHex();

    if (privateKey == null || publicKey == null) {
      throw Exception('Keys not available');
    }

    final tags = [
      ['d', dTag],
      ...additionalTags,
    ];

    // Create event data for signing
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Calculate event id (hash of serialized event)
    final id = _calculateEventId(
      pubkey: publicKey,
      createdAt: createdAt,
      kind: 31925,
      tags: tags,
      content: content,
    );

    // Sign the event
    // TODO: Implement proper Schnorr signature using secp256k1
    final sig = _signEventId(id, privateKey);

    final event = NostrEvent(
      id: id,
      pubkey: publicKey,
      createdAt: createdAt,
      kind: 31925,
      tags: tags,
      content: content,
      sig: sig,
    );

    await publishEvent(event);
  }

  /// Sign event id with private key (Schnorr signature)
  /// TODO: Implement proper secp256k1 Schnorr signature
  String _signEventId(String eventId, String privateKeyHex) {
    // Placeholder: returns a dummy signature
    // In production, use pointycastle or similar for secp256k1 Schnorr
    return '${privateKeyHex.substring(0, 16)}_signature_placeholder';
  }

  /// Calculate event id from serialized event data
  String _calculateEventId({
    required String pubkey,
    required int createdAt,
    required int kind,
    required List<List<String>> tags,
    required String content,
  }) {
    final serialized = jsonEncode([0, pubkey, createdAt, kind, tags, content]);
    // Note: This should be SHA-256 hashed. Using a placeholder for now.
    // TODO: Implement proper SHA-256 hashing
    return 'placeholder_${serialized.hashCode}';
  }

  /// Get the latest addressable event for a given key
  NostrEvent? getAddressableEvent(String kind, String pubkey, String dTag) {
    final key = '$kind:$pubkey:$dTag';
    return _addressableEvents[key];
  }

  /// Get list of connected relays
  List<String> get connectedRelays =>
      _relays.values.where((r) => r.isConnected).map((r) => r.url).toList();

  /// Disconnect all relays
  void disconnect() {
    for (final relay in _relays.values) {
      relay.disconnect();
    }
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}

/// Provider for NostrService
final nostrServiceProvider = Provider<NostrService>((ref) {
  final keyManager = ref.watch(keyManagerProvider);
  return NostrService(keyManager);
});
