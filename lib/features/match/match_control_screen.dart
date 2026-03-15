import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import 'models/match.dart';
import 'providers/match_control_provider.dart';
import 'widgets/horizontal_scoring_view.dart';

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

/// Main match control screen with timer, scoring, and live updates
class MatchControlScreen extends ConsumerStatefulWidget {
  final Match match;

  const MatchControlScreen({super.key, required this.match});

  @override
  ConsumerState<MatchControlScreen> createState() => _MatchControlScreenState();
}

class _MatchControlScreenState extends ConsumerState<MatchControlScreen> {
  /// Currently selected fighter for scoring: 1 or 2
  int _selectedFighter = 1;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchControlProvider);
    final notifier = ref.read(matchControlProvider.notifier);
    final match = state.match;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final f1Color = _hexToColor(match.f1Color, colors.outline);
    final f2Color = _hexToColor(match.f2Color, colors.outline);
    final l10n = AppLocalizations.of(context);

    return OrientationBuilder(
      builder: (context, orientation) {
        // Use horizontal layout for landscape orientation
        if (orientation == Orientation.landscape) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.matchId(match.id)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _onBack(context, state),
              ),
              actions: [
                if (state.isPublishing)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.secondary,
                      ),
                    ),
                  ),
              ],
            ),
            body: const HorizontalScoringView(),
          );
        }

        // Default vertical layout for portrait
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.matchId(match.id)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _onBack(context, state),
            ),
            actions: [
              if (state.isPublishing)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.secondary,
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Timer
                _buildTimer(context, state),

                const SizedBox(height: 16),

                // Score cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildScoreCard(
                          context,
                          name: match.f1Name,
                          score: match.f1Score,
                          advantages: match.f1Adv,
                          penalties: match.f1Pen,
                          color: f1Color,
                          isLeading: match.f1Score > match.f2Score,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l10n.vsLabel,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildScoreCard(
                          context,
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
                ),

                const SizedBox(height: 16),

                // Scoring panel
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fighter selector
                          _buildFighterSelector(
                              context, match, f1Color, f2Color),

                          const SizedBox(height: 20),

                          // Scoring buttons
                          if (state.isRunning) ...[
                            _buildScoringButton(
                              context: context,
                              icon: Icons.sports_mma,
                              label: l10n.takedownSweep,
                              points: '+2',
                              color: colors.primary,
                              onTap: () => notifier.scorePt2(_selectedFighter),
                            ),
                            const SizedBox(height: 10),
                            _buildScoringButton(
                              context: context,
                              icon: Icons.arrow_circle_up,
                              label: l10n.guardPass,
                              points: '+3',
                              color: colors.primary,
                              onTap: () => notifier.scorePt3(_selectedFighter),
                            ),
                            const SizedBox(height: 10),
                            _buildScoringButton(
                              context: context,
                              icon: Icons.circle,
                              label: l10n.mountBackTake,
                              points: '+4',
                              color: colors.secondary,
                              onTap: () => notifier.scorePt4(_selectedFighter),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactButton(
                                    context: context,
                                    label: l10n.advantage,
                                    icon: Icons.add,
                                    color: BJJColors.gold,
                                    onTap: () =>
                                        notifier.scoreAdv(_selectedFighter),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildCompactButton(
                                    context: context,
                                    label: l10n.penalty,
                                    icon: Icons.remove,
                                    color: colors.error,
                                    onTap: () =>
                                        notifier.scorePen(_selectedFighter),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: state.canUndo ? notifier.undo : null,
                                icon: const Icon(Icons.undo, size: 18),
                                label: Text(l10n.undoLastAction),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Status actions
                          _buildStatusActions(context, state, notifier),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimer(BuildContext context, MatchControlState state) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final isLow = state.remainingSeconds <= 30 && state.isRunning;
    final timerColor = isLow ? colors.error : colors.primary;
    final displayText = state.match.status == MatchStatus.canceled
        ? l10n.canceled
        : _formatTime(state.remainingSeconds);

    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          border: Border.all(
            color: timerColor.withOpacity(0.4),
            width: 4,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayText,
                style: TextStyle(
                  color: isLow ? colors.error : colors.onSurface,
                  fontSize:
                      state.match.status == MatchStatus.canceled ? 20 : 40,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(state.match.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _statusLabel(l10n, state.match.status),
                  style: TextStyle(
                    color: _statusColor(state.match.status),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(
    BuildContext context, {
    required String name,
    required int score,
    required int advantages,
    required int penalties,
    required Color color,
    required bool isLeading,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isLeading ? Border.all(color: color, width: 2) : null,
      ),
      child: Column(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: TextStyle(
              color: isLeading ? color : colors.onSurface,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge('A:$advantages', BJJColors.gold),
              const SizedBox(width: 6),
              _buildBadge('P:$penalties', BJJColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildFighterSelector(
      BuildContext context, Match match, Color f1Color, Color f2Color) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFighter = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedFighter == 1 ? f1Color : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  match.f1Name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedFighter == 1
                        ? BJJColors.white
                        : colors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFighter = 2),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedFighter == 2 ? f2Color : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  match.f2Name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedFighter == 2
                        ? BJJColors.white
                        : colors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoringButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String points,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                points,
                style: TextStyle(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusActions(
    BuildContext context,
    MatchControlState state,
    MatchControlNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (state.isWaiting) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: notifier.startMatch,
          icon: const Icon(Icons.play_arrow),
          label: Text(
            l10n.startMatch,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (state.isRunning) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => _confirmFinish(context, notifier),
                child: Text(
                  l10n.finish,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => _confirmCancel(context, notifier),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
                child: Text(
                  l10n.cancel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Finished or canceled — read-only
    return Center(
      child: Text(
        state.match.status == MatchStatus.finished
            ? l10n.matchFinished
            : l10n.matchCanceled,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _confirmFinish(BuildContext context, MatchControlNotifier notifier) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.finishMatchQuestion),
        content: Text(l10n.finishMatchDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.finishMatch();
            },
            child: Text(l10n.finish),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, MatchControlNotifier notifier) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelMatchQuestion),
        content: Text(l10n.cancelMatchDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.goBack),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.cancelMatch();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            child: Text(l10n.cancelMatch),
          ),
        ],
      ),
    );
  }

  void _onBack(BuildContext context, MatchControlState state) {
    if (state.isRunning) {
      final l10n = AppLocalizations.of(context);
      final colors = Theme.of(context).colorScheme;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.leaveMatchQuestion),
          content: Text(l10n.leaveMatchDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.stay),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pop();
              },
              child: Text(
                l10n.leave,
                style: TextStyle(color: colors.error),
              ),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Color _statusColor(MatchStatus status) {
    return switch (status) {
      MatchStatus.waiting => BJJColors.gold,
      MatchStatus.inProgress => BJJColors.green,
      MatchStatus.finished => BJJColors.info,
      MatchStatus.canceled => BJJColors.error,
    };
  }

  String _statusLabel(AppLocalizations l10n, MatchStatus status) {
    return switch (status) {
      MatchStatus.waiting => l10n.statusWaiting,
      MatchStatus.inProgress => l10n.statusInProgress,
      MatchStatus.finished => l10n.statusFinished,
      MatchStatus.canceled => l10n.statusCanceled,
    };
  }
}
