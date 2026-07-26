import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:choke/services/key_management/key_manager.dart';
import 'package:choke/services/nostr/crypto/nostr_crypto.dart';
import 'package:choke/services/nostr/nostr_service.dart';

import '../../support/nostr_fakes.dart';

/// A crypto backend whose encoding operations all fail, for pinning the
/// error paths KeyManager promises: rethrow without logging key material.
class _ThrowingCrypto implements NostrCrypto {
  @override
  String generatePrivateKey() => 'f' * 64;

  @override
  String getPublicKey(String privateKeyHex) =>
      throw StateError('derive failed');

  @override
  String npubEncode(String publicKeyHex) => throw StateError('npub failed');

  @override
  String nsecEncode(String privateKeyHex) => throw StateError('nsec failed');

  @override
  String? nsecDecode(String nsec) => 'a' * 64;

  @override
  String? npubDecode(String npub) => 'a' * 64;

  @override
  NostrEvent finishEvent(UnsignedNostrEvent event, String privateKeyHex) =>
      throw UnimplementedError();

  @override
  bool verifyEvent(NostrEvent event) => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // In-memory stand-in for the platform keystore, matching the mock the
  // main KeyManager suite uses.
  late Map<String, String> storage;

  setUp(() {
    storage = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'write':
            storage[key!] = args['value'] as String;
            return null;
          case 'read':
            return storage[key];
          case 'delete':
            storage.remove(key);
            return null;
          default:
            return null;
        }
      },
    );
  });

  KeyManager subject(NostrCrypto crypto) => KeyManager(
        crypto: crypto,
        secureStorage: const FlutterSecureStorage(),
      );

  test('importFromNsec reports failure when public key derivation throws',
      () async {
    // Arrange — the nsec decodes fine, but the key underneath it is one the
    // crypto backend cannot derive a public key for
    final manager = subject(_ThrowingCrypto());

    // Act
    final imported = await manager.importFromNsec('nsec1whatever');

    // Assert — the failure is contained: false, not a crash
    expect(imported, isFalse);
  });

  test('getNpub propagates an npub encoding failure', () async {
    // Arrange — a stored public key the crypto backend refuses to encode
    storage['nostr_public_key'] = 'e' * 64;
    final manager = subject(_ThrowingCrypto());

    // Act + Assert — encoding errors are programming errors, not user input,
    // so they must surface rather than silently produce no npub
    await expectLater(manager.getNpub(), throwsStateError);
  });

  test('getNsec propagates an nsec encoding failure', () async {
    // Arrange
    storage['nostr_private_key'] = 'f' * 64;
    final manager = subject(_ThrowingCrypto());

    // Act + Assert
    await expectLater(manager.getNsec(), throwsStateError);
  });

  test('getPublicKeyForQR hands back the npub', () async {
    // Arrange — QR sharing shows the same identity the account screen does
    final manager = subject(FakeNostrCrypto());
    await manager.initialize();

    // Act
    final qrData = await manager.getPublicKeyForQR();

    // Assert
    expect(qrData, 'npub1fake');
  });

  test('keyManagerProvider refuses to build without an override', () {
    // Arrange — the provider has no sensible default: it would have to invent
    // a crypto backend the app never uses
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Act + Assert
    expect(
      () => container.read(keyManagerProvider),
      throwsUnimplementedError,
    );
  });
}
