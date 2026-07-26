import '../../../src/rust/api/crypto.dart' as rust;
import '../nostr_service.dart' show NostrEvent;
import 'nostr_crypto.dart';

/// [NostrCrypto] backed by the Rust `nostr` crate, reached over
/// flutter_rust_bridge.
///
/// Requires `RustLib` to have been initialized first — `main.dart` does that
/// when the Rust backend is selected. Every call is synchronous: these are
/// microsecond-scale operations, so hopping to a worker isolate would cost
/// more than it saves.
///
/// See docs/specs/nostr-sdk-migration.md.
class RustNostrCrypto implements NostrCrypto {
  const RustNostrCrypto();

  @override
  String generatePrivateKey() => rust.generateSecretKey();

  @override
  String getPublicKey(String privateKeyHex) =>
      rust.publicKeyFromSecret(secretHex: privateKeyHex);

  @override
  String npubEncode(String publicKeyHex) =>
      rust.npubEncode(publicKeyHex: publicKeyHex);

  @override
  String nsecEncode(String privateKeyHex) =>
      rust.nsecEncode(secretHex: privateKeyHex);

  @override
  String? nsecDecode(String nsec) => rust.nsecDecode(nsec: nsec);

  @override
  String? npubDecode(String npub) => rust.npubDecode(npub: npub);

  @override
  NostrEvent finishEvent(UnsignedNostrEvent event, String privateKeyHex) {
    final signed = rust.finishEvent(
      event: rust.UnsignedEventData(
        pubkey: event.pubkey,
        createdAt: event.createdAt,
        kind: event.kind,
        tags: event.tags,
        content: event.content,
      ),
      secretHex: privateKeyHex,
    );

    return NostrEvent(
      id: signed.id,
      pubkey: signed.pubkey,
      createdAt: signed.createdAt,
      kind: signed.kind,
      tags: signed.tags,
      content: signed.content,
      sig: signed.sig,
    );
  }

  @override
  bool verifyEvent(NostrEvent event) {
    return rust.verifyEventData(
      event: rust.SignedEventData(
        id: event.id,
        pubkey: event.pubkey,
        createdAt: event.createdAt,
        kind: event.kind,
        tags: event.tags,
        content: event.content,
        sig: event.sig,
      ),
    );
  }
}
