import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/scoreboard/providers/scoreboard_providers.dart';
import '../../shared/providers/navigation_provider.dart';
import '../nostr/crypto/nostr_crypto.dart';

/// The host whose links this app answers for.
///
/// Must match the `android:host` in the App Links intent filter and the
/// `applinks:` entry in the iOS entitlement. A link for any other host belongs
/// to somebody else, and is ignored rather than guessed at.
const String kShareLinkHost = 'bjjscore.live';

/// The query parameters a shared board link may carry the pubkey in.
///
/// Both, and in this order, because choke-scoreboard has always accepted both
/// (`SHARE_PUBKEY_PARAMS` in its `share-link.ts`) and one URL is shared to
/// everyone: whichever of the two the recipient opens it in has to understand
/// it.
const List<String> kSharePubkeyParams = ['npub', 'pubkey'];

/// The pubkey a shared board link names, in hex, or null if it names none.
///
/// Accepts exactly what the web board accepts: `https://bjjscore.live/?npub=…`
/// or `?pubkey=…`, holding either an npub or bare hex.
///
/// Returns null rather than throwing for anything else, a link for another host
/// included. What arrives here is whatever the OS was handed, which is not a
/// trusted caller.
String? pubkeyFromShareLink(Uri uri, NostrCrypto crypto) {
  // A relative route has no authority to check; an absolute one must be ours.
  if (uri.hasAuthority && uri.host.toLowerCase() != kShareLinkHost) return null;

  for (final param in kSharePubkeyParams) {
    final value = uri.queryParameters[param]?.trim();
    if (value == null || value.isEmpty) continue;

    final hex = parsePubkey(value, crypto);
    if (hex != null) return hex;
  }

  return null;
}

/// Open a shared board link: watch the pubkey it names, and show the scoreboard.
///
/// Returns whether the link was one this app understands. One that names no
/// usable pubkey changes nothing — dropping the user on an empty scoreboard,
/// having silently forgotten the pubkey they were already watching, would be
/// worse than ignoring a link that made no sense.
bool openShareLink(Uri uri, NostrCrypto crypto, WidgetRef ref) {
  final hex = pubkeyFromShareLink(uri, crypto);
  if (hex == null) {
    // The host and which parameters were present, never their values. A user
    // who pastes their nsec into one of these is correctly rejected above —
    // and must not have it written to the device log on the way out.
    final named = kSharePubkeyParams
        .where(uri.queryParameters.containsKey)
        .join(',');
    debugPrint(
      'DeepLink: ignoring a link for ${uri.host.isEmpty ? '(no host)' : uri.host}'
      '${named.isEmpty ? ' with no pubkey parameter' : ' whose $named did not parse'}',
    );
    return false;
  }

  // Clear the stack first, then switch. A detail screen left on top would
  // otherwise hide the board the link just opened — and, for a different
  // organizer, would find its match missing and show "no longer available"
  // instead. Popping after the switch would let it render once against the new
  // organizer and flash exactly that.
  ref.read(navigatorKeyProvider).currentState?.popUntil((r) => r.isFirst);

  ref.read(watchedPubkeyProvider.notifier).watch(hex);
  ref.read(selectedTabProvider.notifier).state = AppTab.scoreboard;
  return true;
}
