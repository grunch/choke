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
import 'package:choke/features/home/home_screen.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'package:choke/l10n/generated/app_localizations_en.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/shared/theme/app_theme.dart';

import '../../support/nostr_fakes.dart';

const String _publisher = 'aa11';

NostrEvent _event({String id = 'e1', String d = 'release-2-1'}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return NostrEvent(
    id: id,
    pubkey: _publisher,
    createdAt: now - 60,
    kind: kAnnouncementKind,
    tags: [
      ['d', d],
      ['expiration', '${now + 8640000}'],
    ],
    content: jsonEncode({
      'v': kAnnouncementSchemaVersion,
      'locales': {
        for (final code in kAnnouncementLocales)
          code: {'title': 'Version 2.1 is out', 'body': 'Body'},
      },
    }),
    sig: 'f' * 128,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingRelayBackend backend;
  late AnnouncementInbox inbox;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// The home screen, over a live announcement channel.
  ///
  /// Built inside the test body rather than in `setUp`: a broadcast stream
  /// created in another zone delivers on that zone's microtask queue, which
  /// `pumpAndSettle` never flushes.
  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final crypto = FakeNostrCrypto();
    backend = RecordingRelayBackend();
    final service = NostrService(
      KeyManager(crypto: crypto),
      crypto: crypto,
      backend: backend,
    );
    addTearDown(service.dispose);
    inbox = AnnouncementInbox(
      service: service,
      crypto: crypto,
      appVersion: AppVersion.tryParse('2.0.1')!,
      publishers: const [_publisher],
    )..open();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nostrServiceProvider.overrideWithValue(service),
          announcementInboxProvider.overrideWith((_) => inbox),
          npubProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> deliver(WidgetTester tester, NostrEvent event) async {
    backend.eventsController.add(event);
    await tester.pumpAndSettle();
  }

  testWidgets('there is no bell until the project has said something',
      (tester) async {
    // Arrange + Act — a permanent bell is chrome advertising that a channel
    // exists, which this feature has not earned (§4.3)
    await pumpHome(tester);

    // Assert
    expect(find.byIcon(Icons.notifications_none), findsNothing);
  });

  testWidgets('an unread announcement puts a bell in the bar', (tester) async {
    // Arrange
    await pumpHome(tester);

    // Act
    await deliver(tester, _event());

    // Assert
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    expect(inbox.state.hasUnread, isTrue);
  });

  testWidgets('the dot says "unread" to a screen reader too', (tester) async {
    // Arrange — the tooltip says what the bell opens; nothing else says there
    // is something unread behind it, and a coloured circle says it to exactly
    // one kind of user
    final handle = tester.ensureSemantics();
    await pumpHome(tester);
    await deliver(tester, _event());

    // Assert
    expect(
      find.bySemanticsLabel(RegExp(AppLocalizationsEn().announcementsUnread)),
      findsAtLeastNWidgets(1),
    );

    // Act
    await inbox.markRead(inbox.state.entries.single.address);
    await tester.pumpAndSettle();

    // Assert — and it goes with the state it describes
    expect(
      find.bySemanticsLabel(RegExp(AppLocalizationsEn().announcementsUnread)),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('the dot goes away once everything has been read',
      (tester) async {
    // Arrange
    await pumpHome(tester);
    await deliver(tester, _event());
    final withDot = tester.widgetList(find.byType(Positioned)).length;

    // Act
    await inbox.markRead(inbox.state.entries.single.address);
    await tester.pumpAndSettle();

    // Assert — the bell stays, the dot does not
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    expect(inbox.state.hasUnread, isFalse);
    expect(
      tester.widgetList(find.byType(Positioned)).length,
      lessThan(withDot),
      reason: 'the dot is the only Positioned the bell adds',
    );
  });

  testWidgets('tapping the bell opens the announcements screen',
      (tester) async {
    // Arrange
    await pumpHome(tester);
    await deliver(tester, _event());

    // Act
    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(AnnouncementsScreen), findsOneWidget);
    expect(find.text('Version 2.1 is out'), findsOneWidget);
  });

  testWidgets('dismissing the last announcement takes the bell with it',
      (tester) async {
    // Arrange
    await pumpHome(tester);
    await deliver(tester, _event());

    // Act
    await inbox.dismiss(inbox.state.entries.single.address);
    await tester.pumpAndSettle();

    // Assert
    expect(find.byIcon(Icons.notifications_none), findsNothing);
  });
}
