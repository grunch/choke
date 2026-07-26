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

/// What a link turned out to be.
///
/// Three cases, not two. "This is not a share link" and "this is a share link
/// whose pubkey is broken" both used to come back as null, and treating them
/// alike is what left the previous organizer's board on screen as though it
/// were the one the link named.
sealed class ShareLink {
  const ShareLink();
}

/// Not a shared board link: another host, or no pubkey parameter at all.
///
/// Includes the plain launch route, which is the case that fires every time the
/// app opens normally. Nothing should happen, silently.
class NotAShareLink extends ShareLink {
  const NotAShareLink();
}

/// A shared board link naming [pubkeyHex].
class SharedBoard extends ShareLink {
  const SharedBoard(this.pubkeyHex);

  /// The watched author, in lowercase hex.
  final String pubkeyHex;
}

/// A shared board link whose pubkey could not be read.
///
/// The user followed a link meant for one particular board. Showing them any
/// other board now is a lie they have no way to catch, so this has to be said
/// out loud rather than absorbed.
class BrokenShareLink extends ShareLink {
  const BrokenShareLink();
}

/// Read a link the OS handed over.
///
/// Accepts exactly what the web board accepts: `https://bjjscore.live/?npub=…`
/// or `?pubkey=…`, holding either an npub or bare hex.
///
/// Never throws. What arrives here is whatever was tapped, which is not a
/// trusted caller.
ShareLink readShareLink(Uri uri, NostrCrypto crypto) {
  // The host has to be ours, and a URI with no authority does not have one to
  // check — `/?npub=…` and `bjjscore.live/?npub=…` (no scheme) both parse with
  // an empty host. Letting those through used to be harmless, because an
  // unreadable pubkey simply did nothing; now it puts an accusing full-screen
  // message in front of somebody over a link they never followed.
  if (uri.host.toLowerCase() != kShareLinkHost) {
    return const NotAShareLink();
  }

  var sawParameter = false;

  for (final param in kSharePubkeyParams) {
    final value = uri.queryParameters[param]?.trim();

    // An empty value is not a broken key, it is no key — the web board skips it
    // the same way, and a bare `?npub=` should not accuse anybody of anything.
    if (value == null || value.isEmpty) continue;

    sawParameter = true;
    final hex = parsePubkey(value, crypto);
    if (hex != null) return SharedBoard(hex);
  }

  return sawParameter ? const BrokenShareLink() : const NotAShareLink();
}

/// Set when a link named a board and its pubkey could not be read.
///
/// The scoreboard shows this instead of a board. The app does not clear it on
/// its own: only the user can say "fine, show me what I had", because only they
/// know they did not get what they tapped.
final brokenShareLinkProvider = StateProvider<bool>((ref) => false);

/// Open a shared board link.
///
/// Returns whether the link was one this app answers for — true both for a
/// board it opened and for a broken one it reported, since both are ours.
bool openShareLink(Uri uri, NostrCrypto crypto, WidgetRef ref) {
  switch (readShareLink(uri, crypto)) {
    case NotAShareLink():
      // Nothing to say. This is also the ordinary launch route, and an app that
      // complained about that would complain every time it opened.
      _log(uri, 'ignoring');
      return false;

    case SharedBoard(:final pubkeyHex):
      ref.read(brokenShareLinkProvider.notifier).state = false;
      ref.read(watchedPubkeyProvider.notifier).watch(pubkeyHex);
      ref.read(selectedTabProvider.notifier).state = AppTab.scoreboard;
      return true;

    case BrokenShareLink():
      // Fail closed. The previously watched pubkey is kept — it is theirs, and
      // throwing it away would punish them for somebody else's bad link — but
      // the board stays behind the message until they choose to go back to it.
      // What must not happen is that board appearing as though the link worked.
      _log(uri, 'reporting as broken');
      ref.read(brokenShareLinkProvider.notifier).state = true;
      ref.read(selectedTabProvider.notifier).state = AppTab.scoreboard;
      return true;
  }
}

/// The host and which parameters were present, never their values.
///
/// A user who pastes their nsec into one of these is correctly rejected by the
/// parser — and must not have it written to the device log on the way out.
///
/// [what] names the decision, because "ignoring" and "showing the user an
/// error" read identically in a support report otherwise.
void _log(Uri uri, String what) {
  final named =
      kSharePubkeyParams.where(uri.queryParameters.containsKey).join(',');
  debugPrint(
    'DeepLink: $what a link for ${uri.host.isEmpty ? '(no host)' : uri.host}'
    '${named.isEmpty ? ' with no pubkey parameter' : ' whose $named did not parse'}',
  );
}
