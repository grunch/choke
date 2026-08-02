import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/announcements/models/announcement.dart';
import 'package:choke/features/announcements/models/app_version.dart';
import 'package:choke/services/nostr/nostr_service.dart';

const Object _unset = Object();

/// The four locale blocks §2.2 requires, so a test only has to name the one
/// thing it is changing.
Map<String, dynamic> _locales({
  String title = 'Version 2.1 is out',
  String body = 'It fixes the clock drifting on long matches.',
  Set<String> only = kAnnouncementLocales,
}) {
  return {
    for (final code in only) code: {'title': title, 'body': body},
  };
}

/// A well-formed announcement event, with hooks for the piece under test.
NostrEvent _event({
  int kind = kAnnouncementKind,
  String pubkey = 'aa11',
  String? dTag = 'release-2-1',
  String? expiration = '4102444800', // 2100-01-01
  int createdAt = 1754006400,
  String id = 'e1',
  Object? content = _unset,
  Map<String, dynamic>? locales,
  String? url,
  String? minVersion,
  String? maxVersion,
  int? schemaVersion = kAnnouncementSchemaVersion,
}) {
  final body = <String, dynamic>{
    if (schemaVersion != null) 'v': schemaVersion,
    'locales': locales ?? _locales(),
    if (url != null) 'url': url,
  };

  return NostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    kind: kind,
    tags: [
      if (dTag != null) ['d', dTag],
      if (expiration != null) ['expiration', expiration],
      if (minVersion != null) ['min_version', minVersion],
      if (maxVersion != null) ['max_version', maxVersion],
    ],
    content: identical(content, _unset) ? jsonEncode(body) : content as String,
    sig: 'f' * 128,
  );
}

void main() {
  group('tryParse — the happy path', () {
    test('reads every field of a well-formed announcement', () {
      // Arrange
      final event = _event(url: 'https://bjjscore.live/notes/2-1');

      // Act
      final announcement = Announcement.tryParse(event);

      // Assert
      expect(announcement, isNotNull);
      expect(announcement!.announcementId, 'release-2-1');
      expect(announcement.publisher, 'aa11');
      expect(announcement.expiration, 4102444800);
      expect(announcement.url, Uri.parse('https://bjjscore.live/notes/2-1'));
      expect(announcement.minVersion, isNull);
      expect(announcement.maxVersion, isNull);
    });

    test('the address is the full addressable identity, not the d tag', () {
      // Arrange — two allowlisted keys may pick the same d (§3.3)
      final mine = _event(pubkey: 'aa11');
      final theirs = _event(pubkey: 'bb22');

      // Act
      final a = Announcement.tryParse(mine)!;
      final b = Announcement.tryParse(theirs)!;

      // Assert
      expect(a.address, '$kAnnouncementKind:aa11:release-2-1');
      expect(b.address, '$kAnnouncementKind:bb22:release-2-1');
      expect(a.address, isNot(b.address));
    });

    test('the revision carries both created_at and the event id', () {
      // Arrange
      final event = _event(createdAt: 1754006400, id: 'abc');

      // Act
      final announcement = Announcement.tryParse(event)!;

      // Assert
      expect(announcement.revision.createdAt, 1754006400);
      expect(announcement.revision.eventId, 'abc');
      expect(announcement.createdAt, 1754006400);
    });

    test('trims the title and body it stores', () {
      // Arrange
      final event =
          _event(locales: _locales(title: '  Hi  ', body: '  There '));

      // Act
      final announcement = Announcement.tryParse(event)!;

      // Assert
      expect(announcement.textFor('en').title, 'Hi');
      expect(announcement.textFor('en').body, 'There');
    });
  });

  group('tryParse — the event shell', () {
    test('ignores any kind but the announcement kind', () {
      // Assert — a match event must never be read as an announcement
      expect(Announcement.tryParse(_event(kind: 31415)), isNull);
    });

    test('ignores an event with no usable d tag', () {
      // Assert — without a d there is no address to key anything by
      expect(Announcement.tryParse(_event(dTag: null)), isNull);
      expect(Announcement.tryParse(_event(dTag: '')), isNull);
    });

    test('ignores an event whose expiration is missing or unreadable', () {
      // Assert — expiration is required (§2, §3.4)
      expect(Announcement.tryParse(_event(expiration: null)), isNull);
      expect(Announcement.tryParse(_event(expiration: 'soon')), isNull);
      expect(Announcement.tryParse(_event(expiration: '')), isNull);
    });
  });

  group('tryParse — the content schema', () {
    test('ignores content that is not a JSON object', () {
      // Assert
      expect(Announcement.tryParse(_event(content: 'not json')), isNull);
      expect(Announcement.tryParse(_event(content: '[]')), isNull);
      expect(Announcement.tryParse(_event(content: '')), isNull);
    });

    test('ignores an unknown or missing schema version', () {
      // Assert — an unknown v is ignored, not rendered best-effort (§2.2)
      expect(Announcement.tryParse(_event(schemaVersion: 2)), isNull);
      expect(Announcement.tryParse(_event(schemaVersion: null)), isNull);
    });

    test('requires exactly the four locales the app ships', () {
      // Arrange — three of four, and four plus a fifth
      final missing = _event(locales: _locales(only: {'en', 'es', 'ja'}));
      final extra = _event(
        locales: {
          ..._locales(),
          'de': {'title': 'Hallo', 'body': 'Welt'},
        },
      );

      // Assert — no fallback exists to cover either case (§2.2)
      expect(Announcement.tryParse(missing), isNull);
      expect(Announcement.tryParse(extra), isNull);
    });

    test('ignores a locales value that is not a map of blocks', () {
      // Assert
      expect(Announcement.tryParse(_event(locales: {})), isNull);
      expect(
        Announcement.tryParse(_event(content: '{"v":1,"locales":"en"}')),
        isNull,
      );
      expect(
        Announcement.tryParse(
          _event(locales: {for (final c in kAnnouncementLocales) c: 'text'}),
        ),
        isNull,
      );
    });

    test('ignores a block with a missing, blank or non-string field', () {
      // Arrange
      final noTitle = _event(
        locales: {
          for (final c in kAnnouncementLocales) c: {'body': 'b'},
        },
      );
      final blankBody = _event(locales: _locales(body: '   '));
      final numericTitle = _event(
        locales: {
          for (final c in kAnnouncementLocales) c: {'title': 7, 'body': 'b'},
        },
      );

      // Assert
      expect(Announcement.tryParse(noTitle), isNull);
      expect(Announcement.tryParse(blankBody), isNull);
      expect(Announcement.tryParse(numericTitle), isNull);
    });

    test('enforces the length limits after trimming', () {
      // Arrange
      final atLimit = _event(
        locales: _locales(title: 'a' * 80, body: 'b' * 500),
      );
      final longTitle = _event(locales: _locales(title: 'a' * 81));
      final longBody = _event(locales: _locales(body: 'b' * 501));
      final paddedToLimit = _event(
        locales: _locales(title: '  ${'a' * 80}  '),
      );

      // Assert
      expect(Announcement.tryParse(atLimit), isNotNull);
      expect(Announcement.tryParse(longTitle), isNull);
      expect(Announcement.tryParse(longBody), isNull);
      expect(Announcement.tryParse(paddedToLimit), isNotNull);
    });

    test('one bad locale invalidates the announcement, not just that one', () {
      // Arrange — es is over length, the other three are fine
      final event = _event(
        locales: {
          ..._locales(),
          'es': {'title': 'a' * 81, 'body': 'b'},
        },
      );

      // Assert
      expect(Announcement.tryParse(event), isNull);
    });
  });

  group('tryParse — the url', () {
    test('drops a non-https url and still renders the announcement', () {
      // Arrange
      final insecure = _event(url: 'http://bjjscore.live');
      final scheme = _event(url: 'javascript:alert(1)');
      final garbage = _event(url: ':::');

      // Assert — §7: ignored while the announcement still renders
      expect(Announcement.tryParse(insecure)?.url, isNull);
      expect(Announcement.tryParse(scheme)?.url, isNull);
      expect(Announcement.tryParse(garbage)?.url, isNull);
      expect(Announcement.tryParse(insecure), isNotNull);
    });

    test('drops a url that is not a string', () {
      // Arrange
      final event = _event(
        content: jsonEncode({
          'v': kAnnouncementSchemaVersion,
          'locales': _locales(),
          'url': 42,
        }),
      );

      // Assert
      expect(Announcement.tryParse(event)?.url, isNull);
      expect(Announcement.tryParse(event), isNotNull);
    });

    test('keeps an https url with a host', () {
      // Arrange
      final event = _event(url: 'https://bjjscore.live/notes');

      // Assert
      expect(
        Announcement.tryParse(event)!.url,
        Uri.parse('https://bjjscore.live/notes'),
      );
    });

    test('drops an https url with no host', () {
      // Assert — "https:///x" names nothing to open
      expect(Announcement.tryParse(_event(url: 'https:///x'))?.url, isNull);
    });
  });

  group('version bounds', () {
    test('an unparseable bound invalidates the announcement', () {
      // Assert — a bound nobody can read is a targeting instruction that
      // failed; showing it to everyone is the wrong way to fail it (§2.1)
      expect(Announcement.tryParse(_event(minVersion: 'latest')), isNull);
      expect(Announcement.tryParse(_event(maxVersion: '2.1.0+454')), isNull);
    });

    test('parses both bounds when they are readable', () {
      // Arrange
      final event = _event(minVersion: '2.0.0', maxVersion: '2.1');

      // Act
      final announcement = Announcement.tryParse(event)!;

      // Assert
      expect(announcement.minVersion, AppVersion.tryParse('2.0.0'));
      expect(announcement.maxVersion, AppVersion.tryParse('2.1.0'));
    });

    test('an unbounded announcement applies to every version', () {
      // Arrange
      final announcement = Announcement.tryParse(_event())!;

      // Assert
      expect(announcement.appliesTo(AppVersion.tryParse('0.0.1')!), isTrue);
      expect(announcement.appliesTo(AppVersion.tryParse('99.0.0')!), isTrue);
    });

    test('min_version is inclusive', () {
      // Arrange
      final announcement = Announcement.tryParse(_event(minVersion: '2.1.0'))!;

      // Assert
      expect(announcement.appliesTo(AppVersion.tryParse('2.0.9')!), isFalse);
      expect(announcement.appliesTo(AppVersion.tryParse('2.1.0')!), isTrue);
      expect(announcement.appliesTo(AppVersion.tryParse('2.1.1')!), isTrue);
    });

    test('max_version is exclusive, so 2.1 never hears that 2.1 is out', () {
      // Arrange — the case the whole bound exists for (§2.1)
      final announcement = Announcement.tryParse(_event(maxVersion: '2.1.0'))!;

      // Assert
      expect(announcement.appliesTo(AppVersion.tryParse('2.0.9')!), isTrue);
      expect(announcement.appliesTo(AppVersion.tryParse('2.1.0')!), isFalse);
      expect(announcement.appliesTo(AppVersion.tryParse('2.1.1')!), isFalse);
    });

    test('both bounds together describe a half-open range', () {
      // Arrange
      final announcement = Announcement.tryParse(
        _event(minVersion: '2.0.0', maxVersion: '2.1.0'),
      )!;

      // Assert
      expect(announcement.appliesTo(AppVersion.tryParse('1.9.9')!), isFalse);
      expect(announcement.appliesTo(AppVersion.tryParse('2.0.0')!), isTrue);
      expect(announcement.appliesTo(AppVersion.tryParse('2.0.9')!), isTrue);
      expect(announcement.appliesTo(AppVersion.tryParse('2.1.0')!), isFalse);
    });
  });

  group('textFor', () {
    test('every one of the four locales resolves to its own copy', () {
      // Arrange
      final event = _event(
        locales: {
          for (final code in kAnnouncementLocales)
            code: {'title': 'title-$code', 'body': 'body-$code'},
        },
      );

      // Act
      final announcement = Announcement.tryParse(event)!;

      // Assert
      for (final code in kAnnouncementLocales) {
        expect(announcement.textFor(code).title, 'title-$code');
        expect(announcement.textFor(code).body, 'body-$code');
      }
    });
  });

  group('AnnouncementRevision', () {
    test('a newer created_at supersedes an older one', () {
      // Arrange
      const older = AnnouncementRevision(createdAt: 10, eventId: 'aa');
      const newer = AnnouncementRevision(createdAt: 11, eventId: 'zz');

      // Assert
      expect(newer.supersedes(older), isTrue);
      expect(older.supersedes(newer), isFalse);
    });

    test('on a tie the lowest event id wins, as NIP-01 says', () {
      // Arrange — the same rule NostrService already applies to matches
      const held = AnnouncementRevision(createdAt: 10, eventId: 'bb');
      const lower = AnnouncementRevision(createdAt: 10, eventId: 'aa');
      const higher = AnnouncementRevision(createdAt: 10, eventId: 'cc');

      // Assert
      expect(lower.supersedes(held), isTrue);
      expect(higher.supersedes(held), isFalse);
    });

    test('a revision does not supersede itself', () {
      // Arrange — a redelivery of the same event must not re-announce
      const revision = AnnouncementRevision(createdAt: 10, eventId: 'bb');

      // Assert
      expect(revision.supersedes(revision), isFalse);
      expect(
          revision, const AnnouncementRevision(createdAt: 10, eventId: 'bb'));
    });
  });

  group('the locale set', () {
    test('matches the locales the app itself ships', () {
      // Assert — §2.2 pins the schema to AppLocalizations.supportedLocales;
      // if a locale is ever added, this fails until the schema follows
      expect(kAnnouncementLocales, {'en', 'es', 'ja', 'pt'});
    });
  });
}
