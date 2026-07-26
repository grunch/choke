import 'package:flutter_test/flutter_test.dart';
import 'package:choke/services/nostr/crypto/nostr_crypto.dart';
import 'package:choke/services/nostr/nostr_service.dart';

/// The behavior every [NostrCrypto] implementation must exhibit, written once
/// against the interface.
///
/// This is what makes the migration safe: the Rust implementation (Phase 3)
/// is held to this same suite without editing a line of it, so "the new
/// backend behaves like the old one" stops being a claim and becomes a test
/// result. See docs/specs/nostr-sdk-migration.md (I7, I8).
void runNostrCryptoContract(String name, NostrCrypto Function() create) {
  group('$name — NostrCrypto contract', () {
    late NostrCrypto crypto;

    setUp(() => crypto = create());

    // The NIP-19 test vector published in the NIP itself. An implementation
    // that disagrees with this disagrees with the protocol.
    const nip19PrivateKey =
        '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';
    const nip19Nsec =
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

    group('keys', () {
      test('generates a usable 32-byte private key', () {
        // Act
        final privateKey = crypto.generatePrivateKey();

        // Assert — 32 bytes of lowercase hex, and a key the rest of the API
        // actually accepts
        expect(privateKey, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(crypto.getPublicKey(privateKey), hasLength(64));
      });

      test('generates a different key every time', () {
        // Arrange & Act — a generator that repeated itself would hand two
        // referees the same identity
        final keys = List.generate(10, (_) => crypto.generatePrivateKey());

        // Assert
        expect(keys.toSet(), hasLength(10));
      });

      test('derives the same public key from the same private key', () {
        // Arrange
        final privateKey = crypto.generatePrivateKey();

        // Act
        final first = crypto.getPublicKey(privateKey);
        final second = crypto.getPublicKey(privateKey);

        // Assert — the user's identity must not drift between calls
        expect(first, second);
        expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
      });

      test('derives different public keys from different private keys', () {
        // Arrange & Act
        final a = crypto.getPublicKey(crypto.generatePrivateKey());
        final b = crypto.getPublicKey(crypto.generatePrivateKey());

        // Assert
        expect(a, isNot(b));
      });
    });

    group('NIP-19', () {
      test('encodes the NIP-19 spec vector to its published nsec', () {
        // Act
        final nsec = crypto.nsecEncode(nip19PrivateKey);

        // Assert
        expect(nsec, nip19Nsec);
      });

      test('decodes the NIP-19 spec vector back to its hex key', () {
        // Act
        final hex = crypto.nsecDecode(nip19Nsec);

        // Assert
        expect(hex, nip19PrivateKey);
      });

      test('round-trips a generated key through nsec', () {
        // Arrange
        final privateKey = crypto.generatePrivateKey();

        // Act
        final decoded = crypto.nsecDecode(crypto.nsecEncode(privateKey));

        // Assert
        expect(decoded, privateKey);
      });

      test('encodes a public key as an npub', () {
        // Arrange
        final publicKey = crypto.getPublicKey(nip19PrivateKey);

        // Act
        final npub = crypto.npubEncode(publicKey);

        // Assert
        expect(npub, startsWith('npub1'));
      });

      test('gives the same npub for the same key every time', () {
        // Arrange — the npub is the user's public identity; it cannot wobble
        final publicKey = crypto.getPublicKey(nip19PrivateKey);

        // Act & Assert
        expect(crypto.npubEncode(publicKey), crypto.npubEncode(publicKey));
      });

      test('returns null for an nsec that is not one', () {
        // Act & Assert — a user can type any of these into the import field
        expect(crypto.nsecDecode('not an nsec'), isNull);
        expect(crypto.nsecDecode(''), isNull);
        expect(crypto.nsecDecode(nip19PrivateKey), isNull, reason: 'raw hex');
      });

      test('returns null for an npub given where an nsec is expected', () {
        // Arrange — same bech32 family, wrong prefix: decoding this as a
        // private key would be a catastrophic confusion
        final npub = crypto.npubEncode(crypto.getPublicKey(nip19PrivateKey));

        // Act & Assert
        expect(crypto.nsecDecode(npub), isNull);
      });

      test('round-trips a public key through npub', () {
        // Arrange — this is the form a pubkey arrives in when somebody shares it
        final publicKey = crypto.getPublicKey(nip19PrivateKey);

        // Act
        final decoded = crypto.npubDecode(crypto.npubEncode(publicKey));

        // Assert
        expect(decoded, publicKey);
      });

      test('returns null for an npub that is not one', () {
        // Act & Assert — anything a user can paste into a pubkey field
        expect(crypto.npubDecode('not an npub'), isNull);
        expect(crypto.npubDecode(''), isNull);
        expect(
          crypto.npubDecode(crypto.getPublicKey(nip19PrivateKey)),
          isNull,
          reason: 'raw hex is not bech32; the caller decides which one it has',
        );
      });

      test('returns null for an nsec given where an npub is expected', () {
        // The mirror of the test above, and the one that matters more: a private
        // key must never pass as somebody's public identity. A user who pasted
        // the wrong thing would otherwise have it sent to the relays as an
        // author filter, and never be told.
        expect(crypto.npubDecode(nip19Nsec), isNull);
      });
    });

    group('signing', () {
      UnsignedNostrEvent unsigned(String pubkey, {String content = 'choke'}) {
        return UnsignedNostrEvent(
          pubkey: pubkey,
          createdAt: 1700000000,
          kind: 31415,
          tags: const [
            ['d', 'abcd'],
            ['expiration', '1900000000'],
          ],
          content: content,
        );
      }

      test('produces an event that verifies', () {
        // Arrange
        final privateKey = crypto.generatePrivateKey();
        final publicKey = crypto.getPublicKey(privateKey);

        // Act
        final event = crypto.finishEvent(unsigned(publicKey), privateKey);

        // Assert
        expect(crypto.verifyEvent(event), isTrue);
      });

      test('preserves every field it was given', () {
        // Arrange
        final privateKey = crypto.generatePrivateKey();
        final publicKey = crypto.getPublicKey(privateKey);
        final input = unsigned(publicKey);

        // Act
        final event = crypto.finishEvent(input, privateKey);

        // Assert — a signer that quietly reordered tags or rewrote created_at
        // would break the match schema and NIP-01 replacement alike
        expect(event.pubkey, input.pubkey);
        expect(event.createdAt, input.createdAt);
        expect(event.kind, input.kind);
        expect(event.tags, input.tags);
        expect(event.content, input.content);
      });

      test('fills in a well-formed id and signature', () {
        // Arrange
        final privateKey = crypto.generatePrivateKey();
        final publicKey = crypto.getPublicKey(privateKey);

        // Act
        final event = crypto.finishEvent(unsigned(publicKey), privateKey);

        // Assert
        expect(event.id, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(event.sig, matches(RegExp(r'^[0-9a-f]{128}$')));
      });

      test('derives the id from the event, not from chance', () {
        // Arrange — the id is a hash of the event's fields, so signing the
        // same event twice must produce the same id (NIP-01). This is what
        // lets Phase 3 compare the two implementations byte for byte.
        final privateKey = crypto.generatePrivateKey();
        final publicKey = crypto.getPublicKey(privateKey);
        final input = unsigned(publicKey);

        // Act
        final first = crypto.finishEvent(input, privateKey);
        final second = crypto.finishEvent(input, privateKey);

        // Assert
        expect(first.id, second.id);
      });

      test('gives different content a different id', () {
        // Arrange
        final privateKey = crypto.generatePrivateKey();
        final publicKey = crypto.getPublicKey(privateKey);

        // Act
        final a = crypto.finishEvent(unsigned(publicKey), privateKey);
        final b = crypto.finishEvent(
          unsigned(publicKey, content: 'choked'),
          privateKey,
        );

        // Assert
        expect(a.id, isNot(b.id));
      });

      test('signs content that is not plain ASCII', () {
        // Arrange — fighter names carry accents and the app is localized into
        // Japanese; a signer that mangled UTF-8 would emit events every relay
        // rejects. Quotes and newlines probe JSON escaping too.
        final privateKey = crypto.generatePrivateKey();
        final publicKey = crypto.getPublicKey(privateKey);
        final input = unsigned(
          publicKey,
          content:
              '{"f1":"Gonçalves 🥋","f2":"田中","n":"a \\"quote\\"\nnewline"}',
        );

        // Act
        final event = crypto.finishEvent(input, privateKey);

        // Assert
        expect(crypto.verifyEvent(event), isTrue);
        expect(event.content, input.content);
      });
    });

    group('verification', () {
      test('rejects an event whose content was changed after signing', () {
        // Arrange
        final privateKey = crypto.generatePrivateKey();
        final publicKey = crypto.getPublicKey(privateKey);
        final event = crypto.finishEvent(
          UnsignedNostrEvent(
            pubkey: publicKey,
            createdAt: 1700000000,
            kind: 31415,
            tags: const [
              ['d', 'abcd']
            ],
            content: 'f1 wins',
          ),
          privateKey,
        );

        // Act — someone rewrites the result, keeping the original signature
        final forged = NostrEvent(
          id: event.id,
          pubkey: event.pubkey,
          createdAt: event.createdAt,
          kind: event.kind,
          tags: event.tags,
          content: 'f2 wins',
          sig: event.sig,
        );

        // Assert
        expect(crypto.verifyEvent(forged), isFalse);
      });

      test('rejects an event signed by someone else', () {
        // Arrange — two referees; one's signature is pasted onto an event
        // claiming to come from the other
        final keyA = crypto.generatePrivateKey();
        final keyB = crypto.generatePrivateKey();
        final pubA = crypto.getPublicKey(keyA);
        final pubB = crypto.getPublicKey(keyB);

        final byA = crypto.finishEvent(
          UnsignedNostrEvent(
            pubkey: pubA,
            createdAt: 1700000000,
            kind: 31415,
            tags: const [
              ['d', 'abcd']
            ],
            content: 'choke',
          ),
          keyA,
        );

        // Act
        final impersonated = NostrEvent(
          id: byA.id,
          pubkey: pubB,
          createdAt: byA.createdAt,
          kind: byA.kind,
          tags: byA.tags,
          content: byA.content,
          sig: byA.sig,
        );

        // Assert
        expect(crypto.verifyEvent(impersonated), isFalse);
      });
    });
  });
}
