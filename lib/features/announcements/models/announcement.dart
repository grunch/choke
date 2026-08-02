import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../services/nostr/nostr_service.dart'
    show NostrEvent, addressableSupersedes;
import 'app_version.dart';

/// The announcement kind: addressable, adjacent to the match kind 31415.
const int kAnnouncementKind = 31416;

/// The only content schema version this build understands. An event with any
/// other `v` is ignored rather than rendered best-effort (§2.2).
const int kAnnouncementSchemaVersion = 1;

/// Exactly the locales the app ships. An announcement must carry all four and
/// no others: there is no fallback, because a fallback is a bug that ships
/// quietly — the reader gets a language they did not choose and nobody finds
/// out (§2.2). Pinned to `AppLocalizations.supportedLocales` by test.
const Set<String> kAnnouncementLocales = {'en', 'es', 'ja', 'pt'};

const int kAnnouncementTitleMaxLength = 80;
const int kAnnouncementBodyMaxLength = 500;

/// One locale's copy.
@immutable
class AnnouncementText {
  final String title;
  final String body;

  const AnnouncementText({required this.title, required this.body});

  @override
  bool operator ==(Object other) =>
      other is AnnouncementText && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);
}

/// Which revision of an announcement this is.
///
/// Both halves matter. `created_at` alone does not order two events — a
/// correction republished within the same second is an ordinary outcome of
/// fixing a typo and hitting publish, and with a bare timestamp the winner is
/// whichever relay answered first, which is two phones showing two different
/// texts of the same announcement (§3.3).
@immutable
class AnnouncementRevision {
  final int createdAt;
  final String eventId;

  const AnnouncementRevision({required this.createdAt, required this.eventId});

  /// Whether this revision replaces [held].
  ///
  /// Delegates to [addressableSupersedes] rather than restating NIP-01's rule:
  /// there is one definition of "which is newer" in this app, and two would be
  /// exactly how they stop agreeing.
  bool supersedes(AnnouncementRevision held) => addressableSupersedes(
        arrivingCreatedAt: createdAt,
        arrivingId: eventId,
        heldCreatedAt: held.createdAt,
        heldId: held.eventId,
      );

  @override
  bool operator ==(Object other) =>
      other is AnnouncementRevision &&
      other.createdAt == createdAt &&
      other.eventId == eventId;

  @override
  int get hashCode => Object.hash(createdAt, eventId);

  @override
  String toString() => 'AnnouncementRevision($createdAt, $eventId)';
}

/// A validated announcement: everything §2 requires, and nothing a relay could
/// have made up.
///
/// Construction only happens through [tryParse], so holding one of these means
/// the schema, the locales, the lengths and the version bounds already checked
/// out. Whether it is *fresh*, *unexpired* and *signed by an allowed key* is
/// not this class's business — that is §3, enforced by the service above it.
@immutable
class Announcement {
  /// `31416:<publisher hex>:<d>` — the addressable identity, which is what
  /// everything downstream keys by. Never the `d` alone: the allowlist is a
  /// list, so two keys can pick the same `d` (§3.3).
  final String address;

  /// Hex pubkey of the key that signed it.
  final String publisher;

  /// The `d` tag: the sender's id for this announcement.
  final String announcementId;

  final AnnouncementRevision revision;

  /// NIP-40 expiry, unix seconds. Required by §2.
  final int expiration;

  /// All four locales, always. See [kAnnouncementLocales].
  final Map<String, AnnouncementText> locales;

  /// The single action link, or null — absent, or present but not something
  /// this app will open (§7: a bad url is dropped, the announcement still
  /// renders).
  final Uri? url;

  /// Inclusive lower bound on the app version this is for.
  final AppVersion? minVersion;

  /// **Exclusive** upper bound: `max_version: 2.1` is the announcement that
  /// 2.1 is out, and the people already on 2.1 are exactly who must not see
  /// it (§2.1).
  final AppVersion? maxVersion;

  const Announcement({
    required this.address,
    required this.publisher,
    required this.announcementId,
    required this.revision,
    required this.expiration,
    required this.locales,
    this.url,
    this.minVersion,
    this.maxVersion,
  });

  int get createdAt => revision.createdAt;

  /// The announcement in [languageCode].
  ///
  /// Always resolves for a code the app can render: [tryParse] rejects any
  /// event whose locale set is not exactly [kAnnouncementLocales], and that
  /// set is pinned to the app's own locales by test. The guard below is for
  /// the impossible case only — a missing translation is not worth crashing a
  /// release build over.
  AnnouncementText textFor(String languageCode) {
    final text = locales[languageCode];
    if (text != null) return text;
    debugPrint('Announcement: no copy for "$languageCode" in $address');
    return locales.values.first;
  }

  /// Whether this announcement targets [appVersion].
  bool appliesTo(AppVersion appVersion) {
    if (minVersion != null && appVersion < minVersion!) return false;
    if (maxVersion != null && appVersion >= maxVersion!) return false;
    return true;
  }

  /// The announcement in [event], or null if the event is not a valid one.
  ///
  /// Every rejection is silent by design (§4.4): there is nothing a user could
  /// do about a malformed announcement, and "an announcement failed to parse"
  /// is itself a message from a source we have not verified. Details go to
  /// [debugPrint], per the AGENTS.md rule on raw exceptions.
  static Announcement? tryParse(NostrEvent event) {
    if (event.kind != kAnnouncementKind) {
      return _reject(event, 'kind ${event.kind} is not an announcement');
    }

    final id = _tag(event, 'd');
    if (id == null || id.isEmpty) return _reject(event, 'no d tag');

    final expirationTag = _tag(event, 'expiration');
    final expiration =
        expirationTag == null ? null : int.tryParse(expirationTag);
    if (expiration == null) return _reject(event, 'no readable expiration');

    final Object? decoded;
    try {
      decoded = jsonDecode(event.content);
    } catch (e) {
      return _reject(event, 'content is not JSON: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      return _reject(event, 'content is not a JSON object');
    }

    if (decoded['v'] != kAnnouncementSchemaVersion) {
      return _reject(event, 'unknown schema version ${decoded['v']}');
    }

    final locales = _parseLocales(event, decoded['locales']);
    if (locales == null) return null;

    // An unreadable bound is a targeting instruction that failed, and showing
    // the message to everyone is the wrong way to fail it (§2.1).
    final minTag = _tag(event, 'min_version');
    final AppVersion? minVersion;
    if (minTag == null) {
      minVersion = null;
    } else {
      minVersion = AppVersion.tryParse(minTag);
      if (minVersion == null) {
        return _reject(event, 'unparseable min_version "$minTag"');
      }
    }

    final maxTag = _tag(event, 'max_version');
    final AppVersion? maxVersion;
    if (maxTag == null) {
      maxVersion = null;
    } else {
      maxVersion = AppVersion.tryParse(maxTag);
      if (maxVersion == null) {
        return _reject(event, 'unparseable max_version "$maxTag"');
      }
    }

    return Announcement(
      address: '$kAnnouncementKind:${event.pubkey}:$id',
      publisher: event.pubkey,
      announcementId: id,
      revision: AnnouncementRevision(
        createdAt: event.createdAt,
        eventId: event.id,
      ),
      expiration: expiration,
      locales: Map.unmodifiable(locales),
      url: _parseUrl(event, decoded['url']),
      minVersion: minVersion,
      maxVersion: maxVersion,
    );
  }

  /// All four locale blocks, or null if any of them is missing, extra, or
  /// malformed. One bad block invalidates the whole announcement: the sender
  /// publishes once, by hand, and a partial render is how they never find out.
  static Map<String, AnnouncementText>? _parseLocales(
    NostrEvent event,
    Object? raw,
  ) {
    if (raw is! Map<String, dynamic>) {
      return _reject(event, 'locales is not an object');
    }
    if (raw.length != kAnnouncementLocales.length ||
        !kAnnouncementLocales.containsAll(raw.keys)) {
      return _reject(
        event,
        'locales are ${raw.keys.toList()}, '
        'expected exactly ${kAnnouncementLocales.toList()}',
      );
    }

    final parsed = <String, AnnouncementText>{};
    for (final code in kAnnouncementLocales) {
      final block = raw[code];
      if (block is! Map<String, dynamic>) {
        return _reject(event, 'locale "$code" is not an object');
      }

      final title = _text(block['title'], max: kAnnouncementTitleMaxLength);
      if (title == null) return _reject(event, 'bad title in "$code"');

      final body = _text(block['body'], max: kAnnouncementBodyMaxLength);
      if (body == null) return _reject(event, 'bad body in "$code"');

      parsed[code] = AnnouncementText(title: title, body: body);
    }
    return parsed;
  }

  /// A non-empty string of at most [max] characters after trimming, or null.
  static String? _text(Object? raw, {required int max}) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.length > max) return null;
    return trimmed;
  }

  /// The action link, if it is one this app will open.
  ///
  /// Anything else is dropped and the announcement still renders (§7): the
  /// copy is the message, the link is an extra, and a sender who typo'd a
  /// scheme should not silence the text as well.
  static Uri? _parseUrl(NostrEvent event, Object? raw) {
    if (raw == null) return null;
    if (raw is! String) {
      debugPrint('Announcement ${event.id}: url is not a string');
      return null;
    }

    final url = Uri.tryParse(raw);
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      debugPrint('Announcement ${event.id}: dropping url "$raw"');
      return null;
    }
    return url;
  }

  static String? _tag(NostrEvent event, String name) {
    for (final tag in event.tags) {
      if (tag.length > 1 && tag[0] == name) return tag[1];
    }
    return null;
  }

  static Null _reject(NostrEvent event, String why) {
    debugPrint('Announcement: ignoring event ${event.id} — $why');
    return null;
  }
}
