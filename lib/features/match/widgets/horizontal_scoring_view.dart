import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/match_control_provider.dart';

/// Horizontal landscape scoring interface for dual-fighter operation
///
/// Implements the specification from docs/specs/horizontal-scoring-mode.md
///
/// Layout:
/// - Left panel (80% / flex: 4): Dual scoring controls
/// - Right panel (20% / flex: 1): Timer, scores, match controls
class HorizontalScoringView extends ConsumerWidget {
  const HorizontalScoringView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchControlProvider);
    final notifier = ref.read(matchControlProvider.notifier);
    final match = state.match;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Parse fighter colors with fallback
    final f1Color = _parseColor(match.f1Color, BJJColors.green);
    final f2Color = _parseColor(match.f2Color, BJJColors.gold);

    return SafeArea(
      child: Row(
        children: [
          // Left panel: Scoring (80% width, flex: 4)
          Expanded(
            flex: 4,
            child: Container(
              color: colors.surface,
              child: Column(
                children: [
                  // Fighter 1 scoring section (top half)
                  Expanded(
                    child: _buildFighterScoringPanel(
                      context: context,
                      fighter: 1,
                      name: match.f1Name,
                      color: f1Color,
                      pt4: match.f1Pt4,
                      pt3: match.f1Pt3,
                      pt2: match.f1Pt2,
                      adv: match.f1Adv,
                      pen: match.f1Pen,
                      notifier: notifier,
                      colors: colors,
                      isRunning: state.isRunning,
                    ),
                  ),

                  // Divider between fighters
                  Container(
                    height: 2,
                    color: colors.outline.withOpacity(0.3),
                  ),

                  // Fighter 2 scoring section (bottom half)
                  Expanded(
                    child: _buildFighterScoringPanel(
                      context: context,
                      fighter: 2,
                      name: match.f2Name,
                      color: f2Color,
                      pt4: match.f2Pt4,
                      pt3: match.f2Pt3,
                      pt2: match.f2Pt2,
                      adv: match.f2Adv,
                      pen: match.f2Pen,
                      notifier: notifier,
                      colors: colors,
                      isRunning: state.isRunning,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right panel: Timer + scores (20% width, flex: 1)
          Expanded(
            flex: 1,
            child: _buildTimerPanel(
              context: context,
              match: match,
              state: state,
              notifier: notifier,
              f1Color: f1Color,
              f2Color: f2Color,
            ),
          ),
        ],
      ),
    );
  }

  /// Parse hex color string (#RRGGBB) to Color with fallback
  Color _parseColor(String hex, Color fallback) {
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

  /// Build fighter scoring panel (one horizontal row with all controls)
  Widget _buildFighterScoringPanel({
    required BuildContext context,
    required int fighter,
    required String name,
    required Color color,
    required int pt4,
    required int pt3,
    required int pt2,
    required int adv,
    required int pen,
    required MatchControlNotifier notifier,
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
              // Fighter name (14px bold)
              Text(
                name,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              // Scoring row (fill available space)
              Expanded(
                child: Row(
                  children: [
                    // +4 column
                    Expanded(
                      child: _buildScoringColumn(
                        badge: '+4',
                        count: pt4,
                        onIncrement:
                            isRunning ? () => notifier.scorePt4(fighter) : null,
                        onDecrement:
                            isRunning && pt4 > 0 ? () => notifier.undo() : null,
                        colors: colors,
                      ),
                    ),

                    const SizedBox(width: 4),

                    // +3 column
                    Expanded(
                      child: _buildScoringColumn(
                        badge: '+3',
                        count: pt3,
                        onIncrement:
                            isRunning ? () => notifier.scorePt3(fighter) : null,
                        onDecrement:
                            isRunning && pt3 > 0 ? () => notifier.undo() : null,
                        colors: colors,
                      ),
                    ),

                    const SizedBox(width: 4),

                    // +2 column
                    Expanded(
                      child: _buildScoringColumn(
                        badge: '+2',
                        count: pt2,
                        onIncrement:
                            isRunning ? () => notifier.scorePt2(fighter) : null,
                        onDecrement:
                            isRunning && pt2 > 0 ? () => notifier.undo() : null,
                        colors: colors,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Advantage/Penalty column (fixed width: 50px)
                    SizedBox(
                      width: 50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Advantage (🫳 open hand)
                          _buildAdvPenColumn(
                            emoji: '🫳',
                            count: adv,
                            onIncrement: isRunning
                                ? () => notifier.scoreAdv(fighter)
                                : null,
                            onDecrement: isRunning && adv > 0
                                ? () => notifier.undo()
                                : null,
                            colors: colors,
                          ),

                          const SizedBox(height: 2),

                          // Penalty (✊ fist)
                          _buildAdvPenColumn(
                            emoji: '✊',
                            count: pen,
                            onIncrement: isRunning
                                ? () => notifier.scorePen(fighter)
                                : null,
                            onDecrement: isRunning && pen > 0
                                ? () => notifier.undo()
                                : null,
                            colors: colors,
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

  /// Build modern scoring column (+4, +3, +2)
  ///
  /// Components (top to bottom):
  /// - Badge with rounded corners and border
  /// - Count number (24px bold)
  /// - [+] and [-] buttons (30×30)
  Widget _buildScoringColumn({
    required String badge,
    required int count,
    required VoidCallback? onIncrement,
    required VoidCallback? onDecrement,
    required ColorScheme colors,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge (spec: 8px h-padding, 3px v-padding, 6px radius)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),

        const SizedBox(height: 2),

        // Count (spec: 24px bold)
        Text(
          count.toString(),
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 2),

        // Buttons (spec: 30×30, 2px gap)
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

  /// Build ultra-compact advantage/penalty column
  ///
  /// Components (top to bottom):
  /// - Emoji (🫳 or ✊, 14px)
  /// - Count number (14px bold)
  /// - [+] and [-] buttons (18×18 mini)
  Widget _buildAdvPenColumn({
    required String emoji,
    required int count,
    required VoidCallback? onIncrement,
    required VoidCallback? onDecrement,
    required ColorScheme colors,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emoji (spec: 14px)
        Text(
          emoji,
          style: const TextStyle(fontSize: 14),
        ),

        // Count (spec: 14px bold)
        Text(
          count.toString(),
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Mini buttons (spec: 18×18, no gap)
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

  /// Build timer panel (right side, black background)
  ///
  /// Order from top to bottom (spec section 2.3):
  /// 1. Match ID badge
  /// 2. Fighter 1 score (colored background)
  /// 3. Control buttons (pause + undo, horizontal row)
  /// 4. Timer
  /// 5. Fighter 2 score (colored background)
  Widget _buildTimerPanel({
    required BuildContext context,
    required dynamic match,
    required dynamic state,
    required MatchControlNotifier notifier,
    required Color f1Color,
    required Color f2Color,
  }) {
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Adaptive sizes (spec section 4.1)
          final scoreSize = (constraints.maxHeight * 0.20).clamp(36.0, 100.0);
          final timerSize = (constraints.maxHeight * 0.13).clamp(28.0, 70.0);
          final buttonSize = (constraints.maxHeight * 0.06).clamp(20.0, 32.0);
          final spacing = (constraints.maxHeight * 0.015).clamp(2.0, 8.0);

          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Match ID badge (spec section 3.5)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${match.id.substring(0, 5)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: (constraints.maxHeight * 0.025).clamp(9.0, 12.0),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              SizedBox(height: spacing * 0.5),

              // 2. Fighter 1 score (spec section 3.6)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: scoreSize * 0.3,
                  vertical: scoreSize * 0.15,
                ),
                decoration: BoxDecoration(
                  color: f1Color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${match.f1Score}',
                  style: TextStyle(
                    color: f1Color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontSize: scoreSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(height: spacing),

              // 3. Control buttons row (spec section 3.7)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pause/Play button
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: IconButton(
                      onPressed: state.isRunning
                          ? () {/* TODO: pause */}
                          : () {/* TODO: resume */},
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        state.isRunning ? Icons.pause : Icons.play_arrow,
                        size: buttonSize * 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  SizedBox(width: spacing),

                  // Undo button (with visual feedback when active)
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: Container(
                      decoration: BoxDecoration(
                        color: state.isRunning
                            ? Colors.white.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: IconButton(
                        onPressed:
                            state.isRunning ? () => notifier.undo() : null,
                        padding: EdgeInsets.zero,
                        icon: Text(
                          '↩️',
                          style: TextStyle(fontSize: buttonSize * 0.55),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: spacing * 0.5),

              // 4. Timer (spec section 3.8)
              Text(
                _formatTime(state.remainingSeconds),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: timerSize,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),

              SizedBox(height: spacing),

              // 5. Fighter 2 score (spec section 3.6)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: scoreSize * 0.3,
                  vertical: scoreSize * 0.15,
                ),
                decoration: BoxDecoration(
                  color: f2Color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${match.f2Score}',
                  style: TextStyle(
                    color: f2Color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontSize: scoreSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
