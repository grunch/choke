import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/nostr/nostr_service.dart' show NostrEvent;
import 'models/announcement.dart';

/// What survives a restart: the announcements themselves and what the user has
/// already done with them.
@immutable
class AnnouncementCache {
  /// The signed events, exactly as they arrived.
  ///
  /// The *events*, not the parsed announcements, and that is the point: a
  /// restore re-runs the whole pipeline — signature, allowlist, schema,
  /// freshness, expiry, targeting — over them. There is one definition of an
  /// acceptable announcement and the cache cannot hold something outside it,
  /// so a key dropped from the allowlist takes its cached announcements with
  /// it on the next launch.
  final List<NostrEvent> events;

  /// Address → the revision that was read.
  final Map<String, AnnouncementRevision> read;

  /// Address → the revision that was dismissed.
  final Map<String, AnnouncementRevision> dismissed;

  const AnnouncementCache({
    this.events = const [],
    this.read = const {},
    this.dismissed = const {},
  });

  bool get isEmpty => events.isEmpty && read.isEmpty && dismissed.isEmpty;
}

/// The announcement cache in `shared_preferences`, following
/// `match_sound_provider` and its neighbours.
///
/// Nothing here validates anything: it stores what it is given and returns
/// what it stored. Deciding what is still an announcement is
/// `AnnouncementInbox`'s job, on the way out.
class AnnouncementStore {
  /// One key, holding the whole cache.
  ///
  /// Three keys would have been the obvious shape and the wrong one:
  /// `shared_preferences` has no transaction across keys, so a write that
  /// stopped between them would leave a new event list beside an old read map,
  /// and nothing would say so. One value lands or it does not.
  static const String cacheKey = 'choke:announcements';

  const AnnouncementStore();

  /// Everything previously stored, or an empty cache.
  ///
  /// A read that fails or a value that no longer parses yields empty rather
  /// than throwing: the worst case is a user who sees an announcement twice,
  /// which is a great deal better than a launch that cannot get past the
  /// announcement cache.
  Future<AnnouncementCache> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return const AnnouncementCache();

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const AnnouncementCache();

      return AnnouncementCache(
        events: _decodeEvents(decoded['events']),
        read: _decodeRevisions(decoded['read']),
        dismissed: _decodeRevisions(decoded['dismissed']),
      );
    } catch (e) {
      debugPrint('AnnouncementStore: load failed: $e');
      return const AnnouncementCache();
    }
  }

  /// Replace everything stored with [cache].
  ///
  /// One `setString`, so the three pieces cannot disagree: the read map points
  /// at addresses in the event list, and there is no moment at which half of
  /// this has landed.
  Future<void> save(AnnouncementCache cache) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        cacheKey,
        jsonEncode({
          'events': cache.events.map((e) => e.toJson()).toList(),
          'read': _encodeRevisions(cache.read),
          'dismissed': _encodeRevisions(cache.dismissed),
        }),
      );
    } catch (e) {
      debugPrint('AnnouncementStore: save failed: $e');
    }
  }

  /// Forget everything. Used when the channel is switched off (§5).
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cacheKey);
    } catch (e) {
      debugPrint('AnnouncementStore: clear failed: $e');
    }
  }

  static List<NostrEvent> _decodeEvents(Object? raw) {
    if (raw is! List) return const [];

    final events = <NostrEvent>[];
    for (final entry in raw) {
      try {
        events.add(NostrEvent.fromJson(entry as Map<String, dynamic>));
      } catch (e) {
        // One unreadable row must not cost the others: the whole point of the
        // cache is what the project last said.
        debugPrint('AnnouncementStore: dropping unreadable event: $e');
      }
    }
    return events;
  }

  static Map<String, AnnouncementRevision> _decodeRevisions(Object? raw) {
    if (raw is! Map<String, dynamic>) return const {};

    final revisions = <String, AnnouncementRevision>{};
    raw.forEach((address, value) {
      if (value is! Map<String, dynamic>) return;
      final createdAt = value['created_at'];
      final id = value['id'];
      if (createdAt is! int || id is! String) return;
      revisions[address] =
          AnnouncementRevision(createdAt: createdAt, eventId: id);
    });
    return revisions;
  }

  static Map<String, dynamic> _encodeRevisions(
    Map<String, AnnouncementRevision> revisions,
  ) {
    return {
      for (final entry in revisions.entries)
        entry.key: {
          'created_at': entry.value.createdAt,
          'id': entry.value.eventId,
        },
    };
  }
}
