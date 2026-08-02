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
  static const String eventsKey = 'choke:announcements:events';
  static const String readKey = 'choke:announcements:read';
  static const String dismissedKey = 'choke:announcements:dismissed';

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
      return AnnouncementCache(
        events: _decodeEvents(prefs.getString(eventsKey)),
        read: _decodeRevisions(prefs.getString(readKey)),
        dismissed: _decodeRevisions(prefs.getString(dismissedKey)),
      );
    } catch (e) {
      debugPrint('AnnouncementStore: load failed: $e');
      return const AnnouncementCache();
    }
  }

  /// Replace everything stored with [cache].
  ///
  /// A whole-cache write rather than three independent ones: the read map
  /// points at addresses in the event list, and a partial write is how they
  /// would come to disagree.
  Future<void> save(AnnouncementCache cache) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        eventsKey,
        jsonEncode(cache.events.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(readKey, _encodeRevisions(cache.read));
      await prefs.setString(dismissedKey, _encodeRevisions(cache.dismissed));
    } catch (e) {
      debugPrint('AnnouncementStore: save failed: $e');
    }
  }

  /// Forget everything. Used when the channel is switched off (§5).
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(eventsKey);
      await prefs.remove(readKey);
      await prefs.remove(dismissedKey);
    } catch (e) {
      debugPrint('AnnouncementStore: clear failed: $e');
    }
  }

  static List<NostrEvent> _decodeEvents(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    final events = <NostrEvent>[];
    for (final entry in decoded) {
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

  static Map<String, AnnouncementRevision> _decodeRevisions(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const {};

    final revisions = <String, AnnouncementRevision>{};
    decoded.forEach((address, value) {
      if (value is! Map<String, dynamic>) return;
      final createdAt = value['created_at'];
      final id = value['id'];
      if (createdAt is! int || id is! String) return;
      revisions[address] =
          AnnouncementRevision(createdAt: createdAt, eventId: id);
    });
    return revisions;
  }

  static String _encodeRevisions(Map<String, AnnouncementRevision> revisions) {
    return jsonEncode({
      for (final entry in revisions.entries)
        entry.key: {
          'created_at': entry.value.createdAt,
          'id': entry.value.eventId,
        },
    });
  }
}
