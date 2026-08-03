import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/announcements/models/announcement.dart';
import 'package:choke/features/announcements/models/app_version.dart';
import 'package:choke/services/nostr/nostr_service.dart' show NostrEvent;

import '../../tool/announcement_draft.dart';

final DateTime _now = DateTime.utc(2026, 8, 2, 12);
int get _nowSeconds => _now.millisecondsSinceEpoch ~/ 1000;

Map<String, dynamic> _draft({
  Object? d = 'release-2-1',
  Object? expiresAt = '2026-09-01T00:00:00Z',
  Object? url,
  Object? minVersion,
  Object? maxVersion,
  Map<String, dynamic>? locales,
  String title = 'Version 2.1 is out',
  String body = 'The match clock no longer drifts.',
}) {
  return {
    if (d != null) 'd': d,
    if (expiresAt != null) 'expires_at': expiresAt,
    if (url != null) 'url': url,
    if (minVersion != null) 'min_version': minVersion,
    if (maxVersion != null) 'max_version': maxVersion,
    'locales': locales ??
        {
          for (final code in kAnnouncementLocales)
            code: {'title': title, 'body': body},
        },
  };
}

/// Whether the app itself would accept what the tool emitted.
///
/// The tool cannot ask this at runtime — it runs on the plain Dart VM and the
/// parser lives behind Flutter — so the question is asked here instead, over
/// exactly the event that would have been published. This is what keeps the
/// two ends from drifting.
bool appAccepts(Map<String, dynamic> event) {
  final probe = NostrEvent(
    id: 'unsigned',
    pubkey: 'unsigned',
    createdAt: event['created_at'] as int,
    kind: event['kind'] as int,
    tags: (event['tags'] as List)
        .map((tag) => (tag as List).cast<String>())
        .toList(),
    content: event['content'] as String,
    sig: 'unsigned',
  );
  return Announcement.tryParse(probe) != null;
}

/// The messages a draft produces, or an empty list if it is valid.
List<String> errorsFor(Map<String, dynamic> json) {
  try {
    AnnouncementDraft.fromJson(json).toUnsignedEvent(now: _now);
    return const [];
  } on DraftErrors catch (e) {
    return e.messages;
  }
}

void main() {
  group('a valid draft', () {
    test('becomes an event the app would accept', () {
      // Arrange
      final draft = AnnouncementDraft.fromJson(
        _draft(url: 'https://bjjscore.live/notes', maxVersion: '2.1.0'),
      );

      // Act
      final event = draft.toUnsignedEvent(now: _now);

      // Assert — the reader's own parser is the gate this has to clear
      expect(appAccepts(event), isTrue);
      expect(event['kind'], kAnnouncementKind);
      expect(event['created_at'], _nowSeconds);
    });

    test('carries the tags §2.1 defines, and no others', () {
      // Arrange
      final draft = AnnouncementDraft.fromJson(
        _draft(minVersion: '2.0.0', maxVersion: '2.1.0'),
      );

      // Act
      final tags = (draft.toUnsignedEvent(now: _now)['tags'] as List)
          .map((tag) => (tag as List).first)
          .toList();

      // Assert
      expect(tags, ['d', 'expiration', 'min_version', 'max_version']);
    });

    test('leaves the signature to whoever holds the key', () {
      // Arrange + Act — the key of §3.1 is offline, and this tool never sees
      // it: no pubkey, no id, no sig
      final event =
          AnnouncementDraft.fromJson(_draft()).toUnsignedEvent(now: _now);

      // Assert
      expect(event.keys, isNot(contains('pubkey')));
      expect(event.keys, isNot(contains('sig')));
      expect(event.keys, isNot(contains('id')));
    });

    test('trims the copy the way the reader will', () {
      // Arrange
      final draft = AnnouncementDraft.fromJson(
        _draft(title: '  Padded  ', body: '  Also padded  '),
      );

      // Act
      final content = jsonDecode(
        draft.toUnsignedEvent(now: _now)['content'] as String,
      ) as Map<String, dynamic>;

      // Assert
      expect((content['locales'] as Map)['en'], {
        'title': 'Padded',
        'body': 'Also padded',
      });
    });

    test('accepts unix seconds as well as an instant', () {
      // Arrange + Act
      final draft = AnnouncementDraft.fromJson(
        _draft(expiresAt: _nowSeconds + 86400),
      );

      // Assert
      expect(draft.expiration, _nowSeconds + 86400);
    });
  });

  group('the sender obligations of §6', () {
    test('a d that is missing or blank is refused', () {
      // Assert — without a d there is no address to publish under
      expect(errorsFor(_draft(d: null)), contains(contains('"d"')));
      expect(errorsFor(_draft(d: '   ')), contains(contains('"d"')));
    });

    test('an expiry in the past is refused', () {
      // Assert — an announcement that expires on arrival is one nobody sees
      expect(
        errorsFor(_draft(expiresAt: '2020-01-01T00:00:00Z')),
        contains(contains('in the past')),
      );
    });

    test('an unreadable expiry is refused', () {
      // Assert
      expect(
        errorsFor(_draft(expiresAt: 'next tuesday')),
        contains(contains('"expires_at"')),
      );
    });

    test('a missing locale is named, not defaulted', () {
      // Arrange — three of the four
      final json = _draft(
        locales: {
          for (final code in ['en', 'es', 'ja'])
            code: {'title': 't', 'body': 'b'},
        },
      );

      // Assert — the app has no fallback, so this is the moment to find out
      expect(errorsFor(json), contains('"locales.pt" is missing'));
    });

    test('an unknown locale is named too', () {
      // Arrange
      final json = _draft(
        locales: {
          for (final code in kAnnouncementLocales)
            code: {'title': 't', 'body': 'b'},
          'de': {'title': 'Hallo', 'body': 'Welt'},
        },
      );

      // Assert
      expect(errorsFor(json), contains(contains('de')));
    });

    test('over-length copy is reported with its own length', () {
      // Arrange
      final json = _draft(title: 'a' * 81, body: 'b' * 501);

      // Act
      final errors = errorsFor(json);

      // Assert — a publisher who would otherwise count characters by hand
      expect(errors, contains(contains('81 characters')));
      expect(errors, contains(contains('501 characters')));
    });

    test('every broken locale is reported at once', () {
      // Arrange — a publisher fixing four things wants to see four things
      final json = _draft(title: 'a' * 81);

      // Assert
      expect(errorsFor(json), hasLength(kAnnouncementLocales.length));
    });

    test('a non-https url is refused rather than silently dropped', () {
      // Assert — the app drops it and says nothing, which is exactly the
      // failure this tool exists to catch
      expect(
        errorsFor(_draft(url: 'http://bjjscore.live')),
        contains(contains('https')),
      );
    });

    test('a bound with build metadata is refused, with the reason', () {
      // Assert
      expect(
        errorsFor(_draft(maxVersion: '2.1.0+454')),
        contains(contains('never 2.1.0+454')),
      );
    });

    test('an inverted range is refused', () {
      // Assert — max_version is exclusive, so this reaches nobody
      expect(
        errorsFor(_draft(minVersion: '2.1.0', maxVersion: '2.1.0')),
        contains(contains('holds nobody')),
      );
      expect(
        errorsFor(_draft(minVersion: '2.2.0', maxVersion: '2.1.0')),
        contains(contains('holds nobody')),
      );
    });

    test('a half-open range that holds somebody is fine', () {
      // Assert
      expect(
        errorsFor(_draft(minVersion: '2.0.0', maxVersion: '2.1.0')),
        isEmpty,
      );
    });
  });

  group('warnings', () {
    test('an expiry past the freshness window is called out, not refused', () {
      // Arrange — valid, and the sender is wrong about how long it lasts:
      // readers drop anything older than the window whatever the expiry says
      final draft = AnnouncementDraft.fromJson(
        _draft(expiresAt: _nowSeconds + (kAnnouncementMaxAgeDays + 10) * 86400),
      );

      // Act
      final event = draft.toUnsignedEvent(now: _now);

      // Assert
      expect(appAccepts(event), isTrue);
      expect(draft.warnings, contains(contains('freshness window')));
    });

    test('an expiry inside the window warns about nothing', () {
      // Arrange
      final draft = AnnouncementDraft.fromJson(
        _draft(expiresAt: _nowSeconds + 86400),
      );

      // Act
      draft.toUnsignedEvent(now: _now);

      // Assert
      expect(draft.warnings, isEmpty);
    });
  });

  group('the validator it shares with the reader', () {
    test('what the tool emits is what the app parses', () {
      // Arrange — the point of §8 step 5: one validator, not two
      final event = AnnouncementDraft.fromJson(
        _draft(url: 'https://bjjscore.live/notes', maxVersion: '2.1.0'),
      ).toUnsignedEvent(now: _now);

      // Assert
      expect(appAccepts(event), isTrue);
    });

    test('the check itself has teeth', () {
      // Arrange — hand-built, bypassing the draft entirely
      final event = {
        'kind': kAnnouncementKind,
        'created_at': _nowSeconds,
        'tags': [
          ['d', 'x'],
          ['expiration', '${_nowSeconds + 86400}'],
        ],
        'content': jsonEncode({'v': 99, 'locales': <String, dynamic>{}}),
      };

      // Assert — otherwise the assertions above would pass on anything
      expect(appAccepts(event), isFalse);
    });

    test('the tool and the app agree on what a version bound is', () {
      // Arrange — the tool reads bounds with its own small parser, because
      // AppVersion lives behind Flutter. These are the cases where a
      // disagreement would mean publishing something nobody receives.
      const cases = {
        '2.1.0': true,
        '2.1': true,
        '2': true,
        '2.1.0-beta.1': true,
        '2.1.0-beta..1': false,
        '2.1.0-beta!': false,
        '2.1.0-': false,
        '2.1.0+454': false,
        '2.1.0.1': false,
        'latest': false,
        '': false,
        '2.x': false,
        '99999999999999999999999.0.0': false,
      };

      for (final entry in cases.entries) {
        // Act — the app's verdict, and the tool's
        final appAccepted = AppVersion.tryParse(entry.key) != null;
        final toolAccepted = errorsFor(_draft(maxVersion: entry.key)).isEmpty;

        // Assert
        expect(
          appAccepted,
          entry.value,
          reason: 'the app on "${entry.key}"',
        );
        expect(
          toolAccepted,
          entry.value,
          reason: 'the tool on "${entry.key}"',
        );
      }
    });
  });
}
