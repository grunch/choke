import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
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

/// Format seconds as m:ss
String _formatTime(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Horizontal layout optimized for fast dual-fighter scoring
/// Follows the mockup design with 3 scoring columns + advantage/penalty per fighter
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

    final f1Color = _hexToColor(match.f1Color, BJJColors.green);
    final f2Color = _hexToColor(match.f2Color, BJJColors.gold);

    return SafeArea(
      child: Row(
        children: [
          // Left panel: Scoring for both fighters
          Expanded(
            flex: 2,
            child: Container(
              color: colors.surface,
              child: Column(
                children: [
                  // Fighter 1
                  Expanded(
                    child: _buildFighterPanel(
                      context: context,
                      fighter: 1,
                      name: match.f1Name,
                      color: f1Color,
                      pt4Count: match.f1Pt4,
                      pt3Count: match.f1Pt3,
                      pt2Count: match.f1Pt2,
                      advantages: match.f1Adv,
                      penalties: match.f1Pen,
                      notifier: notifier,
                      l10n: l10n,
                      colors: colors,
                      isRunning: state.isRunning,
                    ),
                  ),

                  // Divider
                  Container(
                    height: 2,
                    color: colors.outline.withOpacity(0.3),
                  ),

                  // Fighter 2
                  Expanded(
                    child: _buildFighterPanel(
                      context: context,
                      fighter: 2,
                      name: match.f2Name,
                      color: f2Color,
                      pt4Count: match.f2Pt4,
                      pt3Count: match.f2Pt3,
                      pt2Count: match.f2Pt2,
                      advantages: match.f2Adv,
                      penalties: match.f2Pen,
                      notifier: notifier,
                      l10n: l10n,
                      colors: colors,
                      isRunning: state.isRunning,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right panel: Timer + controls
          Container(
            width: 300,
            color: Colors.black,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Fighter 1 score (large)
                Text(
                  '${match.f1Score}',
                  style: TextStyle(
                    color: f1Color,
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 24),

                // Timer
                Text(
                  _formatTime(state.remainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),

                const SizedBox(height: 24),

                // Pause/Reset controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pause/Resume
                    IconButton(
                      onPressed: state.isRunning
                          ? () {/* TODO: pause */}
                          : () {/* TODO: resume */},
                      icon: Icon(
                        state.isRunning ? Icons.pause : Icons.play_arrow,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Timer adjust buttons
                    IconButton(
                      onPressed: () {/* TODO: +1 min */},
                      icon: const Icon(
                        Icons.add,
                        size: 32,
                        color: Colors.white70,
                      ),
                    ),
                    const Icon(Icons.timer, size: 32, color: Colors.white70),
                    IconButton(
                      onPressed: () {/* TODO: -1 min */},
                      icon: const Icon(
                        Icons.remove,
                        size: 32,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Reset/Power
                    IconButton(
                      onPressed: () {/* TODO: reset */},
                      icon: const Icon(
                        Icons.power_settings_new,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Fighter 2 score (large)
                Text(
                  '${match.f2Score}',
                  style: TextStyle(
                    color: f2Color,
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFighterPanel({
    required BuildContext context,
    required int fighter,
    required String name,
    required Color color,
    required int pt4Count,
    required int pt3Count,
    required int pt2Count,
    required int advantages,
    required int penalties,
    required MatchControlNotifier notifier,
    required AppLocalizations l10n,
    required ColorScheme colors,
    required bool isRunning,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fighter name
          Text(
            name,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          // Scoring columns
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                children: [
                  // Column 1: +4 (Mount/Back take)
                  Expanded(
                    child: _buildScoringColumn(
                      label: l10n.mountBackTake,
                      points: 4,
                      count: pt4Count,
                      onIncrement:
                          isRunning ? () => notifier.scorePt4(fighter) : null,
                      onDecrement: isRunning && pt4Count > 0
                          ? () {
                              // Decrement by calling undo until pt4 decreases
                              // This is a simplified approach - ideally we'd have a dedicated decrement method
                              notifier.undo();
                            }
                          : null,
                      colors: colors,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Column 2: +3 (Guard pass)
                  Expanded(
                    child: _buildScoringColumn(
                      label: l10n.guardPass,
                      points: 3,
                      count: pt3Count,
                      onIncrement:
                          isRunning ? () => notifier.scorePt3(fighter) : null,
                      onDecrement: isRunning && pt3Count > 0
                          ? () => notifier.undo()
                          : null,
                      colors: colors,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Column 3: +2 (Takedown/Sweep)
                  Expanded(
                    child: _buildScoringColumn(
                      label: l10n.takedownSweep,
                      points: 2,
                      count: pt2Count,
                      onIncrement:
                          isRunning ? () => notifier.scorePt2(fighter) : null,
                      onDecrement: isRunning && pt2Count > 0
                          ? () => notifier.undo()
                          : null,
                      colors: colors,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Advantage/Penalty column
                  SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Advantages
                        Text(
                          l10n.advantage,
                          style: TextStyle(
                            color: colors.onSurface.withOpacity(0.7),
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$advantages',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSmallButton(
                              icon: Icons.add,
                              color: BJJColors.gold,
                              onPressed: isRunning
                                  ? () => notifier.scoreAdv(fighter)
                                  : null,
                            ),
                            const SizedBox(width: 2),
                            _buildSmallButton(
                              icon: Icons.remove,
                              color: Colors.red,
                              onPressed: isRunning && advantages > 0
                                  ? () => notifier.undo()
                                  : null,
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Penalties
                        Text(
                          l10n.penalty,
                          style: TextStyle(
                            color: colors.onSurface.withOpacity(0.7),
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$penalties',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSmallButton(
                              icon: Icons.add,
                              color: BJJColors.gold,
                              onPressed: isRunning
                                  ? () => notifier.scorePen(fighter)
                                  : null,
                            ),
                            _buildSmallButton(
                              icon: Icons.remove,
                              color: Colors.red,
                              onPressed: isRunning && penalties > 0
                                  ? () => notifier.undo()
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoringColumn({
    required String label,
    required int points,
    required int count,
    required VoidCallback? onIncrement,
    required VoidCallback? onDecrement,
    required ColorScheme colors,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label (compact)
        SizedBox(
          height: 28,
          child: Text(
            label,
            style: TextStyle(
              color: colors.onSurface.withOpacity(0.7),
              fontSize: 9,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        const SizedBox(height: 4),

        // Count (reduced)
        Text(
          '$count',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 4),

        // Increment/Decrement buttons (smaller)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildScoringButton(
              label: '+',
              points: points,
              color: Colors.blue,
              onPressed: onIncrement,
            ),
            const SizedBox(width: 2),
            _buildScoringButton(
              label: '-',
              points: null,
              color: Colors.red,
              onPressed: onDecrement,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScoringButton({
    required String label,
    required int? points,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 38,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (points != null)
              Text(
                '$points',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        child: Icon(icon, size: 14),
      ),
    );
  }
}
