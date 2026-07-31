import 'package:flutter/material.dart';
import 'package:choke/l10n/generated/app_localizations.dart';

import '../../features/match/models/match.dart';
import '../../features/match/widgets/outcome_label.dart';
import '../theme/app_theme.dart';

/// Parse a hex colour string (`#RRGGBB`) into a [Color], falling back when it is
/// not one. Fighter colours arrive over the wire and cannot be trusted to parse.
Color hexToColor(String hex, Color fallback) {
  try {
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return fallback;
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return fallback;
  }
}

/// The colour a status is spoken in.
Color matchStatusAccent(ChokeTokens tk, MatchStatus status) {
  return switch (status) {
    MatchStatus.waiting => tk.goldFg,
    MatchStatus.inProgress => tk.accent,
    MatchStatus.finished => tk.statusFinishedFg,
    MatchStatus.canceled => tk.statusCanceledFg,
  };
}

/// What a status is called, in the language of the room.
String matchStatusLabel(AppLocalizations l10n, MatchStatus status) {
  return switch (status) {
    MatchStatus.waiting => l10n.statusWaiting,
    MatchStatus.inProgress => l10n.statusInProgress,
    MatchStatus.finished => l10n.statusFinished,
    MatchStatus.canceled => l10n.statusCanceled,
  };
}

/// Whether to light this fighter's number up.
///
/// A finished match names its winner, and that name is the only thing worth
/// believing: a fighter can lead 4–0 and still lose to an armbar. Only while a
/// match is undecided does the scoreboard get to speak for itself — and a
/// canceled match has no winner at all.
bool isWinningFighter(Match match, MatchWinner fighter, bool isCanceled) {
  if (isCanceled) return false;

  final winner = match.winner;
  if (winner != null) return winner == fighter;
  if (match.method != null) return false; // a draw: nobody won

  return match.scoreboardWinner == fighter;
}

/// The status pill: a dot that only appears while a match is running, and the
/// status in words.
class MatchStatusChip extends StatelessWidget {
  const MatchStatusChip({super.key, required this.status});

  final MatchStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tk = ChokeTokens.of(context);
    final (fg, bg) = switch (status) {
      MatchStatus.waiting => (tk.goldFg, tk.goldFg.withValues(alpha: .14)),
      MatchStatus.inProgress => (tk.accent, tk.accent.withValues(alpha: .2)),
      MatchStatus.finished => (tk.statusFinishedFg, tk.statusFinishedBg),
      MatchStatus.canceled => (tk.statusCanceledFg, tk.statusCanceledBg),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == MatchStatus.inProgress) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            matchStatusLabel(l10n, status),
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small counter badge, for advantages and penalties.
class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One match as a row in a list: both fighters, the effective score, and how it
/// ended once it has.
///
/// Shared by the home feed and the read-only scoreboard, which show the same
/// matches and differ only in what opening one means — hence [onTap], rather
/// than a card that knows where it is.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, this.onTap, this.onShare});

  final Match match;

  /// What opening this match means here. A card with no [onTap] does not react
  /// to being pressed.
  final VoidCallback? onTap;

  /// How to hand this match to somebody else, where that is possible.
  ///
  /// Optional, and absent by default, because only the read-only scoreboard has
  /// a link to give: it knows whose board it is watching, and a match id names
  /// nothing without an organizer. A card with no callback renders exactly what
  /// it rendered before this existed, which is what keeps the home feed
  /// untouched.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tk = ChokeTokens.of(context);
    final colors = Theme.of(context).colorScheme;
    final f1Color = hexToColor(match.f1Color, colors.outline);
    final f2Color = hexToColor(match.f2Color, colors.outline);
    final isLive = match.status == MatchStatus.inProgress;
    final isCanceled = match.status == MatchStatus.canceled;

    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: isLive
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tk.accent.withValues(alpha: .12),
                  tk.accent.withValues(alpha: .03),
                ],
              )
            : null,
        color: isLive ? null : tk.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLive ? tk.accent.withValues(alpha: .45) : tk.cardBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${match.id}',
                style: TextStyle(
                  color: tk.faint,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildTrailing(l10n, tk),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration:
                          BoxDecoration(color: f1Color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        match.f1Name,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (match.f1EffectiveAdvantages > 0) ...[
                      const SizedBox(width: 6),
                      _SmallBadge(
                          'A:${match.f1EffectiveAdvantages}', tk.goldFg),
                    ],
                    if (match.f1Pen > 0) ...[
                      const SizedBox(width: 4),
                      _SmallBadge('P:${match.f1Pen}', tk.dangerFg),
                    ],
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${match.f1EffectivePoints}',
                    style: TextStyle(
                      color: isWinningFighter(match, MatchWinner.f1, isCanceled)
                          ? tk.accent
                          : tk.muted,
                      fontWeight: FontWeight.bold,
                      fontSize: 27,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: Text(
                      l10n.vs,
                      style: TextStyle(fontSize: 12, color: tk.faint),
                    ),
                  ),
                  Text(
                    '${match.f2EffectivePoints}',
                    style: TextStyle(
                      color: isWinningFighter(match, MatchWinner.f2, isCanceled)
                          ? tk.accent
                          : tk.muted,
                      fontWeight: FontWeight.bold,
                      fontSize: 27,
                      height: 1,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (match.f2EffectiveAdvantages > 0) ...[
                      _SmallBadge(
                          'A:${match.f2EffectiveAdvantages}', tk.goldFg),
                      const SizedBox(width: 6),
                    ],
                    if (match.f2Pen > 0) ...[
                      _SmallBadge('P:${match.f2Pen}', tk.dangerFg),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        match.f2Name,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      width: 9,
                      height: 9,
                      decoration:
                          BoxDecoration(color: f2Color, shape: BoxShape.circle),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // How it ended — because the scoreboard above cannot say. A match that
          // finished on a submission shows the loser's numbers as the bigger
          // ones, and only this line names the fighter who actually won.
          if (describeOutcome(l10n, match) case final outcome?) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.emoji_events_outlined, size: 13, color: tk.goldFg),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    outcome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tk.goldFg,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: isCanceled ? Opacity(opacity: .72, child: card) : card,
    );
  }

  /// The right-hand end of the card's first line: the status, and a way to pass
  /// the match on where there is one.
  ///
  /// Returns the chip alone when there is nothing to share, rather than a Row
  /// holding only the chip, so a card without [onShare] lays out exactly as it
  /// did before this existed.
  ///
  /// The affordance is deliberately secondary — small, faint, and sharing the
  /// line with the status rather than claiming one of its own. A list of ten
  /// cards each shouting "share" is a list nobody reads, and the card's own tap
  /// target is still "open this match".
  Widget _buildTrailing(AppLocalizations l10n, ChokeTokens tk) {
    if (onShare == null) return MatchStatusChip(status: match.status);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MatchStatusChip(status: match.status),
        const SizedBox(width: 2),
        IconButton(
          onPressed: onShare,
          tooltip: l10n.scoreboardShareMatch,
          // Sized down to the chip beside it so the header line does not grow
          // a taller row for one glyph.
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 30, height: 26),
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.ios_share, size: 14, color: tk.faint),
        ),
      ],
    );
  }
}
