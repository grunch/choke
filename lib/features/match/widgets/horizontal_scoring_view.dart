import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../models/match.dart';
import '../providers/match_control_provider.dart';

/// Parse hex color string (#RRGGBB) to Color with fallback
Color _hexToColor(String hex, Color fallback) {
  try {
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return fallback;
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return fallback;
  }
}

/// Format seconds as mm:ss
String _formatTime(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Horizontal layout optimized for fast dual-fighter scoring
/// Eliminates tab-switching by showing buttons for both fighters simultaneously
class HorizontalScoringView extends ConsumerWidget {
  const HorizontalScoringView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchControlProvider);
    final notifier = ref.read(matchControlProvider.notifier);
    final match = state.match;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final f1Color = _hexToColor(match.f1Color, colors.outline);
    final f2Color = _hexToColor(match.f2Color, colors.outline);

    final isLow = state.remainingSeconds <= 30 && state.isRunning;
    final displayText = match.status == MatchStatus.canceled
        ? l10n.canceled
        : _formatTime(state.remainingSeconds);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Top row: Fighter names, scores, and timer
            Row(
              children: [
                // Fighter 1 (left)
                Expanded(
                  child: _buildFighterHeader(
                    context: context,
                    name: match.f1Name,
                    score: match.f1Score,
                    advantages: match.f1Adv,
                    penalties: match.f1Pen,
                    color: f1Color,
                    isLeading: match.f1Score > match.f2Score,
                  ),
                ),

                // Timer (center)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Text(
                        displayText,
                        style: TextStyle(
                          color: isLow ? colors.error : colors.onSurface,
                          fontSize:
                              match.status == MatchStatus.canceled ? 18 : 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(match.status, colors)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _statusLabel(l10n, match.status),
                          style: TextStyle(
                            color: _statusColor(match.status, colors),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Fighter 2 (right)
                Expanded(
                  child: _buildFighterHeader(
                    context: context,
                    name: match.f2Name,
                    score: match.f2Score,
                    advantages: match.f2Adv,
                    penalties: match.f2Pen,
                    color: f2Color,
                    isLeading: match.f2Score > match.f1Score,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Scoring buttons row
            if (state.isRunning)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fighter 1 buttons (left)
                    Expanded(
                      child: _buildScoringColumn(
                        context: context,
                        fighter: 1,
                        fighterColor: f1Color,
                        notifier: notifier,
                        l10n: l10n,
                        colors: colors,
                        canUndo: state.canUndo,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Fighter 2 buttons (right)
                    Expanded(
                      child: _buildScoringColumn(
                        context: context,
                        fighter: 2,
                        fighterColor: f2Color,
                        notifier: notifier,
                        l10n: l10n,
                        colors: colors,
                        canUndo: state.canUndo,
                      ),
                    ),
                  ],
                ),
              ),

            // Match info footer
            const SizedBox(height: 8),
            Text(
              l10n.matchId(match.id),
              style: TextStyle(
                color: colors.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFighterHeader({
    required BuildContext context,
    required String name,
    required int score,
    required int advantages,
    required int penalties,
    required Color color,
    required bool isLeading,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 14,
                  fontWeight: isLeading ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$score pts',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'A:$advantages  P:$penalties',
          style: TextStyle(
            color: colors.onSurface.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildScoringColumn({
    required BuildContext context,
    required int fighter,
    required Color fighterColor,
    required MatchControlNotifier notifier,
    required AppLocalizations l10n,
    required ColorScheme colors,
    required bool canUndo,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // +2 button
        _buildHorizontalScoringButton(
          context: context,
          label: l10n.takedownSweep,
          points: '+2',
          baseColor: colors.primary,
          fighterColor: fighterColor,
          onTap: () => notifier.scorePt2(fighter),
        ),
        const SizedBox(height: 10),

        // +3 button
        _buildHorizontalScoringButton(
          context: context,
          label: l10n.guardPass,
          points: '+3',
          baseColor: colors.primary,
          fighterColor: fighterColor,
          onTap: () => notifier.scorePt3(fighter),
        ),
        const SizedBox(height: 10),

        // +4 button
        _buildHorizontalScoringButton(
          context: context,
          label: l10n.mountBackTake,
          points: '+4',
          baseColor: colors.secondary,
          fighterColor: fighterColor,
          onTap: () => notifier.scorePt4(fighter),
        ),
        const SizedBox(height: 14),

        // Advantage and Penalty buttons
        Row(
          children: [
            Expanded(
              child: _buildCompactButton(
                context: context,
                label: 'A',
                color: BJJColors.gold,
                onTap: () => notifier.scoreAdv(fighter),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCompactButton(
                context: context,
                label: 'P',
                color: colors.error,
                onTap: () => notifier.scorePen(fighter),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Undo button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: canUndo ? notifier.undo : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: BorderSide(
                color: canUndo ? fighterColor : colors.outline.withOpacity(0.3),
              ),
            ),
            child: Icon(
              Icons.undo,
              size: 16,
              color: canUndo ? fighterColor : colors.onSurface.withOpacity(0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalScoringButton({
    required BuildContext context,
    required String label,
    required String points,
    required Color baseColor,
    required Color fighterColor,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: fighterColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: fighterColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  points,
                  style: TextStyle(
                    color: _getTextColorForBackground(fighterColor),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactButton({
    required BuildContext context,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(MatchStatus status, ColorScheme colors) {
    switch (status) {
      case MatchStatus.waiting:
        return colors.tertiary;
      case MatchStatus.inProgress:
        return BJJColors.green;
      case MatchStatus.finished:
        return colors.primary;
      case MatchStatus.canceled:
        return colors.error;
    }
  }

  String _statusLabel(AppLocalizations l10n, MatchStatus status) {
    switch (status) {
      case MatchStatus.waiting:
        return l10n.statusWaiting;
      case MatchStatus.inProgress:
        return l10n.statusInProgress;
      case MatchStatus.finished:
        return l10n.statusFinished;
      case MatchStatus.canceled:
        return l10n.statusCanceled;
    }
  }

  /// Get appropriate text color (white or black) based on background brightness
  Color _getTextColorForBackground(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
