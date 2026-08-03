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
/// The three keys below are trusted equally: any one of them can put an
/// announcement in front of every user who has the channel on, and none of them
/// can be revoked without shipping a build. That is the cost of a hardcoded
/// allowlist, and it is deliberate — a list that could be updated over the wire
/// would be a channel for taking over the channel.
///
/// Successors ship *before* they are needed, which is the whole reason this is
/// a list. A key that turns out to be lost or leaked is simply dropped here in
/// the next release; the others keep working in the meantime, and the channel
/// never goes dark waiting on a store review.
const List<String> kAnnouncementPublishers = <String>[
  // c5df6c89ab5bd2728528e800412a713673195ab6f4bd71bb780fe9cec4adecc1
  'npub1ch0kezdtt0f89pfgaqqyz2n3xee3jk4k7j7hrwmcpl5ua39danqsrs9y9t',
  // afb8fe8d6825e9290da89267bbfe828f6a2196aa528fc7af899f4e06202ab077
  'npub147u0artgyh5jjrdgjfnmhl5z3a4zr942228u0tufna8qvgp2kpms7ch0ke',
  // c5df6014c19fdda51a52c0d0406135d687d968bfe19a700468e00a15d757e946
  'npub1ch0kq9xpnlw62xjjcrgyqcf466raj69luxd8qprguq9pt46ha9rqyf6a6u',
];

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
