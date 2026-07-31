import 'package:flutter/widgets.dart';
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

/// Base of the public live board.
///
/// Built from [kShareLinkHost] rather than written out again: the host this app
/// answers for and the host it hands out have to be the same one, and two
/// literals are two things to forget to change together.
const String kLiveBoardBaseUrl = 'https://$kShareLinkHost';

/// Build the share link for an organizer's npub.
///
/// A shared link carries the npub in the query string (`?npub=…`), so opening
/// it drops the spectator straight onto that board with nothing to paste — in
/// the app if they have it, on the web board if they do not. Must match the
/// reader in choke-scoreboard (`buildShareLink` / `readSharedPubkey`).
String liveBoardShareUrl(String npub) => '$kLiveBoardBaseUrl/?npub=$npub';

/// Build the share link for one match on an organizer's board.
///
/// The board link plus the match it names. A recipient whose client predates
/// this parameter reads the npub, ignores the rest, and lands on the board —
/// one tap from the match instead of on it.
String matchShareUrl(String npub, String matchId) =>
    '${liveBoardShareUrl(npub)}&$kShareMatchParam=$matchId';

/// The query parameter naming one match on the board.
const String kShareMatchParam = 'match';

/// What a match id is allowed to look like.
///
/// Four lowercase hex characters, which is what `Match.create` generates.
/// Matched against the *decoded* value after trimming and lowercasing — see
/// [_rawMatchId] for why that order, and `docs/specs/shared-match-links.md`
/// for the contract both readers implement.
final RegExp _matchIdPattern = RegExp(r'^[0-9a-f]{4}$');

/// The match id in [uri], or null if it names none.
///
/// Returns the id, or null both for "no match parameter" and for one that is
/// not a match id — the caller separates those, because they are the difference
/// between a board link and a broken one.
String? _rawMatchId(Uri uri) {
  final value = uri.queryParameters[kShareMatchParam]?.trim().toLowerCase();
  return (value == null || value.isEmpty) ? null : value;
}

/// The query parameter a shared board link carries the pubkey in.
///
/// One name, matching `SHARE_PUBKEY_PARAM` in choke-scoreboard's
/// `share-link.ts`, because one URL is shared to everyone and whichever of the
/// two the recipient opens it in has to understand it.
///
/// The *value* may still be an `npub1…` or bare 64-character hex — `parsePubkey`
/// sorts that out, so this stays a question about the URL and not about crypto.
const String kSharePubkeyParam = 'npub';

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

/// A shared link naming one match on [pubkeyHex].
///
/// Both halves, always. A match id is unique only inside one author's events,
/// so an id without an organizer names nothing and never reaches here.
class SharedMatch extends ShareLink {
  const SharedMatch(this.pubkeyHex, this.matchId);

  /// The watched author, in lowercase hex.
  final String pubkeyHex;

  /// The requested match, already validated against the contract's grammar.
  final String matchId;
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
/// holding either an npub or bare hex, optionally followed by `&match=…`
/// naming one match on that board.
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

  final match = _rawMatchId(uri);
  final value = uri.queryParameters[kSharePubkeyParam]?.trim();

  // An empty value is not a broken key, it is no key — the web board skips it
  // the same way, and a bare `?npub=` should not accuse anybody of anything.
  //
  // Unless a match was named. Then the link did promise something, and an id
  // with no author to look it up under cannot deliver it: ids are unique only
  // inside one organizer's events.
  if (value == null || value.isEmpty) {
    return match == null ? const NotAShareLink() : const BrokenShareLink();
  }

  final hex = parsePubkey(value, crypto);
  if (hex == null) return const BrokenShareLink();

  if (match == null) return SharedBoard(hex);

  // A named match that is not a match id is a promise this app cannot keep,
  // and saying so beats quietly handing over the board it sits on.
  return _matchIdPattern.hasMatch(match)
      ? SharedMatch(hex, match)
      : const BrokenShareLink();
}

/// Set when a link named a board and its pubkey could not be read.
///
/// The scoreboard shows this instead of a board. The app does not clear it on
/// its own: only the user can say "fine, show me what I had", because only they
/// know they did not get what they tapped.
final brokenShareLinkProvider = StateProvider<bool>((ref) => false);

/// The match a link asked for, until something shows it.
///
/// Set by [openShareLink] and read by the scoreboard, which owns the waiting:
/// the feed answers whenever it answers, and until then there is a request and
/// no match. Deliberately not "the match to display" — the parser's job ends at
/// saying what was named, and Pending, Resolved and Unresolved are states of a
/// screen, not of a URL.
///
/// Cleared by any link that names no match, so a board link never inherits the
/// request left by the one before it.
final requestedMatchProvider = StateProvider<String?>((ref) => null);

/// Open a shared board link.
///
/// Returns whether the link was one this app answers for — true both for a
/// board it opened and for a broken one it reported, since both are ours.
bool openShareLink(Uri uri, NostrCrypto crypto, WidgetRef ref) {
  switch (readShareLink(uri, crypto)) {
    case NotAShareLink():
      // Nothing to say, and nothing touched. This is also the ordinary launch
      // route, and an app that complained about that would complain every time
      // it opened — and must not throw somebody out of what they were doing.
      _log(uri, 'ignoring');
      return false;

    case SharedBoard(:final pubkeyHex):
      // Clear the stack first, then switch. A detail screen left on top would
      // otherwise hide the board the link just opened — and, for a different
      // organizer, would find its match missing and show "no longer available"
      // instead. Popping after the switch would let it render once against the
      // new organizer and flash exactly that.
      //
      // Only when there is something to gain: a link for the board already
      // being watched would otherwise close the match the user had open and
      // hand them back the list, for no change at all. Re-shares in a group
      // chat are how that happens, and it reads as the app losing their place.
      if (ref.read(watchedPubkeyProvider) != pubkeyHex) {
        _clearStack(ref);
      }

      ref.read(brokenShareLinkProvider.notifier).state = false;
      ref.read(requestedMatchProvider.notifier).state = null;
      ref.read(watchedPubkeyProvider.notifier).watch(pubkeyHex);
      ref.read(selectedTabProvider.notifier).state = AppTab.scoreboard;
      return true;

    case SharedMatch(:final pubkeyHex, :final matchId):
      // The same "only when there is something to gain" rule as above, widened
      // by what this link names. A re-share of the match already on screen must
      // still change nothing — that is the group-chat case, and it reads as the
      // app losing the viewer's place. But a link naming a *different* match on
      // the board already being watched now has something to do, where a board
      // link would have had nothing: the stack has to come down for the new
      // match to be seen.
      if (ref.read(watchedPubkeyProvider) != pubkeyHex ||
          ref.read(requestedMatchProvider) != matchId) {
        _clearStack(ref);
      }

      // The request goes in before the pubkey, not after. Switching the
      // watched author rebuilds the feed, and anything that reacts to that
      // synchronously asks "was a match asked for?" — set second, it would
      // read the previous answer. The board case above clears it first for
      // the same reason; these two have to agree.
      ref.read(brokenShareLinkProvider.notifier).state = false;
      ref.read(requestedMatchProvider.notifier).state = matchId;
      ref.read(watchedPubkeyProvider.notifier).watch(pubkeyHex);
      ref.read(selectedTabProvider.notifier).state = AppTab.scoreboard;
      return true;

    case BrokenShareLink():
      // Fail closed. The previously watched pubkey is kept — it is theirs, and
      // throwing it away would punish them for somebody else's bad link — but
      // the board stays behind the message until they choose to go back to it.
      // What must not happen is that board appearing as though the link worked.
      //
      // And the stack has to come down for the same reason it does above: a
      // message the user never sees is no better than no message. This is the
      // one case worth popping unconditionally — there is no "already showing
      // it" to skip, and the whole point is that they find out.
      _log(uri, 'reporting as broken');
      _clearStack(ref);

      // No request survives the message. Leaving one behind would have the
      // scoreboard still waiting on a match underneath a screen saying the
      // link could not be read.
      ref.read(requestedMatchProvider.notifier).state = null;
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
  final named = uri.queryParameters.containsKey(kSharePubkeyParam);
  debugPrint(
    'DeepLink: $what a link for ${uri.host.isEmpty ? '(no host)' : uri.host}'
    '${named ? ' whose $kSharePubkeyParam did not parse' : ' with no pubkey parameter'}',
  );
}

/// Pop back to the board, stopping at any route that refuses to go.
///
/// A bare `popUntil` will not do: it calls `pop`, which is unconditional, and
/// `MatchControlScreen` guards itself with a `PopScope` that only intercepts
/// system back and `maybePop`. A referee scoring a live match would have the
/// screen torn away by an incoming link, with none of the confirmation that
/// guard exists to require — a worse outcome than the stale screen this change
/// is about.
///
/// `maybePop` in a loop will not do either, and less obviously: it answers
/// "was this request handled", and a guard saying *no* counts as handling it.
/// The loop reads that as progress and spins forever.
///
/// So each route is asked what it would do, and the first refusal ends it. The
/// link has still selected the board; it is simply behind a screen the user was
/// told they must leave deliberately.
void _clearStack(WidgetRef ref) {
  final navigator = ref.read(navigatorKeyProvider).currentState;
  if (navigator == null) return;

  navigator.popUntil((route) {
    if (route.isFirst) return true;
    return route is ModalRoute &&
        route.popDisposition != RoutePopDisposition.pop;
  });
}
