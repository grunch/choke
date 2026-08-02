import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/announcements/announcement_publishers.dart';

import '../../support/nostr_fakes.dart';

/// Decodes exactly the npubs a test names, and nothing else.
///
/// Decoding is bech32 and bech32 lives in the crate (AGENTS.md), so the unit
/// under test is *which* entries survive, never the decoding itself — that is
/// pinned by the crypto contract tests.
class _StubCrypto extends FakeNostrCrypto {
  _StubCrypto(this.table);

  final Map<String, String> table;

  @override
  String? npubDecode(String npub) => table[npub];
}

void main() {
  group('decodeAnnouncementPublishers', () {
    test('maps each allowlisted npub to the hex a filter needs', () {
      // Arrange
      final crypto = _StubCrypto({
        'npub1first': 'aa' * 32,
        'npub1second': 'bb' * 32,
      });

      // Act
      final hex = decodeAnnouncementPublishers(
        crypto,
        npubs: const ['npub1first', 'npub1second'],
      );

      // Assert
      expect(hex, ['aa' * 32, 'bb' * 32]);
    });

    test('drops an entry that fails to decode and keeps the rest', () {
      // Arrange — a typo in one constant must not silence the channel (§3.1)
      final crypto = _StubCrypto({'npub1good': 'aa' * 32});

      // Act
      final hex = decodeAnnouncementPublishers(
        crypto,
        npubs: const ['npub1typo', 'npub1good'],
      );

      // Assert
      expect(hex, ['aa' * 32]);
    });

    test('returns nothing when no entry decodes', () {
      // Arrange
      final crypto = _StubCrypto(const {});

      // Act
      final hex = decodeAnnouncementPublishers(
        crypto,
        npubs: const ['npub1typo'],
      );

      // Assert — the caller opens no subscription rather than an unfiltered one
      expect(hex, isEmpty);
    });

    test('returns nothing for an empty allowlist', () {
      // Arrange
      final crypto = _StubCrypto({'npub1first': 'aa' * 32});

      // Act
      final hex = decodeAnnouncementPublishers(crypto, npubs: const []);

      // Assert
      expect(hex, isEmpty);
    });

    test('drops duplicates so a filter never names one author twice', () {
      // Arrange — the same key reachable under two entries
      final crypto = _StubCrypto({
        'npub1first': 'aa' * 32,
        'npub1firstAgain': 'aa' * 32,
      });

      // Act
      final hex = decodeAnnouncementPublishers(
        crypto,
        npubs: const ['npub1first', 'npub1firstAgain'],
      );

      // Assert
      expect(hex, ['aa' * 32]);
    });
  });

  group('the shipped allowlist', () {
    test('holds npubs, never hex', () {
      // Assert — the constant is what a human checks against the value
      // published elsewhere, and the app's surfaces speak npub (§3.1)
      for (final entry in kAnnouncementPublishers) {
        expect(entry, startsWith('npub1'));
      }
    });

    test('is empty until a dedicated offline key exists', () {
      // Assert — an empty allowlist is inert by construction: nothing to
      // decode means no authors, and §4.1 opens no subscription without them.
      // Delete this test in the commit that adds the real key.
      expect(kAnnouncementPublishers, isEmpty);
    });
  });
}
