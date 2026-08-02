import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/announcements/announcement_inbox.dart';
import 'package:choke/features/announcements/announcement_store.dart';
import 'package:choke/features/announcements/models/announcement.dart';
import 'package:choke/features/announcements/models/app_version.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/nostr_service.dart';

import '../../support/nostr_fakes.dart';

const String _publisher = 'aa11';
const String _stranger = 'ff99';

/// Wall clock every test shares, so "31 days old" is a fixed number.
final DateTime _now = DateTime.utc(2026, 8, 2, 12);
int get _nowSeconds => _now.millisecondsSinceEpoch ~/ 1000;

/// Verifies everything except the events a test names as tampered with.
class _Verifier extends FakeNostrCrypto {
  final Set<String> rejected = {};
  final Set<String> throwing = {};
  int verifyCalls = 0;

  @override
  bool verifyEvent(NostrEvent event) {
    verifyCalls++;
    if (throwing.contains(event.id)) throw StateError('native boom');
    return !rejected.contains(event.id);
  }
}

NostrEvent _event({
  String id = 'e1',
  String pubkey = _publisher,
  String d = 'release-2-1',
  int? createdAt,
  int? expiration,
  int kind = kAnnouncementKind,
  String title = 'Version 2.1 is out',
  String? minVersion,
  String? maxVersion,
}) {
  return NostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt ?? _nowSeconds - 60,
    kind: kind,
    tags: [
      ['d', d],
      ['expiration', '${expiration ?? _nowSeconds + 86400}'],
      if (minVersion != null) ['min_version', minVersion],
      if (maxVersion != null) ['max_version', maxVersion],
    ],
    content: jsonEncode({
      'v': kAnnouncementSchemaVersion,
      'locales': {
        for (final code in kAnnouncementLocales)
          code: {'title': title, 'body': 'body'},
      },
    }),
    sig: 'f' * 128,
  );
}

/// An inbox wired to fakes, with the clock and the allowlist under the test's
/// control.
({
  AnnouncementInbox inbox,
  RecordingRelayBackend backend,
  NostrService service,
  _Verifier crypto,
}) _build({
  List<String> publishers = const [_publisher],
  String appVersion = '2.0.1',
  DateTime? clock,
}) {
  final backend = RecordingRelayBackend();
  final crypto = _Verifier();
  final service = NostrService(
    KeyManager(crypto: crypto),
    crypto: crypto,
    backend: backend,
  );
  final inbox = AnnouncementInbox(
    service: service,
    crypto: crypto,
    appVersion: AppVersion.tryParse(appVersion)!,
    publishers: publishers,
    now: () => clock ?? _now,
  );
  return (inbox: inbox, backend: backend, service: service, crypto: crypto);
}

/// Push an event through the relay and let the stream turn.
Future<void> _deliver(RecordingRelayBackend backend, NostrEvent event) async {
  backend.eventsController.add(event);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the allowlist', () {
    test('an event from an allowed key is accepted', () async {
      // Arrange
      final w = _build();
      w.inbox.open();

      // Act
      await _deliver(w.backend, _event());

      // Assert
      expect(w.inbox.state.entries, hasLength(1));
      expect(w.inbox.state.entries.single.announcement.publisher, _publisher);
      expect(w.inbox.state.hasUnread, isTrue);
    });

    test('an event from any other key is ignored', () async {
      // Arrange
      final w = _build();
      w.inbox.open();

      // Act — a relay can serve anything it likes
      await _deliver(w.backend, _event(pubkey: _stranger));

      // Assert
      expect(w.inbox.state.entries, isEmpty);
    });

    test('an empty allowlist opens no subscription at all', () async {
      // Arrange — the state this ships in, until the offline key exists
      final w = _build(publishers: const []);

      // Act
      w.inbox.open();

      // Assert
      expect(w.inbox.isOpen, isFalse);
      expect(w.backend.subscriptions, isEmpty);
    });

    test('the filter asks for the kind, the authors, and 30 days', () async {
      // Arrange
      final w = _build(publishers: const [_publisher, _stranger]);

      // Act
      w.inbox.open();

      // Assert
      final filter = w.backend.subscriptions[kAnnouncementSubscriptionId]!;
      expect(filter.kinds, [kAnnouncementKind]);
      expect(filter.authors, [_publisher, _stranger]);
      expect(filter.limit, kAnnouncementCacheLimit);
      expect(filter.since, _nowSeconds - kAnnouncementMaxAge.inSeconds);
    });
  });

  group('verification', () {
    test('every accepted event is verified in the crate', () async {
      // Arrange — asserted where it is used, not assumed of the relay pool
      final w = _build();
      w.inbox.open();

      // Act
      await _deliver(w.backend, _event());

      // Assert
      expect(w.crypto.verifyCalls, 1);
    });

    test('an event that fails verification is dropped silently', () async {
      // Arrange
      final w = _build();
      w.crypto.rejected.add('tampered');
      w.inbox.open();

      // Act
      await _deliver(w.backend, _event(id: 'tampered'));

      // Assert
      expect(w.inbox.state.entries, isEmpty);
    });

    test('verification throwing drops the event, not the app', () async {
      // Arrange — the native library is a foreign function call
      final w = _build();
      w.crypto.throwing.add('boom');
      w.inbox.open();

      // Act + Assert
      await _deliver(w.backend, _event(id: 'boom'));
      expect(w.inbox.state.entries, isEmpty);
    });

    test('an unlisted key is never even verified', () async {
      // Arrange — the cheap check comes first
      final w = _build();
      w.inbox.open();

      // Act
      await _deliver(w.backend, _event(pubkey: _stranger));

      // Assert
      expect(w.crypto.verifyCalls, 0);
    });
  });

  group('freshness', () {
    test('an announcement older than 30 days is ignored', () async {
      // Arrange
      final w = _build();
      w.inbox.open();

      // Act
      await _deliver(
        w.backend,
        _event(createdAt: _nowSeconds - const Duration(days: 31).inSeconds),
      );

      // Assert
      expect(w.inbox.state.entries, isEmpty);
    });

    test('an announcement dated ten minutes ahead is ignored', () async {
      // Arrange — post-dating must not park a message at the top of the inbox
      final w = _build();
      w.inbox.open();

      // Act
      await _deliver(w.backend, _event(createdAt: _nowSeconds + 600));

      // Assert
      expect(w.inbox.state.entries, isEmpty);
    });

    test('a minute of clock skew is tolerated', () async {
      // Arrange
      final w = _build();
      w.inbox.open();

      // Act
      await _deliver(w.backend, _event(createdAt: _nowSeconds + 60));

      // Assert
      expect(w.inbox.state.entries, hasLength(1));
    });
  });

  group('expiry', () {
    test('an event already expired on arrival is dropped', () async {
      // Arrange
      final w = _build();
      w.inbox.open();

      // Act
      await _deliver(w.backend, _event(expiration: _nowSeconds - 1));

      // Assert
      expect(w.inbox.state.entries, isEmpty);
    });
  });

  group('version targeting', () {
    test('an announcement below min_version is not for this build', () async {
      // Arrange — running 2.0.1
      final w = _build();
      w.inbox.open();

      // Act
      await _deliver(w.backend, _event(minVersion: '2.1.0'));

      // Assert
      expect(w.inbox.state.entries, isEmpty);
    });

    test('2.0.1 still hears that 2.1 is out', () async {
      // Arrange
      final w = _build();
      w.inbox.open();

      // Act — max_version is exclusive
      await _deliver(w.backend, _event(maxVersion: '2.1.0'));

      // Assert
      expect(w.inbox.state.entries, hasLength(1));
    });

    test('2.1.0 does not hear that 2.1 is out', () async {
      // Arrange
      final w = _build(appVersion: '2.1.0');
      w.inbox.open();

      // Act
      await _deliver(w.backend, _event(maxVersion: '2.1.0'));

      // Assert
      expect(w.inbox.state.entries, isEmpty);
    });
  });

  group('replay and revisions', () {
    test('the same event delivered twice does not re-announce', () async {
      // Arrange
      final w = _build();
      w.inbox.open();
      await _deliver(w.backend, _event());
      await w.inbox.markRead(w.inbox.state.entries.single.address);

      // Act — relays redeliver on reconnect
      await _deliver(w.backend, _event());

      // Assert
      expect(w.inbox.state.entries, hasLength(1));
      expect(w.inbox.state.hasUnread, isFalse);
    });

    test('a newer revision replaces and re-announces', () async {
      // Arrange
      final w = _build();
      w.inbox.open();
      await _deliver(w.backend, _event(title: 'Sunday at 9'));
      final address = w.inbox.state.entries.single.address;
      await w.inbox.markRead(address);

      // Act — the correction
      await _deliver(
        w.backend,
        _event(id: 'e2', createdAt: _nowSeconds - 30, title: 'Sunday at 10'),
      );

      // Assert — read state is cleared, or the fix arrives already read
      expect(w.inbox.state.entries, hasLength(1));
      expect(
        w.inbox.state.entries.single.announcement.textFor('en').title,
        'Sunday at 10',
      );
      expect(w.inbox.state.hasUnread, isTrue);
    });

    test('a correction resurfaces something already dismissed', () async {
      // Arrange
      final w = _build();
      w.inbox.open();
      await _deliver(w.backend, _event());
      await w.inbox.dismiss(w.inbox.state.entries.single.address);
      expect(w.inbox.state.entries, isEmpty);

      // Act
      await _deliver(
        w.backend,
        _event(id: 'e2', createdAt: _nowSeconds - 30, title: 'Correction'),
      );

      // Assert — the case the correction was published for
      expect(w.inbox.state.entries, hasLength(1));
      expect(w.inbox.state.hasUnread, isTrue);
    });

    test('an older revision of the same address is ignored', () async {
      // Arrange
      final w = _build();
      w.inbox.open();
      await _deliver(w.backend, _event(id: 'e2', createdAt: _nowSeconds - 30));

      // Act — a relay serving what it still had
      await _deliver(w.backend, _event(id: 'e1', createdAt: _nowSeconds - 60));

      // Assert
      expect(w.inbox.state.entries.single.announcement.revision.eventId, 'e2');
    });

    test('on a created_at tie the lowest event id wins', () async {
      // Arrange
      final w = _build();
      w.inbox.open();
      await _deliver(w.backend, _event(id: 'bb', createdAt: _nowSeconds - 30));

      // Act
      await _deliver(w.backend, _event(id: 'aa', createdAt: _nowSeconds - 30));
      await _deliver(w.backend, _event(id: 'cc', createdAt: _nowSeconds - 30));

      // Assert — NIP-01, and the same rule NostrService applies to matches
      expect(w.inbox.state.entries.single.announcement.revision.eventId, 'aa');
    });

    test('the same d from two allowed keys is two announcements', () async {
      // Arrange — the reason the address is not the d alone (§3.3)
      final w = _build(publishers: const [_publisher, _stranger]);
      w.inbox.open();

      // Act
      await _deliver(w.backend, _event(id: 'e1'));
      await _deliver(w.backend, _event(id: 'e2', pubkey: _stranger));

      // Assert
      expect(w.inbox.state.entries, hasLength(2));
    });

    test('reading one key does not read the other key at the same d', () async {
      // Arrange
      final w = _build(publishers: const [_publisher, _stranger]);
      w.inbox.open();
      await _deliver(w.backend, _event(id: 'e1'));
      await _deliver(w.backend, _event(id: 'e2', pubkey: _stranger));

      // Act
      await w.inbox.markRead('$kAnnouncementKind:$_publisher:release-2-1');

      // Assert
      expect(w.inbox.state.unreadCount, 1);
    });
  });

  group('ordering and the cap', () {
    test('newest first', () async {
      // Arrange
      final w = _build();
      w.inbox.open();

      // Act
      await _deliver(
        w.backend,
        _event(id: 'old', d: 'a', createdAt: _nowSeconds - 900),
      );
      await _deliver(
        w.backend,
        _event(id: 'new', d: 'b', createdAt: _nowSeconds - 60),
      );

      // Assert
      expect(
        w.inbox.state.entries.map((e) => e.announcement.announcementId),
        ['b', 'a'],
      );
    });

    test('keeps only the twenty most recent', () async {
      // Arrange
      final w = _build();
      w.inbox.open();

      // Act — 25 announcements, ageing backwards
      for (var i = 0; i < 25; i++) {
        await _deliver(
          w.backend,
          _event(id: 'e$i', d: 'a$i', createdAt: _nowSeconds - i * 60),
        );
      }

      // Assert
      expect(w.inbox.state.entries, hasLength(kAnnouncementCacheLimit));
      expect(w.inbox.state.entries.first.announcement.announcementId, 'a0');
      expect(w.inbox.state.entries.last.announcement.announcementId, 'a19');
    });
  });

  group('read and dismiss', () {
    test('marking read clears the unread flag and persists', () async {
      // Arrange
      final w = _build();
      w.inbox.open();
      await _deliver(w.backend, _event());

      // Act
      await w.inbox.markRead(w.inbox.state.entries.single.address);

      // Assert
      expect(w.inbox.state.hasUnread, isFalse);
      final cache = await const AnnouncementStore().load();
      expect(cache.read.keys, ['$kAnnouncementKind:$_publisher:release-2-1']);
    });

    test('dismissing hides it and survives a restart', () async {
      // Arrange
      final w = _build();
      w.inbox.open();
      await _deliver(w.backend, _event());

      // Act
      await w.inbox.dismiss(w.inbox.state.entries.single.address);

      // Assert
      expect(w.inbox.state.entries, isEmpty);
      final restarted = _build();
      await restarted.inbox.restore();
      expect(restarted.inbox.state.entries, isEmpty);
    });

    test('marking an address nobody holds does nothing', () async {
      // Arrange
      final w = _build();

      // Act + Assert
      await w.inbox.markRead('31416:nobody:nothing');
      expect(w.inbox.state.entries, isEmpty);
    });
  });

  group('storage', () {
    test('what arrived is what a restart shows', () async {
      // Arrange
      final w = _build();
      w.inbox.open();
      await _deliver(w.backend, _event());
      await w.inbox.markRead(w.inbox.state.entries.single.address);

      // Act
      final restarted = _build();
      await restarted.inbox.restore();

      // Assert
      expect(restarted.inbox.state.entries, hasLength(1));
      expect(restarted.inbox.state.hasUnread, isFalse);
    });

    test('a restore verifies the cache again rather than trusting it',
        () async {
      // Arrange
      final w = _build();
      w.inbox.open();
      await _deliver(w.backend, _event());

      // Act — the key that signed it is no longer allowed
      final restarted = _build(publishers: const [_stranger]);
      await restarted.inbox.restore();

      // Assert — and it is gone from disk, not merely hidden
      expect(restarted.inbox.state.entries, isEmpty);
      expect((await const AnnouncementStore().load()).events, isEmpty);
    });

    test(
        'a cached announcement that aged past the window while offline is '
        'dropped and deleted', () async {
      // Arrange — cached fresh, restored 31 days later with no relay in sight
      final w = _build();
      w.inbox.open();
      await _deliver(w.backend, _event(d: 'stale'));
      expect((await const AnnouncementStore().load()).events, hasLength(1));

      // Act
      final later = _build(clock: _now.add(const Duration(days: 31)));
      await later.inbox.restore();

      // Assert — gone from both the screen and storage
      expect(later.inbox.state.entries, isEmpty);
      expect((await const AnnouncementStore().load()).events, isEmpty);
    });

    test('a cached announcement that expires while offline is swept', () async {
      // Arrange — the expiration is in the real future as well as the fake
      // one: NostrService applies NIP-40 against the wall clock on the way in,
      // so a near expiry would make this pass without the sweep ever running
      final w = _build();
      w.inbox.open();
      await _deliver(w.backend, _event(expiration: _nowSeconds + 86400));
      expect((await const AnnouncementStore().load()).events, hasLength(1));

      // Act — two days later, still offline
      final later = _build(clock: _now.add(const Duration(days: 2)));
      await later.inbox.restore();

      // Assert
      expect(later.inbox.state.entries, isEmpty);
      expect((await const AnnouncementStore().load()).events, isEmpty);
    });

    test('a valid neighbour survives the sweep', () async {
      // Arrange
      final w = _build();
      w.inbox.open();
      await _deliver(
        w.backend,
        _event(d: 'expiring', expiration: _nowSeconds + 86400),
      );
      await _deliver(
        w.backend,
        _event(id: 'e2', d: 'lasting', expiration: _nowSeconds + 8640000),
      );
      expect((await const AnnouncementStore().load()).events, hasLength(2));

      // Act
      final later = _build(clock: _now.add(const Duration(days: 2)));
      await later.inbox.restore();

      // Assert
      expect(
        later.inbox.state.entries.map((e) => e.announcement.announcementId),
        ['lasting'],
      );
    });

    test('a foreground revalidate drops what the clock invalidated', () async {
      // Arrange — the app was open, then away long enough to matter
      var clock = _now;
      final backend = RecordingRelayBackend();
      final crypto = _Verifier();
      final inbox = AnnouncementInbox(
        service: NostrService(
          KeyManager(crypto: crypto),
          crypto: crypto,
          backend: backend,
        ),
        crypto: crypto,
        appVersion: AppVersion.tryParse('2.0.1')!,
        publishers: const [_publisher],
        now: () => clock,
      );
      inbox.open();
      await _deliver(backend, _event(expiration: _nowSeconds + 86400));
      expect(inbox.state.entries, hasLength(1));

      // Act — away for two days, so what was good for one has expired
      clock = _now.add(const Duration(days: 2));
      await inbox.revalidate();

      // Assert
      expect(inbox.state.entries, isEmpty);
      expect((await const AnnouncementStore().load()).events, isEmpty);
    });

    test('a restore with nothing stored leaves an empty inbox', () async {
      // Arrange
      final w = _build();

      // Act + Assert
      await w.inbox.restore();
      expect(w.inbox.state.entries, isEmpty);
    });
  });

  group('consent', () {
    test('nothing is delivered before the channel is opened', () async {
      // Arrange
      final w = _build();

      // Act
      await _deliver(w.backend, _event());

      // Assert
      expect(w.inbox.state.entries, isEmpty);
    });

    test('closing cancels the listener and drops the subscription', () async {
      // Arrange
      final w = _build();
      w.inbox.open();

      // Act
      w.inbox.close();

      // Assert
      expect(w.inbox.isOpen, isFalse);
      expect(w.backend.unsubscribed, [kAnnouncementSubscriptionId]);
    });

    test('an event queued behind a close is discarded, not processed',
        () async {
      // Arrange — the tap happens while an event is already in flight
      final w = _build();
      w.inbox.open();

      // Act
      w.backend.eventsController.add(_event());
      w.inbox.close();
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(w.inbox.state.entries, isEmpty);
    });

    test('reopening resumes delivery', () async {
      // Arrange
      final w = _build();
      w.inbox.open();
      w.inbox.close();

      // Act
      w.inbox.open();
      await _deliver(w.backend, _event());

      // Assert
      expect(w.inbox.state.entries, hasLength(1));
    });

    test('forgetting everything empties the screen and the storage', () async {
      // Arrange
      final w = _build();
      w.inbox.open();
      await _deliver(w.backend, _event());

      // Act
      await w.inbox.forgetEverything();

      // Assert
      expect(w.inbox.state.entries, isEmpty);
      expect((await const AnnouncementStore().load()).isEmpty, isTrue);
    });
  });
}
