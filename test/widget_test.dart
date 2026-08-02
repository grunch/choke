import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:choke/features/announcements/announcement_providers.dart';
import 'package:choke/features/announcements/models/app_version.dart';
import 'package:choke/main.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/crypto/nostr_crypto.dart';
import 'package:choke/services/nostr/nostr_service.dart';

import 'support/nostr_fakes.dart';

/// The app's providers no longer invent a default Nostr stack — a default
/// would have to name an implementation, and naming one twice is what the
/// interfaces exist to prevent. A widget test says what it wants instead.
List<Override> _fakeNostrStack() {
  final crypto = FakeNostrCrypto();
  final keyManager = KeyManager(crypto: crypto);
  return [
    nostrCryptoProvider.overrideWithValue(crypto),
    keyManagerProvider.overrideWithValue(keyManager),
    nostrServiceProvider.overrideWithValue(
      NostrService(keyManager, crypto: crypto, backend: FakeRelayBackend()),
    ),
    // The announcement channel targets by app version, which is a plugin read
    // in main() and not something a widget test has. Any version will do here:
    // the allowlist these tests run with is empty, so nothing is subscribed to
    // and nothing is targeted.
    appVersionProvider.overrideWithValue(AppVersion.tryParse('2.0.1')!),
  ];
}

void main() {
  testWidgets('App loads with bottom navigation', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(overrides: _fakeNostrStack(), child: const ChokeApp()),
    );

    // Verify that bottom navigation items exist.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify app title in header.
    expect(find.text('Choke'), findsOneWidget);

    // The Match tab is gone, and must stay gone. It could only ever tell you to
    // go somewhere else — a nav item that costs a tap and returns nothing is
    // worse than a missing feature, because a missing feature promises nothing.
    expect(find.text('Match'), findsNothing);
  });

  testWidgets('Can navigate to different tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _fakeNostrStack(), child: const ChokeApp()),
    );

    // Tap on Account tab.
    await tester.tap(find.text('Account'));
    await tester.pump();

    // Verify Account screen content.
    expect(find.text('Account'), findsWidgets);
  });
}
