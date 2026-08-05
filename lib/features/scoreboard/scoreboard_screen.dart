import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';

import '../../services/deep_links/share_link.dart';
import '../../services/nostr/crypto/nostr_crypto.dart';
import '../../shared/share_sheet.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/match_card.dart';
import '../../shared/widgets/qr_dialog.dart';
import '../../shared/widgets/status_filter_bar.dart';
import '../match/models/match.dart';
import 'providers/scoreboard_providers.dart';
import 'scoreboard_match_screen.dart';

/// Somebody else's matches, live, and nothing more.
///
/// Read-only on purpose: this exists for watching a mat you are not refereeing —
/// a coach following their team, a competitor's family two rooms away. Nothing
/// here can start, score or end anything, and it never mixes with the user's own
/// matches.
class ScoreboardScreen extends ConsumerStatefulWidget {
  const ScoreboardScreen({super.key});

  @override
  ConsumerState<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends ConsumerState<ScoreboardScreen> {
  final _controller = TextEditingController();

  /// Set when what the user typed is not a pubkey, and cleared as soon as they
  /// edit again, so the error always describes what is in the field now.
  bool _invalid = false;

  /// The request this screen has already pushed a board for.
  ///
  /// The consuming half of [requestedMatchProvider]: the provider says what a
  /// link asked for and keeps saying it for as long as that board is up, and
  /// this says whether the asking has been acted on. Without it every rebuild —
  /// a tab change, a new event, a keystroke — would push the same match again.
  String? _openedRequest;

  @override
  void initState() {
    super.initState();
    // A link the app was *launched* by is read after the first frame, which can
    // land either side of this listener being registered. Reading the current
    // value once covers the side that would otherwise be missed; the guard in
    // [_openRequestedMatch] makes doing it twice harmless.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final requested = ref.read(requestedMatchProvider);
      if (requested != null) _openRequestedMatch(requested);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Put the match a link named on screen.
  ///
  /// This lives here, and not in `MainNavigation` or the link handler, because
  /// this screen is the one that is always alive: it sits in an [IndexedStack]
  /// that builds every tab and keeps them, so a link arriving while the user is
  /// on Home still finds a listener — and `openShareLink` has already selected
  /// this tab by the time the push happens.
  ///
  /// The board is pushed rather than swapped in, so Back returns to the list
  /// the recipient was never shown. It is marked as coming from a link, which
  /// is the whole difference between waiting for the feed and declaring the
  /// match gone.
  void _openRequestedMatch(String matchId) {
    // Re-opening the link already on screen must do nothing: no flicker, no
    // reload. That is the group-chat re-share, and pushing a second identical
    // board would read as the app losing the viewer's place.
    if (_openedRequest == matchId) return;
    _openedRequest = matchId;

    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => ScoreboardMatchScreen(matchId: matchId, fromLink: true),
    ))
        .then((_) {
      if (!mounted) return;
      // Only if this is still the board that came down. A link naming a
      // *different* match pops this one and pushes the next in the same turn,
      // and the pop's answer arrives after the push — clearing unconditionally
      // would forget the board that is now on screen and let a re-share of it
      // push a duplicate.
      if (_openedRequest == matchId) _openedRequest = null;
      // The request outlived the screen that answered it. Dropping it here —
      // and only if it is still the one this screen opened — lets the same
      // link, tapped again later, open the match a second time, while a link
      // that arrived in the meantime keeps its claim.
      if (ref.read(requestedMatchProvider) == matchId) {
        ref.read(requestedMatchProvider.notifier).state = null;
      }
    });
  }

  void _watch() {
    final crypto = ref.read(nostrCryptoProvider);
    final hex = parsePubkey(_controller.text, crypto);

    if (hex == null) {
      setState(() => _invalid = true);
      return;
    }

    setState(() => _invalid = false);
    FocusScope.of(context).unfocus();
    ref.read(watchedPubkeyProvider.notifier).watch(hex);
  }

  void _stopWatching() {
    _controller.clear();
    setState(() => _invalid = false);
    ref.read(watchedPubkeyProvider.notifier).watch(null);
  }

  void _toggleStatus(MatchStatus status) {
    final current =
        Set<MatchStatus>.from(ref.read(scoreboardStatusFilterProvider));
    if (!current.remove(status)) current.add(status);
    ref.read(scoreboardStatusFilterProvider.notifier).state = current;
  }

  /// The link a spectator opens to reach the board being watched.
  ///
  /// The npub, not the hex: it is what the web board publishes and what a
  /// person can recognise if they ever look at the URL.
  String _boardUrl(String watchedHex) =>
      liveBoardShareUrl(ref.read(nostrCryptoProvider).npubEncode(watchedHex));

  /// Hand this board to somebody else.
  ///
  /// A board is worth nothing to the person already watching it — its value is
  /// that it travels: a coach sends it to a parent two rooms away, a spectator
  /// re-shares it into the academy group. Sharing the *link* rather than the
  /// key means the recipient has nothing to paste, and the same URL serves both
  /// of them: the app opens it if they have it, the web board if they do not.
  Future<void> _shareBoard(String watchedHex) async {
    final l10n = AppLocalizations.of(context);
    await shareLink(
      context,
      message: l10n.scoreboardShareBoardMessage,
      url: _boardUrl(watchedHex),
      subject: l10n.scoreboardShareBoard,
      logTag: 'ScoreboardScreen',
    );
  }

  /// Hand one fight to somebody else, without opening it first.
  ///
  /// The unit people actually share. A board link says "follow this academy"
  /// and leaves the recipient hunting a list that reorders itself as matches
  /// start and finish; this one says "watch this fight" and lands on it.
  ///
  /// The npub travels with the id because an id names nothing on its own — four
  /// hex characters are unique only inside one organizer's events.
  Future<void> _shareMatch(Match match, String watchedHex) async {
    await shareMatchLink(
      context,
      ref,
      watchedHex: watchedHex,
      matchId: match.id,
      logTag: 'ScoreboardScreen',
    );
  }

  /// The same link as a code, for a room rather than a chat.
  ///
  /// This is how a board reaches people who are physically present: the
  /// organizer holds up or projects the code and the crowd points a camera at
  /// it, with nothing typed and no key exchanged.
  ///
  /// The share control is here because the room is not always the whole
  /// audience. Somebody who opened this to project it often also has one person
  /// to text, and without it that means closing the dialog to reach the
  /// header's share button. It reuses [_shareBoard], so a link sent from under
  /// the code and one sent from the header are the same link, worded the same.
  void _showQr(String watchedHex) {
    final l10n = AppLocalizations.of(context);
    showQrDialog(
      context,
      title: l10n.scoreboardQrTitle,
      data: _boardUrl(watchedHex),
      caption: l10n.scoreboardQrHint,
      copyLabel: l10n.link,
      share: (
        label: l10n.scoreboardShareBoard,
        onTap: () => _shareBoard(watchedHex),
      ),
    );
  }

  void _open(Match match) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScoreboardMatchScreen(matchId: match.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tk = ChokeTokens.of(context);
    // Nothing reads this as state — the board it names is a route, not a
    // branch of this build — so it is listened to rather than watched.
    ref.listen<String?>(requestedMatchProvider, (_, requested) {
      if (requested != null) _openRequestedMatch(requested);
    });

    final brokenLink = ref.watch(brokenShareLinkProvider);
    final watched = ref.watch(watchedPubkeyProvider);
    // Two lists: everything in scope, which the chips count from, and what
    // survives the filter, which is what the list shows.
    final allMatches = ref.watch(scoreboardMatchesProvider);
    final matches = ref.watch(scoreboardFilteredMatchesProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  // Filled with the accent, with the mark on it in ink — not
                  // home's light grey plate.
                  //
                  // Home's grey is chosen for what sits on it: a red and black
                  // logo, which reads well against it. A green glyph does not.
                  // Measured against this theme's accent, that grey gives
                  // 1.27:1 in the dark theme and 2.15:1 in the light one, where
                  // iconography wants 3:1. Filled, the same glyph in ink gives
                  // 9.87:1 and 5.81:1.
                  Container(
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: tk.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.scoreboard_outlined,
                      color: BJJColors.ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.navScoreboard,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -.5,
                            height: 1.05,
                          ),
                        ),
                        Text(
                          // Not the watched pubkey while a broken link is
                          // showing: naming an organizer one line above "that
                          // link is broken" invites the reader to take this hex
                          // for the link's board, which is the substitution the
                          // whole state exists to prevent.
                          brokenLink || watched == null
                              ? l10n.scoreboardWelcomeTitle
                              : _shortPubkey(watched),
                          style: TextStyle(fontSize: 12.5, color: tk.muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Only once there is a board to hand over. With nothing
                  // watched there is no link to give, and behind a broken link
                  // the board underneath is not the one that was asked for —
                  // passing it on would spread the substitution the broken-link
                  // state exists to stop.
                  if (watched != null && !brokenLink) ...[
                    IconButton(
                      onPressed: () => _showQr(watched),
                      tooltip: l10n.showQr,
                      color: tk.muted,
                      icon: const Icon(Icons.qr_code_2),
                    ),
                    IconButton(
                      onPressed: () => _shareBoard(watched),
                      tooltip: l10n.scoreboardShareBoard,
                      color: tk.muted,
                      icon: const Icon(Icons.ios_share),
                    ),
                  ],
                ],
              ),
            ),
            if (!brokenLink)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: _buildPubkeyField(l10n, tk, watched),
              ),
            if (watched != null && !brokenLink)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: StatusFilterBar(
                  matches: allMatches,
                  selected: ref.watch(scoreboardStatusFilterProvider),
                  onToggle: _toggleStatus,
                ),
              ),
            Expanded(
              child: switch ((brokenLink, watched, matches.isEmpty)) {
                // A link that named a board and could not be read outranks
                // everything: whatever is behind this is not what was tapped.
                (true, _, _) => _buildBrokenLink(l10n, tk),
                (_, null, _) => _buildWelcome(l10n, tk),
                (_, _, true) => _buildEmpty(l10n, tk),
                _ => _buildList(matches, watched),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPubkeyField(
      AppLocalizations l10n, ChokeTokens tk, String? watched) {
    if (watched != null) {
      return Row(
        children: [
          Icon(Icons.podcasts, size: 16, color: tk.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _shortPubkey(watched),
              style: TextStyle(
                fontSize: 12.5,
                fontFamily: 'monospace',
                color: tk.muted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _stopWatching,
            child: Text(l10n.scoreboardStopWatching),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _watch(),
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
            // A pubkey is never a sentence, and a keyboard that capitalises one
            // turns a valid npub into an invalid one.
            textCapitalization: TextCapitalization.none,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
            ],
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: l10n.scoreboardPubkeyHint,
              hintStyle: TextStyle(fontSize: 12.5, color: tk.faint),
              errorText: _invalid ? l10n.scoreboardInvalidPubkey : null,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: FilledButton(
            onPressed: _watch,
            child: Text(l10n.scoreboardWatch),
          ),
        ),
      ],
    );
  }

  /// The board, one card per match.
  ///
  /// [watchedHex] is what makes a card shareable: the link a card hands out
  /// names the organizer as well as the match, so with nobody watched there is
  /// no link to give and the icon does not appear. In practice this list is
  /// only reached with a board watched — the argument is threaded rather than
  /// asserted because the alternative is a `!` on something the type system
  /// cannot see is settled.
  Widget _buildList(List<Match> matches, String? watchedHex) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: MatchCard(
            match: match,
            onTap: () => _open(match),
            onShare: watchedHex == null
                ? null
                : () => _shareMatch(match, watchedHex),
          ),
        );
      },
    );
  }

  /// The link named a board and its pubkey could not be read.
  ///
  /// Deliberately not a snackbar: a message that disappears on its own, over a
  /// board belonging to somebody else, is the same silent substitution this
  /// screen exists to avoid. The user dismisses it, so the app knows they know.
  Widget _buildBrokenLink(AppLocalizations l10n, ChokeTokens tk) {
    return _buildPlaceholder(
      tk,
      icon: Icons.link_off,
      title: l10n.scoreboardBrokenLinkTitle,
      body: l10n.scoreboardBrokenLinkBody,
      // The one state here that is a failure rather than an absence, and the
      // only one the user has to act on.
      accent: tk.dangerFg,
      action: FilledButton(
        onPressed: () =>
            ref.read(brokenShareLinkProvider.notifier).state = false,
        child: Text(l10n.scoreboardBrokenLinkDismiss),
      ),
    );
  }

  Widget _buildWelcome(AppLocalizations l10n, ChokeTokens tk) {
    return _buildPlaceholder(
      tk,
      icon: Icons.qr_code_scanner_outlined,
      title: l10n.scoreboardWelcomeTitle,
      body: l10n.scoreboardWelcomeBody,
    );
  }

  Widget _buildEmpty(AppLocalizations l10n, ChokeTokens tk) {
    return _buildPlaceholder(
      tk,
      icon: Icons.hourglass_empty,
      title: l10n.scoreboardEmptyTitle,
      body: l10n.scoreboardEmptyBody,
    );
  }

  /// The shape every "there is no list here" state takes: an icon, a line, and
  /// an explanation.
  ///
  /// [accent] tints the icon and the title for a state that is a failure rather
  /// than an absence; without it they stay quiet, which is right for waiting and
  /// for having nothing to show yet. [action] appends something to do about it.
  Widget _buildPlaceholder(
    ChokeTokens tk, {
    required IconData icon,
    required String title,
    required String body,
    Color? accent,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: accent ?? tk.faint),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: accent ?? tk.muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tk.faint),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action,
            ],
          ],
        ),
      ),
    );
  }

  /// The watched organizer, short enough to fit and still recognisable.
  ///
  /// Shown as an **npub**, whatever was pasted. Hex is the app's internal
  /// currency — the subscription filter, the event author, the lookup key — but
  /// it is not what anybody was handed: an organizer gives out an npub, and a
  /// spectator checking they are on the right board compares what is on screen
  /// against what is in their chat. Truncated hex makes them compare two
  /// different encodings of the same key, which nobody can do by eye.
  ///
  /// Truncated after encoding, so both ends belong to the npub. The leading
  /// `npub1` is kept on purpose: it is what makes the string recognisable as a
  /// key at all.
  String _shortPubkey(String hex) {
    final npub = ref.read(nostrCryptoProvider).npubEncode(hex);
    if (npub.length <= 16) return npub;
    return '${npub.substring(0, 8)}…${npub.substring(npub.length - 8)}';
  }
}
