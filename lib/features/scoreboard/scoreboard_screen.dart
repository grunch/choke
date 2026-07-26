import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';

import '../../services/deep_links/share_link.dart';
import '../../services/nostr/crypto/nostr_crypto.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/match_card.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                _ => _buildList(matches),
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

  Widget _buildList(List<Match> matches) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: MatchCard(match: match, onTap: () => _open(match)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 44, color: tk.dangerFg),
            const SizedBox(height: 14),
            Text(
              l10n.scoreboardBrokenLinkTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tk.dangerFg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.scoreboardBrokenLinkBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tk.faint),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () =>
                  ref.read(brokenShareLinkProvider.notifier).state = false,
              child: Text(l10n.scoreboardBrokenLinkDismiss),
            ),
          ],
        ),
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

  Widget _buildPlaceholder(
    ChokeTokens tk, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: tk.faint),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tk.muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tk.faint),
            ),
          ],
        ),
      ),
    );
  }

  /// A pubkey is 64 characters of hex nobody reads. Show enough of both ends to
  /// tell which one it is.
  String _shortPubkey(String hex) {
    if (hex.length <= 16) return hex;
    return '${hex.substring(0, 8)}…${hex.substring(hex.length - 8)}';
  }
}
