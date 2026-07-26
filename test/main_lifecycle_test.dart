
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:choke/main.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/crypto/nostr_crypto.dart';
import 'package:flutter/material.dart';
import 'package:choke/services/nostr/nostr_service.dart';
import 'package:choke/shared/providers/navigation_provider.dart';

import 'support/nostr_fakes.dart';

/// A NostrService that only counts how often the app asks it to recycle its
/// relay connections.
class _ReconnectSpyService extends NostrService {
  _ReconnectSpyService()
      : super(
          KeyManager(crypto: FakeNostrCrypto()),
          crypto: FakeNostrCrypto(),
          backend: FakeRelayBackend(),
        );

  int reconnectCalls = 0;

  @override
  Future<void> reconnectAll() async {
    reconnectCalls++;
  }
}

void main() {
  late _ReconnectSpyService service;

  setUp(() {
    service = _ReconnectSpyService();
  });

  tearDown(() => service.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    final crypto = FakeNostrCrypto();
    final keyManager = KeyManager(crypto: crypto);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nostrCryptoProvider.overrideWithValue(crypto),
          keyManagerProvider.overrideWithValue(keyManager),
          nostrServiceProvider.overrideWithValue(service),
        ],
        child: const ChokeApp(),
      ),
    );
  }

  /// Drive a lifecycle sequence the way the OS actually does.
  ///
  /// The states are a path, not a set: Android and iOS walk resumed → inactive →
  /// hidden → paused on the way out and back again on the way in, and Flutter's
  /// own AppLifecycleListener asserts on any jump that skips a step. Sending
  /// paused → resumed directly is a transition no device performs, and any
  /// widget in the tree that listens for lifecycle changes — a TextField, for
  /// one — will rightly complain about it.
  Future<void> walk(
    WidgetTester tester,
    List<AppLifecycleState> states,
  ) async {
    for (final state in states) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
  }

  /// Away and back, in full.
  const goingAway = [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ];
  const comingBack = [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ];

  testWidgets('recycles every relay connection when the app resumes',
      (tester) async {
    // Arrange — backgrounding kills sockets without a close frame, so resume
    // must not trust any connection that looks open
    await pumpApp(tester);
    await walk(tester, goingAway);
    expect(service.reconnectCalls, 0);

    // Act
    await walk(tester, comingBack);

    // Assert
    expect(service.reconnectCalls, 1);
  });

  testWidgets('leaves connections alone on every other lifecycle change',
      (tester) async {
    // Arrange
    await pumpApp(tester);

    // Act — every transition short of resuming
    await walk(tester, goingAway);

    // Assert — recycling sockets mid-use would drop live subscriptions
    expect(service.reconnectCalls, 0);

    // Restore the default state so later tests see a live app
    await walk(tester, comingBack);
  });

  testWidgets('the app hands its navigator to the provider that pops it',
      (tester) async {
    // The whole shared-link stack clearing rests on one line in main.dart. A
    // test that builds its own MaterialApp and passes the key it also overrode
    // proves popUntil works — and stays green if that line is deleted, which is
    // the same silent failure shape as the bug it fixes.
    //
    // Arrange + Act
    await pumpApp(tester);

    // Assert — the key the app is actually using is the one the provider hands
    // out, so code outside the tree can reach this navigator
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    expect(container.read(navigatorKeyProvider).currentState, isNotNull);
  });
}
