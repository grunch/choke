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
/// Icon-only design with badges (+2/+3/+4) instead of text labels to prevent overflow
class HorizontalScoringView extends ConsumerWidget {
  const HorizontalScoringView({super.key});

  /// Build compact scoring column with modern badge design
  Widget _buildScoringColumn({
    required ColorScheme colors,
    required String badge,
    required int count,
    required VoidCallback? onIncrement,
    required VoidCallback? onDecrement,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Modern badge (no emoji)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: colors.primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Count
        Text(
          count.toString(),
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        // Increment/Decrement buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                onPressed: onIncrement,
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: colors.primary.withOpacity(0.1),
                  foregroundColor: colors.primary,
                ),
              ),
            ),
            const SizedBox(width: 2),
            SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                onPressed: onDecrement,
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: colors.error.withOpacity(0.1),
                  foregroundColor: colors.error,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build ultra-compact advantage/penalty column with emoji
  Widget _buildAdvPenColumn({
    required ColorScheme colors,
    required String emoji,
    required int count,
    required VoidCallback? onIncrement,
    required VoidCallback? onDecrement,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emoji only (save space)
        Text(
          emoji,
          style: const TextStyle(fontSize: 14),
        ),
        // Count (tiny)
        Text(
          count.toString(),
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Buttons (mini)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: IconButton(
                onPressed: onIncrement,
                padding: EdgeInsets.zero,
                iconSize: 10,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: colors.primary.withOpacity(0.1),
                  foregroundColor: colors.primary,
                ),
              ),
            ),
            SizedBox(
              width: 18,
              height: 18,
              child: IconButton(
                onPressed: onDecrement,
                padding: EdgeInsets.zero,
                iconSize: 10,
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: colors.error.withOpacity(0.1),
                  foregroundColor: colors.error,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

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
          // Left panel: Scoring for both fighters (flex 4, more space)
          Expanded(
            flex: 4,
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

          // Right panel: Timer + scores (flex 1, more compact)
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Adaptive font sizes based on available height
                  final scoreSize =
                      (constraints.maxHeight * 0.20).clamp(36.0, 100.0);
                  final timerSize =
                      (constraints.maxHeight * 0.13).clamp(28.0, 70.0);
                  final buttonSize =
                      (constraints.maxHeight * 0.06).clamp(20.0, 32.0);
                  final spacing =
                      (constraints.maxHeight * 0.015).clamp(2.0, 8.0);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Match ID (compact, above score)
                      Text(
                        '#${match.id.substring(0, 5)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize:
                              (constraints.maxHeight * 0.025).clamp(10.0, 14.0),
                          fontWeight: FontWeight.w300,
                        ),
                      ),

                      SizedBox(height: spacing * 0.5),

                      // Fighter 1 score (adaptive)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${match.f1Score}',
                          style: TextStyle(
                            color: f1Color,
                            fontSize: scoreSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      SizedBox(height: spacing),

                      // Control buttons row (pause + undo)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pause/Resume button
                          SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: IconButton(
                              onPressed: state.isRunning
                                  ? () {/* TODO: pause */}
                                  : () {/* TODO: resume */},
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                state.isRunning
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: buttonSize * 0.6,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          SizedBox(width: spacing),

                          // Undo button
                          SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: IconButton(
                              onPressed: state.isRunning
                                  ? () => notifier.undo()
                                  : null,
                              padding: EdgeInsets.zero,
                              icon: Text(
                                '↩️',
                                style: TextStyle(fontSize: buttonSize * 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: spacing * 0.5),

                      // Timer (adaptive)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatTime(state.remainingSeconds),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: timerSize,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),

                      SizedBox(height: spacing),

                      // Fighter 2 score (adaptive)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${match.f2Score}',
                          style: TextStyle(
                            color: f2Color,
                            fontSize: scoreSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fighter name (compact)
              Text(
                name,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              // Scoring columns (fill available space)
              Expanded(
                child: Row(
                  children: [
                    // Column 1: +4 (Mount/Back take)
                    Expanded(
                      child: _buildScoringColumn(
                        badge: '+4',
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

                    const SizedBox(width: 4),

                    // Column 2: +3 (Guard pass)
                    Expanded(
                      child: _buildScoringColumn(
                        badge: '+3',
                        count: pt3Count,
                        onIncrement:
                            isRunning ? () => notifier.scorePt3(fighter) : null,
                        onDecrement: isRunning && pt3Count > 0
                            ? () => notifier.undo()
                            : null,
                        colors: colors,
                      ),
                    ),

                    const SizedBox(width: 4),

                    // Column 3: +2 (Takedown/Sweep)
                    Expanded(
                      child: _buildScoringColumn(
                        badge: '+2',
                        count: pt2Count,
                        onIncrement:
                            isRunning ? () => notifier.scorePt2(fighter) : null,
                        onDecrement: isRunning && pt2Count > 0
                            ? () => notifier.undo()
                            : null,
                        colors: colors,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Advantage/Penalty column (ultra-compact)
                    SizedBox(
                      width: 50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Advantages (🫳 open hand)
                          _buildAdvPenColumn(
                            colors: colors,
                            emoji: '🫳',
                            count: advantages,
                            onIncrement: isRunning
                                ? () => notifier.scoreAdv(fighter)
                                : null,
                            onDecrement: isRunning && advantages > 0
                                ? () => notifier.undo()
                                : null,
                          ),

                          const SizedBox(height: 2),

                          // Penalties (✊ fist)
                          _buildAdvPenColumn(
                            colors: colors,
                            emoji: '✊',
                            count: penalties,
                            onIncrement: isRunning
                                ? () => notifier.scorePen(fighter)
                                : null,
                            onDecrement: isRunning && penalties > 0
                                ? () => notifier.undo()
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
