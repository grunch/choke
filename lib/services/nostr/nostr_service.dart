import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/nostr_relays.dart';
import '../key_management/key_manager.dart';
import 'crypto/nostr_crypto.dart';
import 'relay/nostr_relay_backend.dart';

/// A signed Nostr event.
///
/// Deliberately free of any crypto library's types: translating to and from
/// those is [NostrCrypto]'s business, which is what lets the backend change
/// without the rest of the app noticing.
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

/// Whether an arriving addressable event replaces the one already held.
///
/// NIP-01: a replacement needs a strictly newer `created_at`, and **on a tie the
/// event with the lowest id wins**. The tie is not exotic — scoring twice inside
/// one second is an ordinary thing for a referee to do — and without the id
/// comparison the winner is whichever event the relays happened to deliver
/// first, so two phones watching one board could settle on different revisions
/// of the same match and show different scores.
///
/// One function because there is one rule: the service and every feed that
/// keeps its own copy have to agree, and two implementations of "which is
/// newer" is exactly how they would stop agreeing.
///
/// Ids are compared case-insensitively. NIP-01 ids are lowercase hex and every
/// relay sends them that way, but lexicographic order only matches numeric
/// order when both operands agree on case — `'A'.compareTo('a')` is -1 — and an
/// id that arrived uppercase from anywhere would order backwards and reproduce
/// the very divergence this exists to remove. Cheap insurance against a
/// precondition nothing enforces.
bool addressableSupersedes({
  required int arrivingCreatedAt,
  required String arrivingId,
  required int heldCreatedAt,
  required String heldId,
}) {
  if (arrivingCreatedAt != heldCreatedAt) {
    return arrivingCreatedAt > heldCreatedAt;
  }
  return arrivingId.toLowerCase().compareTo(heldId.toLowerCase()) < 0;
}

/// Publishing matches to Nostr, reliably.
///
/// The transport lives behind [NostrRelayBackend]. What stays here is
/// everything that makes publishing *trustworthy*, and it stays here on
/// purpose — each piece was bought with a real bug:
///
/// - **Convergence** (I3): a publish succeeds as soon as one relay accepts, so
///   the referee is never left waiting. But relays that were down, silent, or
///   that rejected the event keep being resent the latest state until every
///   configured relay has it. "One relay accepted" used to be treated as
///   "done", which left the relay someone was actually watching showing a
///   stale scoreboard (#78).
/// - **Monotonic `created_at`** (I1): relays keep one event per
///   (kind, pubkey, d-tag) and, per NIP-01, a replacement needs a strictly
///   newer timestamp — on a tie the *old* event wins. Two scores in the same
///   second would otherwise leave the relay holding the earlier one.
/// - **Supersession**: only the newest state per match is ever resent. These
///   events are addressable; an older one is not history, it is noise.
///
/// None of that belongs to a transport, which is why swapping the transport
/// (Phase 6) cannot quietly undo it. See docs/specs/nostr-sdk-migration.md.
class NostrService {
  static const int _maxCachedEvents = 1000; // Max addressable events to cache

  final KeyManager _keyManager;
  final NostrRelayBackend _backend;

  /// Signs and verifies the events this service publishes. Injected so the
  /// crypto backend can be swapped without touching the relay layer.
  final NostrCrypto _crypto;

  final _eventController = StreamController<NostrEvent>.broadcast();
  final Map<String, NostrEvent> _addressableEvents = {};
  final Map<String, int> _lastCreatedAt = {};

  StreamSubscription<NostrEvent>? _backendEvents;
  StreamSubscription<String>? _backendConnections;

  /// Latest signed event per d-tag that some relay has not accepted yet, and
  /// the relay urls that already did. "One relay accepted" is enough for the
  /// caller, but every configured relay must converge to the latest state —
  /// stragglers are resent on reconnect and by [_resendTimer].
  final Map<String, NostrEvent> _pendingLatest = {};
  final Map<String, Set<String>> _pendingAcks = {};
  Timer? _resendTimer;

  /// How often relays that are connected but still missing the latest event
  /// (because they rejected it) are retried — the pace of a sweep that is
  /// getting somewhere.
  final Duration resendInterval;

  /// The slowest the sweep may get after repeated refusals.
  final Duration maxResendInterval;

  /// Consecutive sweeps in which no relay accepted anything. Doubles the
  /// interval; any acceptance resets it.
  int _sweepFailures = 0;

  NostrService(
    this._keyManager, {
    required NostrCrypto crypto,
    required NostrRelayBackend backend,
    this.resendInterval = const Duration(seconds: 5),
    this.maxResendInterval = const Duration(minutes: 1),
  })  : _crypto = crypto,
        _backend = backend {
    _backendEvents = _backend.events.listen(_handleIncomingEvent);
    _backendConnections = _backend.onRelayConnected.listen((url) async {
      // A relay that just came back may have missed events while it was away —
      // bring it up to date now, rather than on the referee's next score.
      //
      // A reconnect is also new information: whatever the sweep had been
      // backing off from, this relay has not refused anything yet, so the
      // pace starts over.
      _sweepFailures = 0;
      await _resendPendingTo(url);

      // Resetting the counter is not enough on its own. Any sweep already
      // scheduled was timed against the OLD, backed-off pace — up to
      // [maxResendInterval] away — and [_scheduleResendSweep] keeps whatever
      // timer it finds. The relay that just came back would then wait out a
      // backoff earned by a relay that is still refusing. Drop the stale timer
      // so the reschedule below uses the reset interval.
      //
      // Only this reconnect-driven reset cancels; publishes still reuse a
      // pending timer, which is what keeps a burst of scores cheap.
      _resendTimer?.cancel();
      _resendTimer = null;
      _scheduleResendSweep();
    });
  }

  /// Every event from every relay that survived filtering: expired ones
  /// (NIP-40) and ones superseded by a newer state for the same match are
  /// dropped before they get here.
  Stream<NostrEvent> get eventStream => _eventController.stream;

  /// Fires with the relay URL each time a relay (re)connects. Publishers
  /// holding unconfirmed state listen to this to retry immediately instead
  /// of waiting out a backoff against a relay that just came back.
  Stream<String> get onRelayConnected => _backend.onRelayConnected;

  /// Connect to configured relays on app start
  Future<void> initialize({List<String>? relayUrls}) async {
    for (final url in relayUrls ?? defaultNostrRelays) {
      await addRelay(url);
    }
  }

  /// Add a custom relay
  Future<void> addRelay(String url) => _backend.addRelay(url);

  /// Remove a relay
  void removeRelay(String url) => _backend.removeRelay(url);

  /// Recycle every relay connection with a fresh socket.
  ///
  /// Meant for app resume: the OS kills sockets in the background without a
  /// close frame, so connections can look open while dropping every event.
  Future<void> reconnectAll() => _backend.reconnectAll();

  /// Subscribe to kind 31415 events for the current user
  Future<void> subscribeToUserEvents() async {
    final publicKey = await _keyManager.getPublicKeyHex();
    if (publicKey == null) {
      throw Exception('No public key available');
    }

    _userPubkey = publicKey;

    _backend.subscribe(
      'user_events',
      Filter(kinds: [31415], authors: [publicKey]),
    );
  }

  String? _userPubkey;

  /// Re-read the identity and point the subscription at it.
  ///
  /// Call after the key changes. [subscribeToUserEvents] reuses the same
  /// subscription id, and a REQ that repeats an id replaces it, so the relays
  /// stop sending the old identity's matches and start sending the new one's.
  ///
  /// Without this the service keeps answering [userPubkey] with the key the app
  /// started with, and the home feed — which believes it — throws away the
  /// user's own matches under their new identity.
  Future<void> refreshIdentity() => subscribeToUserEvents();

  /// This device's own public key, once [subscribeToUserEvents] has looked it
  /// up, and null before that.
  ///
  /// Exposed because [eventStream] carries the events of every subscription with
  /// no way to tell which filter matched them, so a consumer that wants only
  /// this user's matches — the home feed — has to be able to ask who this user
  /// is. Threading the key in from the key manager separately would instead let
  /// the two disagree about whose matches they are looking at.
  String? get userPubkey => _userPubkey;

  /// Subscribe to kind 31415 events from a specific author.
  ///
  /// The default id is deliberately short. NIP-01 caps a subscription id at 64
  /// characters and a relay refuses the whole REQ over it — nos.lol answers
  /// `CLOSED … "ERROR: bad req: invalid subscription id"` — so `author_` plus a
  /// 64-character pubkey would be 71 and would never receive an event.
  void subscribeToAuthor(String authorPubkey, {String? subscriptionId}) {
    _backend.subscribe(
      subscriptionId ?? 'author_${_shortKey(authorPubkey)}',
      Filter(kinds: [31415], authors: [authorPubkey]),
    );
  }

  /// Enough of a pubkey to tell two of them apart inside a subscription id.
  static String _shortKey(String pubkey) =>
      pubkey.length <= 16 ? pubkey : pubkey.substring(0, 16);

  /// Subscribe with a filter the caller built itself.
  ///
  /// The match subscriptions above are shaped alike — one kind, one author —
  /// and the announcement channel is not: a fixed kind, a fixed *list* of
  /// authors, `since` and `limit` (§4.1 of the announcement spec). Rather than
  /// grow a second nearly-identical helper per filter shape, a caller whose
  /// filter is its own business passes it. The pairing [unsubscribe] is
  /// already general in exactly the same way.
  void subscribeWithFilter(String subscriptionId, Filter filter) =>
      _backend.subscribe(subscriptionId, filter);

  /// Unsubscribe from a subscription
  void unsubscribe(String subscriptionId) =>
      _backend.unsubscribe(subscriptionId);

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
    if (event.kind == 31415) {
      final dTag = event.tags.firstWhere(
        (tag) => tag.isNotEmpty && tag[0] == 'd',
        orElse: () => [],
      );
      if (dTag.isNotEmpty && dTag.length > 1) {
        final addressKey = '${event.kind}:${event.pubkey}:${dTag[1]}';

        // Keep the revision NIP-01 says wins, not the one that arrived first.
        final existing = _addressableEvents[addressKey];
        if (existing != null &&
            !addressableSupersedes(
              arrivingCreatedAt: event.createdAt,
              arrivingId: event.id,
              heldCreatedAt: existing.createdAt,
              heldId: existing.id,
            )) {
          debugPrint('NostrService: Ignoring superseded event $addressKey');
          return;
        }

        _addressableEvents[addressKey] = event;

        // Evict oldest entries if cache exceeds limit
        if (_addressableEvents.length > _maxCachedEvents) {
          final oldestKey = _addressableEvents.keys.first;
          _addressableEvents.remove(oldestKey);
          debugPrint('NostrService: Evicted oldest event from cache');
        }
      }
    }

    _eventController.add(event);
  }

  /// Publish a signed event to every connected relay, returning as soon as the
  /// **first** one accepts it.
  ///
  /// Completing means one relay has the event. It does *not* mean the pool has
  /// converged: the other publishes are still in flight when this returns, and
  /// relays that were down, silent, or that rejected the event keep being
  /// resent the latest state per d-tag until every configured relay has it.
  /// Callers who need the referee's tap on the wire get it here; convergence
  /// is the resend sweep's job, and it outlives this call.
  ///
  /// Throws only once every relay has answered and none of them accepted.
  Future<void> publishEvent(NostrEvent event) async {
    final dTag = _dTagOf(event);
    if (dTag != null) {
      // This event supersedes whatever was pending for the match: relays that
      // missed older states only ever need the newest one.
      _pendingLatest[dTag] = event;
      _pendingAcks[dTag] = <String>{};
    }

    final connected = _backend.connectedRelays;

    debugPrint(
        'NostrService: publishing event ${event.id} (kind ${event.kind}, content ${event.content.length} chars) to ${connected.length} relays');

    if (connected.isEmpty) {
      // The pending state stays registered: the reconnect listener delivers it
      // as soon as any relay comes back.
      throw Exception('No connected relays');
    }

    // Every relay is asked at once, and this returns on the FIRST acceptance —
    // it does not wait for the rest.
    //
    // Waiting for all of them is what put the referee's taps behind the mat. A
    // relay going quiet is not a rare failure: `nostr-sdk` allows a full 10s
    // for an `OK` before giving up, and the publisher above sends one state at
    // a time, so every tap during that window sat unsent. One slow relay
    // delayed the scoreboard on the fast one.
    //
    // Nothing is lost by returning early: the stragglers keep running and
    // still record their acks, and a relay that never accepts is picked up by
    // the resend sweep — which is what convergence already means here.
    final firstAcceptance = Completer<void>();
    var outstanding = connected.length;

    for (final url in connected) {
      unawaited(() async {
        var accepted = false;
        try {
          accepted = await _backend.publish(url, event);
          debugPrint('NostrService: [$url] accepted=$accepted');
          if (accepted) _markAccepted(dTag, event, url);
        } catch (e) {
          debugPrint('NostrService: [$url] publish error: $e');
        }

        if (accepted && !firstAcceptance.isCompleted) {
          firstAcceptance.complete();
        }

        outstanding--;
        if (outstanding == 0) {
          // Everyone has answered. If nobody took it, the caller is still
          // waiting to hear so — it retries with backoff.
          if (!firstAcceptance.isCompleted) {
            firstAcceptance
                .completeError(Exception('Event rejected by all relays'));
          }
          _scheduleResendSweep();
        }
      }());
    }

    await firstAcceptance.future;

    // Relays still outstanding have not acked, so the state stays pending and
    // the sweep goes on working at it after this returns.
    _scheduleResendSweep();
  }

  static String? _dTagOf(NostrEvent event) {
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 'd') return tag[1];
    }
    return null;
  }

  /// Record that [url] accepted [event]; forget the d-tag once every configured
  /// relay has the latest state.
  void _markAccepted(String? dTag, NostrEvent event, String url) {
    if (dTag == null) return;
    // A newer state may have superseded this event mid-flight; an ack for the
    // old one says nothing about the state the relays must converge to.
    if (!identical(_pendingLatest[dTag], event)) return;
    final acked = _pendingAcks[dTag];
    if (acked == null) return;
    acked.add(url);
    if (_backend.relayUrls.every(acked.contains)) {
      _pendingLatest.remove(dTag);
      _pendingAcks.remove(dTag);
    }
  }

  /// Send every pending latest event this relay has not accepted yet.
  ///
  /// Returns whether the relay took anything, which is what tells the sweep
  /// above whether to keep its pace or back off.
  Future<bool> _resendPendingTo(String url) async {
    var acceptedAny = false;
    for (final dTag in _pendingLatest.keys.toList()) {
      final event = _pendingLatest[dTag];
      if (event == null) continue;
      final acked = _pendingAcks[dTag];
      if (acked == null || acked.contains(url)) continue;
      // The original publish may still be waiting on this relay's OK — don't
      // race it with a duplicate frame for the same event.
      if (_backend.isAwaitingOk(url, event.id)) continue;
      try {
        final accepted = await _backend.publish(url, event);
        debugPrint(
            'NostrService: resent ${event.id} to $url, accepted=$accepted');
        if (accepted) {
          _markAccepted(dTag, event, url);
          acceptedAny = true;
        }
      } catch (e) {
        debugPrint('NostrService: resend to $url failed: $e');
      }
    }
    return acceptedAny;
  }

  /// While any relay is missing the latest state, keep a retry loop alive for
  /// relays that are connected but rejected it. Disconnected relays are handled
  /// by the reconnect listener instead.
  ///
  /// Relays are swept **concurrently**: one that never answers used to hold up
  /// every relay behind it in the loop, for as long as the transport waits for
  /// an OK.
  ///
  /// The interval **doubles** each time a whole sweep goes unaccepted, up to
  /// [maxResendInterval]. A relay that refuses is usually refusing for a
  /// reason that a fixed heartbeat cannot fix and can actively worsen: a rate
  /// limit like `max 5 events per minute per IP` is spent by the very retries
  /// meant to beat it. Any acceptance — here or on a reconnect — puts the pace
  /// straight back to [resendInterval].
  void _scheduleResendSweep() {
    if (_pendingLatest.isEmpty) return;

    final backoff = resendInterval * (1 << _sweepFailures.clamp(0, 5));
    final delay = backoff > maxResendInterval ? maxResendInterval : backoff;

    _resendTimer ??= Timer(delay, () async {
      _resendTimer = null;
      final results = await Future.wait(
        _backend.connectedRelays.map(_resendPendingTo),
      );
      _sweepFailures = results.any((accepted) => accepted)
          ? 0
          : (_sweepFailures + 1).clamp(0, 5);
      _scheduleResendSweep();
    });
  }

  /// Create and publish a kind 31415 addressable event
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

    final createdAt = nextCreatedAt(dTag);

    // Sign the event: this computes both its id and its signature.
    final event = _crypto.finishEvent(
      UnsignedNostrEvent(
        kind: 31415,
        tags: tags,
        content: content,
        createdAt: createdAt,
        pubkey: publicKey,
      ),
      privateKey,
    );
    debugPrint('NostrService: event id: ${event.id}');

    // Self-check before it goes out: a relay would reject a bad event anyway,
    // and a silently malformed one is worse than a loud failure here.
    if (!_crypto.verifyEvent(event)) {
      throw Exception('Event signature verification failed');
    }

    await publishEvent(event);
  }

  /// Timestamp for the next addressable event of [dTag], strictly greater
  /// than any this session has used for it.
  ///
  /// Relays keep a single event per (kind, pubkey, d) and, per NIP-01, a
  /// replacement must have a strictly newer created_at — on a tie the old
  /// event wins. Two publishes within the same wall-clock second would
  /// otherwise leave the relay holding the stale state, which is how a
  /// final score or a "finished" status used to go missing remotely.
  @visibleForTesting
  int nextCreatedAt(String dTag) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final last = _lastCreatedAt[dTag];
    final createdAt = (last != null && now <= last) ? last + 1 : now;
    _lastCreatedAt[dTag] = createdAt;
    return createdAt;
  }

  /// Get the latest addressable event for a given key
  NostrEvent? getAddressableEvent(String kind, String pubkey, String dTag) {
    final key = '$kind:$pubkey:$dTag';
    return _addressableEvents[key];
  }

  /// Every cached event of [kind] published by [pubkey].
  ///
  /// Exists because this service deduplicates addressable events for the whole
  /// app: a relay replaying the state it already sent is dropped here, so a
  /// consumer that starts later never sees it on [eventStream] and would sit
  /// empty until the author published again. A late consumer asks for what it
  /// missed instead.
  List<NostrEvent> cachedEventsOf(int kind, String pubkey) {
    final prefix = '$kind:$pubkey:';
    return _addressableEvents.entries
        .where((e) => e.key.startsWith(prefix))
        .map((e) => e.value)
        .toList();
  }

  /// Get list of connected relays
  List<String> get connectedRelays => _backend.connectedRelays;

  /// Disconnect all relays
  void disconnect() => _backend.disconnect();

  /// Release the service and the transport beneath it. Anything still pending
  /// in the outbox is abandoned — the caller is going away, and there is nobody
  /// left to converge for.
  void dispose() {
    _backendEvents?.cancel();
    _backendConnections?.cancel();
    _resendTimer?.cancel();

    _backend.dispose();
    _eventController.close();
  }
}

/// Provider for NostrService.
///
/// Overridden in `main.dart`, which owns the relay pool's lifetime. There is no
/// sensible default: a second NostrService would mean a second set of sockets
/// and a second outbox, silently competing to publish the same match.
final nostrServiceProvider = Provider<NostrService>((ref) {
  throw UnimplementedError('nostrServiceProvider must be overridden');
});
