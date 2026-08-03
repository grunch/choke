import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:choke/features/announcements/announcement_inbox.dart';
import 'package:choke/features/announcements/announcement_providers.dart';
import 'package:choke/features/announcements/announcement_store.dart';
import 'package:choke/features/announcements/announcements_enabled_provider.dart';
import 'package:choke/features/announcements/models/announcement.dart';
import 'package:choke/features/announcements/models/app_version.dart';
import 'package:choke/main.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/crypto/nostr_crypto.dart';
import 'package:choke/services/nostr/nostr_service.dart';

import '../../support/nostr_fakes.dart';

const String _publisher = 'aa11';

NostrEvent _event({String id = 'e1'}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return NostrEvent(
    id: id,
    pubkey: _publisher,
    createdAt: now - 60,
    kind: kAnnouncementKind,
    tags: [
      ['d', 'release-2-1'],
      ['expiration', '${now + 86400}'],
    ],
    content: jsonEncode({
      'v': kAnnouncementSchemaVersion,
      'locales': {
        for (final code in kAnnouncementLocales)
          code: {'title': 'Title', 'body': 'Body'},
      },
    }),
    sig: 'f' * 128,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the preference itself', () {
    test('the channel is on for anyone who has never touched it', () async {
      // Arrange — empty preferences

      // Act
      final enabled = await AnnouncementsEnabledNotifier.loadSaved();

      // Assert — §5 argues the default; this is where it is
      expect(enabled, isTrue);
      expect(defaultAnnouncementsEnabled, isTrue);
    });

    test('a stored preference is honoured', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'choke:announcements-enabled': false,
      });

      // Act + Assert
      expect(await AnnouncementsEnabledNotifier.loadSaved(), isFalse);
    });

    test('turning it off persists, and survives a restart', () async {
      // Arrange
      final notifier = AnnouncementsEnabledNotifier();

      // Act
      await notifier.setEnabled(false);

      // Assert
      expect(notifier.state, isFalse);
      expect(await AnnouncementsEnabledNotifier.loadSaved(), isFalse);
    });

    test('the state moves before the write, not after it', () async {
      // Arrange — the listener that closes the subscription hangs off this
      // state, and the switch has to act at the tap rather than after a disk
      // write completes (§5)
      final notifier = AnnouncementsEnabledNotifier();

      // Act — deliberately not awaited
      final pending = notifier.setEnabled(false);

      // Assert
      expect(notifier.state, isFalse);
      await pending;
    });
  });

  group('the switch, in the app', () {
    late RecordingRelayBackend backend;
    late NostrService service;

    Future<ProviderContainer> pumpApp(
      WidgetTester tester, {
      bool enabled = true,
    }) async {
      final crypto = FakeNostrCrypto();
      backend = RecordingRelayBackend();
      service = NostrService(
        KeyManager(crypto: crypto),
        crypto: crypto,
        backend: backend,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nostrCryptoProvider.overrideWithValue(crypto),
            nostrServiceProvider.overrideWithValue(service),
            appVersionProvider.overrideWithValue(AppVersion.tryParse('2.0.1')!),
            // A publisher, so there is a subscription to open at all. The
            // shipped allowlist is empty on purpose (§3.1).
            announcementPublishersProvider.overrideWithValue(
              const [_publisher],
            ),
            announcementsEnabledProvider.overrideWith(
              (_) => AnnouncementsEnabledNotifier()..hydrate(enabled),
            ),
          ],
          child: const ChokeApp(),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
    }

    testWidgets('on by default, the channel is open', (tester) async {
      // Arrange + Act
      await pumpApp(tester);

      // Assert
      expect(backend.subscriptions, contains(kAnnouncementSubscriptionId));
    });

    testWidgets('off at launch opens no subscription', (tester) async {
      // Arrange + Act
      await pumpApp(tester, enabled: false);

      // Assert — off means the subscription is never opened, not that
      // arriving events are hidden (§5)
      expect(backend.subscriptions, isEmpty);
    });

    testWidgets('switching off closes the subscription at the tap',
        (tester) async {
      // Arrange — the user is still on the Settings screen afterwards, which
      // is exactly why this must not wait for a background transition
      final container = await pumpApp(tester);
      expect(backend.subscriptions, contains(kAnnouncementSubscriptionId));

      // Act
      await container
          .read(announcementsEnabledProvider.notifier)
          .setEnabled(false);
      await tester.pumpAndSettle();

      // Assert
      expect(backend.unsubscribed, contains(kAnnouncementSubscriptionId));
      expect(
        container.read(announcementInboxProvider.notifier).isOpen,
        isFalse,
      );
    });

    testWidgets('an event arriving after the tap is not processed',
        (tester) async {
      // Arrange
      final container = await pumpApp(tester);

      // Act
      await container
          .read(announcementsEnabledProvider.notifier)
          .setEnabled(false);
      await tester.pumpAndSettle();
      backend.eventsController.add(_event());
      await tester.pumpAndSettle();

      // Assert
      expect(container.read(announcementInboxProvider).entries, isEmpty);
    });

    testWidgets('switching off leaves nothing of the channel on the device',
        (tester) async {
      // Arrange
      final container = await pumpApp(tester);
      backend.eventsController.add(_event());
      await tester.pumpAndSettle();
      expect(container.read(announcementInboxProvider).entries, hasLength(1));

      // Act
      await container
          .read(announcementsEnabledProvider.notifier)
          .setEnabled(false);
      await tester.pumpAndSettle();

      // Assert
      expect(container.read(announcementInboxProvider).entries, isEmpty);
      expect((await const AnnouncementStore().load()).isEmpty, isTrue);
    });

    testWidgets('flicking it on and straight back off opens nothing',
        (tester) async {
      // Arrange — turning it on reads the cache off disk first, and the user
      // can flick the switch again while that read is in flight
      final container = await pumpApp(tester, enabled: false);
      final setting = container.read(announcementsEnabledProvider.notifier);

      // Act — both taps before anything is awaited
      final on = setting.setEnabled(true);
      final off = setting.setEnabled(false);
      await Future.wait([on, off]);
      await tester.pumpAndSettle();

      // Assert — the switch says off, so nothing may be subscribed
      expect(
        container.read(announcementInboxProvider.notifier).isOpen,
        isFalse,
      );
      backend.eventsController.add(_event());
      await tester.pumpAndSettle();
      expect(container.read(announcementInboxProvider).entries, isEmpty);
    });

    testWidgets('switching it back on resumes delivery', (tester) async {
      // Arrange
      final container = await pumpApp(tester, enabled: false);
      final setting = container.read(announcementsEnabledProvider.notifier);

      // Act
      await setting.setEnabled(true);
      await tester.pumpAndSettle();
      backend.eventsController.add(_event());
      await tester.pumpAndSettle();

      // Assert
      expect(backend.subscriptions, contains(kAnnouncementSubscriptionId));
      expect(container.read(announcementInboxProvider).entries, hasLength(1));
    });
  });
}
