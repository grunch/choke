import 'package:flutter/foundation.dart';

import '../../services/nostr/crypto/nostr_crypto.dart';

/// The keys allowed to publish announcements — the whole trust model (§3.1).
///
/// A list rather than a single value, and the plural is the point: a hardcoded
/// singular key that is lost or leaked kills the channel until a Play review
/// completes, which is measured in days. A list lets a successor key ship
/// *before* it is needed.
///
/// Two rules on what goes in here:
///
/// 1. **Not the maintainer's personal key.** A dedicated key, kept offline,
///    used for nothing else. If the announcement key is also the key that
///    arbitrates matches, then losing a phone loses both.
/// 2. **`npub`, never hex.** It is what a human checks against the value
///    published elsewhere, and every surface in this app speaks `npub`.
///    Decoding happens in the crate (AGENTS.md), never in Dart.
///
/// Empty on purpose: the dedicated offline key does not exist yet, and an
/// empty allowlist is inert by construction — no authors means no
/// subscription, so shipping this cannot open a channel nobody can speak on.
/// Adding the real key is a one-line change here.
const List<String> kAnnouncementPublishers = <String>[];

/// The hex keys a subscription filter needs, from the npubs in [npubs].
///
/// An entry that fails to decode is dropped with a [debugPrint] and the rest
/// still work: a typo in one constant must not silence the channel (§3.1).
///
/// Duplicates are collapsed, so an npub listed twice — or a successor key that
/// turns out to be the same key — never makes a filter name one author twice.
List<String> decodeAnnouncementPublishers(
  NostrCrypto crypto, {
  List<String> npubs = kAnnouncementPublishers,
}) {
  final hex = <String>{};
  for (final npub in npubs) {
    final decoded = crypto.npubDecode(npub);
    if (decoded == null) {
      // Safe to log: this is a public key, and a wrong one at that.
      debugPrint('Announcements: dropping undecodable publisher "$npub"');
      continue;
    }
    hex.add(decoded);
  }
  return List.unmodifiable(hex);
}
