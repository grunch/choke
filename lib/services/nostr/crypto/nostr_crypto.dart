import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nostr_service.dart' show NostrEvent;

/// A Nostr event that has been assembled but not yet signed: it has no id
/// and no signature, because both are derived from these fields.
class UnsignedNostrEvent {
  final String pubkey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;

  const UnsignedNostrEvent({
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
  });
}

/// Every cryptographic operation the app performs.
///
/// This is the seam the migration turns on: the app talks to this interface,
/// never to a crypto library directly, so the implementation underneath can
/// be swapped (Dart `nostr_tools` → Rust `nostr`) without a single call site
/// changing. See docs/specs/nostr-sdk-migration.md.
///
/// Implementations must be interchangeable: the same private key always
/// yields the same public key, npub and nsec, and the same unsigned event
/// always yields the same event id. Only signatures may differ between
/// implementations (Schnorr signing uses a random nonce), and each must
/// verify the other's. `nostr_crypto_contract.dart` pins all of this.
abstract class NostrCrypto {
  /// A fresh, valid secp256k1 private key, as lowercase hex.
  String generatePrivateKey();

  /// The public key belonging to [privateKeyHex], as lowercase hex.
  String getPublicKey(String privateKeyHex);

  /// NIP-19 bech32 encoding of a hex public key (`npub1…`).
  String npubEncode(String publicKeyHex);

  /// NIP-19 bech32 encoding of a hex private key (`nsec1…`).
  String nsecEncode(String privateKeyHex);

  /// The hex private key inside [nsec], or null if it is not a valid nsec.
  ///
  /// Returns null rather than throwing: a malformed nsec is something a user
  /// can type, not a programming error.
  String? nsecDecode(String nsec);

  /// The hex public key inside [npub], or null if it is not a valid npub.
  ///
  /// Null rather than throwing, for the same reason as [nsecDecode]: an npub is
  /// something a user pastes.
  ///
  /// Strictly bech32. A bare hex key is not accepted, because the two forms
  /// cannot be told apart once mixed — any 64 hex characters parse as a public
  /// key, a private one included. Callers that accept either form must decide
  /// which they were handed before calling this.
  String? npubDecode(String npub);

  /// Compute [event]'s id and sign it with [privateKeyHex].
  NostrEvent finishEvent(UnsignedNostrEvent event, String privateKeyHex);

  /// Whether [event]'s id matches its contents and its signature is valid.
  bool verifyEvent(NostrEvent event);
}

/// The crypto implementation the app runs on.
///
/// Overridden in `main.dart` with the selected backend. Phase 2 ships only
/// the legacy Dart implementation; Phase 3 adds the Rust one behind a flag.
final nostrCryptoProvider = Provider<NostrCrypto>((ref) {
  throw UnimplementedError(
    'nostrCryptoProvider must be overridden with a NostrCrypto implementation',
  );
});
