import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/announcements/announcement_inbox.dart';
import 'package:choke/features/announcements/announcement_providers.dart';
import 'package:choke/features/announcements/announcements_screen.dart';
import 'package:choke/features/announcements/models/announcement.dart';
import 'package:choke/features/announcements/models/app_version.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'package:choke/l10n/generated/app_localizations_en.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/shared/theme/app_theme.dart';

import '../../support/nostr_fakes.dart';

const String _publisher = 'aa11';

NostrEvent _event({
  String id = 'e1',
  String d = 'release-2-1',
  String title = 'Version 2.1 is out',
  String body = 'It fixes the clock drifting on long matches.',
  String? url,
  int ageSeconds = 60,
  Map<String, ({String title, String body})>? perLocale,
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return NostrEvent(
    id: id,
    pubkey: _publisher,
    createdAt: now - ageSeconds,
    kind: kAnnouncementKind,
    tags: [
      ['d', d],
      ['expiration', '${now + 8640000}'],
    ],
    content: jsonEncode({
      'v': kAnnouncementSchemaVersion,
      'locales': {
        for (final code in kAnnouncementLocales)
          code: {
            'title': perLocale?[code]?.title ?? title,
            'body': perLocale?[code]?.body ?? body,
          },
      },
      if (url != null) 'url': url,
    }),
    sig: 'f' * 128,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingRelayBackend backend;
  late NostrService service;
  late AnnouncementInbox inbox;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final l10n = AppLocalizationsEn();

  /// Build the channel and put the screen in front of it.
  ///
  /// Everything is created inside the test body rather than in `setUp`: a
  /// broadcast stream created outside the zone `testWidgets` runs in delivers
  /// its events on that other zone's microtask queue, and `pumpAndSettle`
  /// never flushes them — the screen would sit empty while the relay
  /// cheerfully reported the event delivered.
  Future<void> pumpScreen(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    final crypto = FakeNostrCrypto();
    backend = RecordingRelayBackend();
    service = NostrService(
      KeyManager(crypto: crypto),
      crypto: crypto,
      backend: backend,
    );
    addTearDown(service.dispose);
    // Not disposed here: from the moment the widget is pumped the
    // ProviderScope owns it, and disposing it twice is an error.
    inbox = AnnouncementInbox(
      service: service,
      crypto: crypto,
      appVersion: AppVersion.tryParse('2.0.1')!,
      publishers: const [_publisher],
    )..open();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementInboxProvider.overrideWith((_) => inbox),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const AnnouncementsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> deliver(NostrEvent event, WidgetTester tester) async {
    backend.eventsController.add(event);
    await tester.pumpAndSettle();
  }

  group('empty state', () {
    testWidgets('says what the channel is for', (tester) async {
      // Arrange + Act — an empty list otherwise reads as something broken
      await pumpScreen(tester);

      // Assert
      expect(find.text(l10n.announcementsEmpty), findsOneWidget);
      expect(find.text(l10n.announcementsEmptyDetail), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('shows title, body and the newest first', (tester) async {
      // Arrange
      await pumpScreen(tester);

      // Act
      await deliver(_event(d: 'old', title: 'Older', ageSeconds: 7200), tester);
      await deliver(_event(id: 'e2', d: 'new', title: 'Newer'), tester);

      // Assert
      expect(find.text('Newer'), findsOneWidget);
      expect(find.text('Older'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Newer')).dy,
        lessThan(tester.getTopLeft(find.text('Older')).dy),
      );
    });

    testWidgets('renders the copy for the current locale', (tester) async {
      // Arrange — the whole reason all four locales ride in one event
      await pumpScreen(tester, locale: const Locale('ja'));

      // Act
      await deliver(
        _event(
          perLocale: {
            'en': (title: 'English title', body: 'b'),
            'es': (title: 'Título', body: 'b'),
            'ja': (title: '日本語のタイトル', body: 'b'),
            'pt': (title: 'Título pt', body: 'b'),
          },
        ),
        tester,
      );

      // Assert
      expect(find.text('日本語のタイトル'), findsOneWidget);
      expect(find.text('English title'), findsNothing);
    });

    testWidgets('offers the link only when there is one', (tester) async {
      // Arrange
      await pumpScreen(tester);

      // Act
      await deliver(_event(d: 'plain'), tester);

      // Assert
      expect(find.text(l10n.announcementsOpen), findsNothing);

      // Act — and one that carries a url
      await deliver(
        _event(id: 'e2', d: 'linked', url: 'https://bjjscore.live/notes'),
        tester,
      );

      // Assert
      expect(find.text(l10n.announcementsOpen), findsOneWidget);
    });

    testWidgets('a non-https link is dropped, the announcement still renders',
        (tester) async {
      // Arrange
      await pumpScreen(tester);

      // Act
      await deliver(_event(url: 'http://bjjscore.live'), tester);

      // Assert
      expect(find.text('Version 2.1 is out'), findsOneWidget);
      expect(find.text(l10n.announcementsOpen), findsNothing);
    });
  });

  group('read and dismiss', () {
    testWidgets('tapping an item marks it read', (tester) async {
      // Arrange
      await pumpScreen(tester);
      await deliver(_event(), tester);
      expect(inbox.state.hasUnread, isTrue);

      // Act
      await tester.tap(find.text('Version 2.1 is out'));
      await tester.pumpAndSettle();

      // Assert
      expect(inbox.state.hasUnread, isFalse);
    });

    testWidgets('swiping dismisses it, and it stays gone', (tester) async {
      // Arrange
      await pumpScreen(tester);
      await deliver(_event(), tester);

      // Act
      await tester.drag(find.text('Version 2.1 is out'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Assert — off the screen, and off the list behind it
      expect(find.text('Version 2.1 is out'), findsNothing);
      expect(inbox.state.entries, isEmpty);
      expect(find.text(l10n.announcementsEmpty), findsOneWidget);
    });

    testWidgets('read and dismissed state survives a restart', (tester) async {
      // Arrange
      await pumpScreen(tester);
      await deliver(_event(d: 'read-me'), tester);
      await deliver(_event(id: 'e2', d: 'dismiss-me', title: 'Gone'), tester);
      await tester.tap(find.text('Version 2.1 is out'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Gone'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Act — a fresh inbox over the same storage
      final restarted = AnnouncementInbox(
        service: service,
        crypto: FakeNostrCrypto(),
        appVersion: AppVersion.tryParse('2.0.1')!,
        publishers: const [_publisher],
      );
      addTearDown(restarted.dispose);
      await restarted.restore();

      // Assert
      expect(restarted.state.entries, hasLength(1));
      expect(restarted.state.entries.single.isRead, isTrue);
      expect(restarted.state.hasUnread, isFalse);
    });
  });

  group('the relative date', () {
    testWidgets('reads coarsely, in the current locale', (tester) async {
      // Arrange
      await pumpScreen(tester);

      // Act — under an hour, then a couple of hours, then days
      await deliver(_event(d: 'now', ageSeconds: 120), tester);
      await deliver(_event(id: 'e2', d: 'hours', ageSeconds: 7200), tester);
      await deliver(_event(id: 'e3', d: 'days', ageSeconds: 3 * 86400), tester);

      // Assert
      expect(find.text(l10n.announcementsWhenNow), findsOneWidget);
      expect(find.text(l10n.announcementsWhenHours(2)), findsOneWidget);
      expect(find.text(l10n.announcementsWhenDays(3)), findsOneWidget);
    });
  });
}
