import 'dart:convert';

import 'package:choke/features/announcements/models/announcement_schema.dart';

/// Everything wrong with a draft, in the order a human would fix it.
class DraftErrors implements Exception {
  final List<String> messages;

  const DraftErrors(this.messages);

  bool get isEmpty => messages.isEmpty;

  @override
  String toString() => messages.map((m) => '  - $m').join('\n');
}

/// A draft as written by hand, before it is an event.
///
/// The reader's failure mode is silence: publish a malformed announcement and
/// nothing tells you, on either end (§6). So the sender's obligations are
/// checked here, before anything is signed.
///
/// This runs on the plain Dart VM, where `dart:ui` does not exist, so it
/// cannot call the app's own parser — that lives behind Flutter. The
/// constants it must agree on are shared (`announcement_schema.dart`), and
/// what it emits is fed through the real `Announcement.tryParse` by test:
/// drift between the end that writes an announcement and the end that reads
/// one fails the suite rather than a publish.
///
/// Nothing here signs, and nothing here talks to a relay. Signing is `nak`, or
/// any client holding the offline key of §3.1, and keeping it out of this tool
/// is what keeps the key off the machine that writes the copy — and keeps Dart
/// out of the crypto (AGENTS.md).
class AnnouncementDraft {
  /// The announcement id: stable, opaque, unique — unless this is deliberately
  /// correcting a live announcement, in which case it repeats the one being
  /// corrected (§6).
  final String id;

  /// When the announcement stops being true, unix seconds. Required: it is
  /// what keeps "we are down for maintenance tonight" from being read as news
  /// a month later, and it means nothing published here is permanent (§3.4).
  final int expiration;

  /// The title and body per locale. All four the app ships, and no others:
  /// there is no fallback, so a missing locale is a reader who sees nothing
  /// (§2.2).
  final Map<String, ({String title, String body})> locales;

  /// Where "read more" goes, or null for an announcement that is only text.
  /// https with a host, since the app drops anything else silently (§2.2).
  final String? url;

  /// The oldest app version this announcement is for, inclusive. Null targets
  /// every version below [maxVersion] (§2.1).
  final String? minVersion;

  /// The version this announcement stops being for, **exclusive** — a build
  /// reporting exactly this version does not see it. Null leaves the range open
  /// at the top (§2.1).
  final String? maxVersion;

  AnnouncementDraft({
    required this.id,
    required this.expiration,
    required this.locales,
    this.url,
    this.minVersion,
    this.maxVersion,
  });

  /// Read a draft file. Shape errors are collected, not thrown one at a time:
  /// a publisher fixing four things wants to see four things.
  static AnnouncementDraft fromJson(Map<String, dynamic> json) {
    final errors = <String>[];

    final id = json['d'];
    if (id is! String || id.trim().isEmpty) {
      errors.add('"d" must be a non-empty string');
    }

    final expiration = _readExpiration(json['expires_at'], errors);

    final locales = <String, ({String title, String body})>{};
    final rawLocales = json['locales'];
    if (rawLocales is! Map<String, dynamic>) {
      errors.add('"locales" must be an object with the four app locales');
    } else {
      for (final code in kAnnouncementLocales) {
        final block = rawLocales[code];
        if (block is! Map<String, dynamic>) {
          errors.add('"locales.$code" is missing');
          continue;
        }
        final title = block['title'];
        final body = block['body'];
        if (title is! String || title.trim().isEmpty) {
          errors.add('"locales.$code.title" must be a non-empty string');
        } else if (title.trim().length > kAnnouncementTitleMaxLength) {
          errors.add(
            '"locales.$code.title" is ${title.trim().length} characters, '
            'the limit is $kAnnouncementTitleMaxLength',
          );
        }
        if (body is! String || body.trim().isEmpty) {
          errors.add('"locales.$code.body" must be a non-empty string');
        } else if (body.trim().length > kAnnouncementBodyMaxLength) {
          errors.add(
            '"locales.$code.body" is ${body.trim().length} characters, '
            'the limit is $kAnnouncementBodyMaxLength',
          );
        }
        if (title is String && body is String) {
          locales[code] = (title: title.trim(), body: body.trim());
        }
      }
      final extra = rawLocales.keys.toSet().difference(kAnnouncementLocales);
      if (extra.isNotEmpty) {
        errors.add(
          '"locales" carries ${extra.join(', ')}, which this build cannot '
          'render — the app has exactly ${kAnnouncementLocales.join(', ')}',
        );
      }
    }

    final url = json['url'];
    if (url != null && url is! String) errors.add('"url" must be a string');

    final minVersion = json['min_version'];
    if (minVersion != null && minVersion is! String) {
      errors.add('"min_version" must be a string');
    }
    final maxVersion = json['max_version'];
    if (maxVersion != null && maxVersion is! String) {
      errors.add('"max_version" must be a string');
    }

    if (errors.isNotEmpty) throw DraftErrors(errors);

    return AnnouncementDraft(
      id: (id as String).trim(),
      expiration: expiration!,
      locales: locales,
      url: url as String?,
      minVersion: minVersion as String?,
      maxVersion: maxVersion as String?,
    );
  }

  /// An ISO-8601 instant or a bare unix second count.
  static int? _readExpiration(Object? raw, List<String> errors) {
    if (raw is int) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.millisecondsSinceEpoch ~/ 1000;
    }
    errors.add(
      '"expires_at" must be an ISO-8601 instant ("2026-09-01T00:00:00Z") '
      'or unix seconds',
    );
    return null;
  }

  /// Things that are not wrong but are probably not what the sender meant.
  ///
  /// Filled by [toUnsignedEvent]; empty until it has run.
  final List<String> warnings = [];

  /// The unsigned event, once every obligation of §6 checks out.
  ///
  /// Throws [DraftErrors] otherwise. The returned map carries no `pubkey`,
  /// `id` or `sig` on purpose: those come from whatever holds the key.
  Map<String, dynamic> toUnsignedEvent({required DateTime now}) {
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final errors = <String>[];

    if (expiration <= nowSeconds) {
      errors.add(
        '"expires_at" is in the past — an announcement that expires on '
        'arrival is one nobody will ever see',
      );
    }

    if (url != null) {
      final parsed = Uri.tryParse(url!);
      if (parsed == null || parsed.scheme != 'https' || parsed.host.isEmpty) {
        errors.add(
          '"url" must be https with a host — the app drops anything else, '
          'and does it silently',
        );
      }
    }

    // Not an error: the event is valid, and the sender is simply wrong about
    // how long it lasts. Readers drop anything whose created_at is older than
    // the freshness window, so an expiry past it ends the announcement
    // somewhere the sender did not choose (§3.3).
    warnings.clear();
    final freshUntil = nowSeconds + kAnnouncementMaxAgeDays * 86400;
    if (expiration > freshUntil) {
      warnings.add(
        'expires_at is beyond the $kAnnouncementMaxAgeDays-day freshness '
        'window, so readers will stop showing this after '
        '$kAnnouncementMaxAgeDays days regardless — the expiry does not '
        'extend it',
      );
    }

    final min = _bound(minVersion, 'min_version', errors);
    final max = _bound(maxVersion, 'max_version', errors);
    if (min != null && max != null && _compare(min, max) >= 0) {
      errors.add(
        'min_version $minVersion is not below max_version $maxVersion — '
        'max_version is exclusive, so this range holds nobody',
      );
    }

    final content = jsonEncode({
      'v': kAnnouncementSchemaVersion,
      'locales': {
        for (final entry in locales.entries)
          entry.key: {'title': entry.value.title, 'body': entry.value.body},
      },
      if (url != null) 'url': url,
    });

    final event = <String, dynamic>{
      'kind': kAnnouncementKind,
      'created_at': nowSeconds,
      'tags': [
        ['d', id],
        ['expiration', '$expiration'],
        if (minVersion != null) ['min_version', minVersion],
        if (maxVersion != null) ['max_version', maxVersion],
      ],
      'content': content,
    };

    if (errors.isNotEmpty) throw DraftErrors(errors);
    return event;
  }

  /// The three numbers in a bound, or null if it is not one this app can
  /// compare.
  ///
  /// A second, smaller reading of §2.1 rather than a call into the app's
  /// AppVersion: that class lives behind Flutter, and this tool has to run on
  /// the plain Dart VM. The rules it has to agree on — three numeric
  /// components at most, pre-release allowed, **build metadata rejected** —
  /// are pinned against the real parser by test.
  static List<int>? _bound(String? raw, String field, List<String> errors) {
    if (raw == null) return null;
    final parsed = _parseVersion(raw);
    if (parsed == null) {
      errors.add(
        '"$field" is not a version this app can compare ("$raw"). Build '
        'metadata is rejected: write 2.1.0, never 2.1.0+454',
      );
    }
    return parsed;
  }

  static final RegExp _numeric = RegExp(r'^\d+$');
  static final RegExp _identifier = RegExp(r'^[0-9A-Za-z-]+$');

  static List<int>? _parseVersion(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.contains('+')) return null;

    final dash = text.indexOf('-');
    final core = dash == -1 ? text : text.substring(0, dash);
    if (dash != -1) {
      // The suffix does not affect the comparison, but it still has to be a
      // pre-release: `2.1.0-beta..1` and `2.1.0-beta!` are ones AppVersion
      // rejects, and a bound the app cannot read is an announcement nobody
      // receives (§2.1).
      final suffix = text.substring(dash + 1);
      if (suffix.isEmpty) return null;
      for (final identifier in suffix.split('.')) {
        if (!_identifier.hasMatch(identifier)) return null;
      }
    }

    final parts = core.split('.');
    if (parts.length > 3) return null;

    final numbers = <int>[0, 0, 0];
    for (var i = 0; i < parts.length; i++) {
      if (!_numeric.hasMatch(parts[i])) return null;
      final value = int.tryParse(parts[i]);
      if (value == null) return null;
      numbers[i] = value;
    }
    return numbers;
  }

  /// Major, minor, patch — and nothing else.
  ///
  /// A pre-release suffix parses (the app accepts one in a bound) but does not
  /// affect this comparison, so `2.1.0-beta` and `2.1.0` compare equal here
  /// while the app orders the pre-release first. The one place it shows is the
  /// inverted-range check, and the verdict is the same either way: no build of
  /// this app ever reports a pre-release version, so a range bounded by one
  /// holds nobody regardless of which end it is on.
  static int _compare(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }
}
