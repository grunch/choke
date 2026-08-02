import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/nostr/crypto/nostr_crypto.dart';
import '../../services/nostr/nostr_service.dart';
import '../../services/nostr/relay/nostr_relay_backend.dart' show Filter;
import 'announcement_store.dart';
import 'models/announcement.dart';
import 'models/app_version.dart';

/// Nothing older than this is news, however long a relay has been serving it.
/// The number itself lives in the schema, which the publisher tool shares.
const Duration kAnnouncementMaxAge = Duration(days: kAnnouncementMaxAgeDays);

/// Clock skew, not tolerance for post-dating: an announcement dated next week
/// must not sit at the top of every inbox until then (§3.3).
const Duration kAnnouncementClockSkew = Duration(minutes: 5);

/// How many announcements are kept, newest first.
const int kAnnouncementCacheLimit = 20;

/// The subscription id. One channel, one subscription, and a REQ that repeats
/// an id replaces it.
const String kAnnouncementSubscriptionId = 'announcements';

/// One announcement as the UI needs it.
@immutable
class AnnouncementEntry {
  final Announcement announcement;
  final bool isRead;

  const AnnouncementEntry({required this.announcement, required this.isRead});

  String get address => announcement.address;
}

/// Everything shown, newest first, with the dismissed ones already gone.
@immutable
class AnnouncementInboxState {
  final List<AnnouncementEntry> entries;

  const AnnouncementInboxState({this.entries = const []});

  bool get hasUnread => entries.any((entry) => !entry.isRead);

  int get unreadCount => entries.where((entry) => !entry.isRead).length;
}

/// The announcement channel: what arrives, what is kept, and what is shown.
///
/// Everything §3 asks for happens here, in one pass, over one definition of an
/// acceptable announcement — an arriving event and a cached one go through the
/// same door:
///
/// 1. the author is on the allowlist (§3.1)
/// 2. the signature verifies, **in the crate, every time** (§3.2)
/// 3. the schema of §2 parses
/// 4. it is neither stale nor post-dated, and has not expired (§3.3, §3.4)
/// 5. it targets this app version (§2.1)
/// 6. it is the revision that wins at its address (§3.3)
///
/// Every rejection is silent. A user who never receives an announcement should
/// not be able to tell that they didn't (§4.4).
class AnnouncementInbox extends StateNotifier<AnnouncementInboxState> {
  AnnouncementInbox({
    required NostrService service,
    required NostrCrypto crypto,
    required AppVersion appVersion,
    required List<String> publishers,
    AnnouncementStore store = const AnnouncementStore(),
    DateTime Function() now = DateTime.now,
  })  : _service = service,
        _crypto = crypto,
        _appVersion = appVersion,
        _publishers = Set.unmodifiable(publishers),
        _store = store,
        _now = now,
        super(const AnnouncementInboxState());

  final NostrService _service;
  final NostrCrypto _crypto;
  final AppVersion _appVersion;
  final Set<String> _publishers;
  final AnnouncementStore _store;
  final DateTime Function() _now;

  /// Address → the event and the announcement inside it. The event is kept
  /// because it is what gets written back: a restore re-verifies rather than
  /// trusting what we parsed last time.
  final Map<String, ({NostrEvent event, Announcement announcement})> _held = {};
  final Map<String, AnnouncementRevision> _read = {};
  final Map<String, AnnouncementRevision> _dismissed = {};

  StreamSubscription<NostrEvent>? _events;

  /// Whether the channel is open. Events that arrive while it is not are
  /// discarded rather than queued: switching the setting off must take effect
  /// at the tap, not at the next background transition (§5).
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  int get _nowSeconds => _now().millisecondsSinceEpoch ~/ 1000;

  /// Read the cache and re-run every rule over it.
  ///
  /// Not a fast path that trusts what it stored: the clock has moved, and the
  /// allowlist or the app version may have changed since. An entry that no
  /// longer passes is dropped here *and* removed from storage (§4.2).
  Future<void> restore() async {
    final cache = await _store.load();
    if (cache.isEmpty) return;

    for (final event in cache.events) {
      _admit(event);
    }

    // Read and dismissed state survives only for an address that survived,
    // **at the revision it was recorded against**.
    //
    // The revision check is also what makes this safe to run in any order
    // relative to the live subscription. On a slow cold start the app can be
    // resumed before the post-frame callback that calls this, so open() may
    // already have admitted a newer revision at a known address — and applying
    // a read mark recorded against the revision it replaced would show a
    // correction as something the user had already read. That is the one case
    // the correction was published for (§3.3).
    _read.addEntries(cache.read.entries.where(_isRevisionStillHeld));
    _dismissed.addEntries(cache.dismissed.entries.where(_isRevisionStillHeld));

    _publish();
    // Whatever the clock or the allowlist just rejected is gone from disk too.
    await _persist();
  }

  /// Whether the announcement at this address is still the revision the entry
  /// was recorded against.
  bool _isRevisionStillHeld(MapEntry<String, AnnouncementRevision> entry) {
    return _held[entry.key]?.announcement.revision == entry.value;
  }

  /// Open the channel: subscribe, and start listening.
  ///
  /// A no-op when the allowlist decodes to nothing. An unfiltered subscription
  /// would be a request for every announcement-kind event on the relay, signed
  /// by anyone, and the answer to "we have no key yet" is silence.
  void open() {
    if (_isOpen) return;
    if (_publishers.isEmpty) {
      debugPrint('Announcements: no publishers, opening no subscription');
      return;
    }

    _isOpen = true;
    _events = _service.eventStream.listen(_onEvent);
    _service.subscribeWithFilter(
      kAnnouncementSubscriptionId,
      Filter(
        kinds: const [kAnnouncementKind],
        authors: _publishers.toList(),
        since: _nowSeconds - kAnnouncementMaxAge.inSeconds,
        limit: kAnnouncementCacheLimit,
      ),
    );
  }

  /// Close the channel, now.
  ///
  /// The listener is cancelled before the subscription is dropped, so anything
  /// already on its way is discarded rather than processed. Off means the
  /// subscription is not open, not that arriving events are hidden (§5).
  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    _events?.cancel();
    _events = null;
    _service.unsubscribe(kAnnouncementSubscriptionId);
  }

  /// Re-check what is held against the current time.
  ///
  /// The offline case, and only that: freshness and expiry are enforced on
  /// arrival, but a phone that spends five weeks in a gym basement receives
  /// nothing to displace what it has. Without this, "we are down for
  /// maintenance tonight" outlives its own expiration precisely because
  /// nothing came in (§4.2).
  Future<void> revalidate() async {
    final stale = _held.entries
        .where((entry) => !_isCurrent(entry.value.announcement))
        .map((entry) => entry.key)
        .toList();
    if (stale.isEmpty) return;

    for (final address in stale) {
      _forget(address);
    }
    _publish();
    await _persist();
  }

  /// Mark an announcement read. Idempotent.
  Future<void> markRead(String address) async {
    final held = _held[address];
    if (held == null) return;
    if (_read[address] == held.announcement.revision) return;

    _read[address] = held.announcement.revision;
    _publish();
    await _persist();
  }

  /// Swipe it away. The address stays in the dismissed map so a redelivery of
  /// the same revision does not bring it back.
  Future<void> dismiss(String address) async {
    final held = _held[address];
    if (held == null) return;
    if (_dismissed[address] == held.announcement.revision) return;

    _dismissed[address] = held.announcement.revision;
    _publish();
    await _persist();
  }

  /// Forget everything, in memory and on disk. For the switch of §5.
  Future<void> forgetEverything() async {
    _held.clear();
    _read.clear();
    _dismissed.clear();
    _publish();
    // Behind the same chain as every other write: a save from an event that
    // arrived a moment ago must not land after this and put it all back.
    await _enqueueWrite(_store.clear);
  }

  void _onEvent(NostrEvent event) {
    if (!_isOpen) return;
    if (!_admit(event)) return;
    _publish();
    unawaited(_persist());
  }

  /// The one door. Returns whether anything changed.
  bool _admit(NostrEvent event) {
    if (event.kind != kAnnouncementKind) return false;

    // The allowlist first, because it is a set lookup and verification is not.
    if (!_publishers.contains(event.pubkey)) {
      debugPrint('Announcements: ignoring event from an unlisted key');
      return false;
    }

    // Verified here, in the crate, whatever the relay pool does or does not
    // check on its own (§3.2). The pool's settings are a transport detail that
    // can change under us; this is the only property the feature rests on.
    bool verified;
    try {
      verified = _crypto.verifyEvent(event);
    } catch (e) {
      debugPrint('Announcements: verification threw: $e');
      return false;
    }
    if (!verified) {
      debugPrint('Announcements: dropping an event that failed verification');
      return false;
    }

    final announcement = Announcement.tryParse(event);
    if (announcement == null) return false;
    if (!_isCurrent(announcement)) return false;

    final held = _held[announcement.address];
    if (held != null &&
        !announcement.revision.supersedes(held.announcement.revision)) {
      // Either a redelivery of what we have, or an older revision. Neither is
      // news, and neither may re-announce.
      return false;
    }

    if (held != null) {
      // A correction the user has already read and dismissed must not arrive
      // pre-dismissed — that loses it in exactly the case it was published
      // for (§3.3).
      _read.remove(announcement.address);
      _dismissed.remove(announcement.address);
    }

    _held[announcement.address] = (event: event, announcement: announcement);
    _evictBeyondLimit();
    return true;
  }

  /// Freshness (§3.3), expiry (§3.4) and targeting (§2.1), against the clock
  /// as it is right now.
  bool _isCurrent(Announcement announcement) {
    final now = _nowSeconds;

    if (announcement.createdAt < now - kAnnouncementMaxAge.inSeconds) {
      debugPrint('Announcements: ${announcement.address} is too old');
      return false;
    }
    if (announcement.createdAt > now + kAnnouncementClockSkew.inSeconds) {
      debugPrint('Announcements: ${announcement.address} is post-dated');
      return false;
    }
    if (announcement.expiration <= now) {
      debugPrint('Announcements: ${announcement.address} has expired');
      return false;
    }
    if (!announcement.appliesTo(_appVersion)) {
      debugPrint(
        'Announcements: ${announcement.address} is not for $_appVersion',
      );
      return false;
    }
    return true;
  }

  /// Keep the newest [kAnnouncementCacheLimit] and no more.
  void _evictBeyondLimit() {
    if (_held.length <= kAnnouncementCacheLimit) return;

    final byAge = _held.entries.toList()
      ..sort(
        (a, b) => _compareNewestFirst(
          a.value.announcement,
          b.value.announcement,
        ),
      );
    for (final entry in byAge.skip(kAnnouncementCacheLimit)) {
      _forget(entry.key);
    }
  }

  /// Drop an address everywhere at once. Nothing may reference an address that
  /// is no longer held.
  void _forget(String address) {
    _held.remove(address);
    _read.remove(address);
    _dismissed.remove(address);
  }

  static int _compareNewestFirst(Announcement a, Announcement b) {
    if (a.createdAt != b.createdAt) return b.createdAt.compareTo(a.createdAt);
    // A stable tiebreak so two announcements published in the same second do
    // not swap places between rebuilds.
    return a.revision.eventId.compareTo(b.revision.eventId);
  }

  void _publish() {
    final visible = _held.values
        .map((held) => held.announcement)
        .where((announcement) => !_dismissed.containsKey(announcement.address))
        .toList()
      ..sort(_compareNewestFirst);

    state = AnnouncementInboxState(
      entries: List.unmodifiable(
        visible.map(
          (announcement) => AnnouncementEntry(
            announcement: announcement,
            isRead: _read.containsKey(announcement.address),
          ),
        ),
      ),
    );
  }

  /// The tail of the write chain. Every write to storage queues behind it.
  ///
  /// A burst of events is one relay redelivering on reconnect, so overlapping
  /// writes are the ordinary case rather than the exotic one — and two
  /// unordered `setString` calls can land newest-first, leaving storage a
  /// state the app was in two events ago. The snapshot is taken here, when the
  /// caller asks, so the chain replays the states in the order they happened.
  Future<void> _writes = Future.value();

  /// The write chain, for a test that needs to read storage back.
  ///
  /// Persistence is deliberately fire-and-forget — nothing on screen waits for
  /// a disk write — which leaves a test with no synchronization point and a
  /// choice between guessing a delay and this.
  @visibleForTesting
  Future<void> get pendingWrites => _writes;

  Future<void> _enqueueWrite(Future<void> Function() write) {
    // Guarded twice, and both are load-bearing. The chain must survive one
    // failed write, or a single storage error wedges every write after it —
    // and the *returned* future must not carry the error either: half its
    // callers are `unawaited`, where a rejection is an unhandled async error,
    // and the other half are UI callbacks that have nothing to do with one.
    // AnnouncementStore swallows its own failures today, but `store` is
    // injectable and the next implementation is under no such obligation.
    final next = _writes.then((_) => write()).catchError((Object e) {
      debugPrint('Announcements: a write to storage failed: $e');
    });
    _writes = next;
    return next;
  }

  Future<void> _persist() {
    final snapshot = AnnouncementCache(
      events: _held.values.map((held) => held.event).toList(),
      read: Map.of(_read),
      dismissed: Map.of(_dismissed),
    );
    return _enqueueWrite(() => _store.save(snapshot));
  }

  @override
  void dispose() {
    // Through close(), so the relays are told: cancelling the listener alone
    // leaves a REQ open on every socket, feeding a stream nobody reads.
    close();
    super.dispose();
  }
}
