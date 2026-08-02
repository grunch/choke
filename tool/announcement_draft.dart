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

  final Map<String, ({String title, String body})> locales;
  final String? url;
  final String? minVersion;
  final String? maxVersion;

  const AnnouncementDraft({
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

  static List<int>? _parseVersion(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.contains('+')) return null;

    final dash = text.indexOf('-');
    final core = dash == -1 ? text : text.substring(0, dash);
    if (dash != -1 && text.substring(dash + 1).isEmpty) return null;

    final parts = core.split('.');
    if (parts.length > 3) return null;

    final numbers = <int>[0, 0, 0];
    for (var i = 0; i < parts.length; i++) {
      if (!RegExp(r'^\d+$').hasMatch(parts[i])) return null;
      final value = int.tryParse(parts[i]);
      if (value == null) return null;
      numbers[i] = value;
    }
    return numbers;
  }

  static int _compare(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }
}
