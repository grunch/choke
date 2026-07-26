import 'package:flutter/material.dart';
import 'package:choke/l10n/generated/app_localizations.dart';

import '../../features/match/models/match.dart';
import '../theme/app_theme.dart';
import 'match_card.dart';

/// The row of status chips above a match list: one per status, each showing how
/// many matches are in it, each toggling that status in and out of view.
///
/// Shared by the home feed and the read-only scoreboard. The two filter
/// different lists and keep their choices apart — hiding finished matches on
/// somebody else's board should not hide them on your own — so the state comes
/// in rather than being read from a provider in here.
class StatusFilterBar extends StatelessWidget {
  const StatusFilterBar({
    super.key,
    required this.matches,
    required this.selected,
    required this.onToggle,
  });

  /// Everything in scope, filter or no filter. The counts describe this rather
  /// than what survives the filter, or a chip would only ever count what it
  /// already lets through — and read zero for everything it hides.
  final List<Match> matches;

  final Set<MatchStatus> selected;

  /// Called with the status that was tapped. What a toggle means is the
  /// caller's to decide, because the set is theirs.
  final ValueChanged<MatchStatus> onToggle;

  @override
  Widget build(BuildContext context) {
    final tk = ChokeTokens.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in MatchStatus.values)
          _StatusChip(
            status: status,
            count: matches.where((m) => m.status == status).length,
            isSelected: selected.contains(status),
            tokens: tk,
            onTap: () => onToggle(status),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.count,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  final MatchStatus status;
  final int count;
  final bool isSelected;
  final ChokeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = matchStatusAccent(tokens, status);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${matchStatusLabel(l10n, status)}: $count',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          // Enforce the 44px minimum interactive height for an accessible tap
          // target; the visible layout and styling stay compact.
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: .12) : tokens.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected ? color.withValues(alpha: .5) : tokens.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                matchStatusLabel(l10n, status),
                style: TextStyle(
                  color: isSelected ? color : tokens.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  color: count > 0 ? color : tokens.faint,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
