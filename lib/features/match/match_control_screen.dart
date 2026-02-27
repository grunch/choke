import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_theme.dart';
import 'models/match.dart';
import 'providers/match_control_provider.dart';

/// Parse hex color string (#RRGGBB) to Color
Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
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
  ConsumerState<MatchControlScreen> createState() =>
      _MatchControlScreenState();
}

class _MatchControlScreenState extends ConsumerState<MatchControlScreen> {
  /// Currently selected fighter for scoring: 1 or 2
  int _selectedFighter = 1;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchControlProvider(widget.match));
    final notifier = ref.read(matchControlProvider(widget.match).notifier);
    final match = state.match;
    final f1Color = _hexToColor(match.f1Color);
    final f2Color = _hexToColor(match.f2Color);

    return Scaffold(
      backgroundColor: BJJColors.navy,
      appBar: AppBar(
        title: Text('Match #${match.id}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _onBack(context, state),
        ),
        actions: [
          if (state.isPublishing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BJJColors.gold,
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
                        color: BJJColors.navyDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'VS',
                        style: TextStyle(
                          color: BJJColors.white,
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
                decoration: const BoxDecoration(
                  color: BJJColors.offWhite,
                  borderRadius: BorderRadius.only(
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
                      _buildFighterSelector(match, f1Color, f2Color),

                      const SizedBox(height: 20),

                      // Scoring buttons
                      if (state.isRunning) ...[
                        _buildScoringButton(
                          icon: Icons.sports_mma,
                          label: 'Takedown / Sweep',
                          points: '+2',
                          color: BJJColors.green,
                          onTap: () =>
                              notifier.scorePt2(_selectedFighter),
                        ),
                        const SizedBox(height: 10),
                        _buildScoringButton(
                          icon: Icons.arrow_circle_up,
                          label: 'Guard Pass',
                          points: '+3',
                          color: BJJColors.green,
                          onTap: () =>
                              notifier.scorePt3(_selectedFighter),
                        ),
                        const SizedBox(height: 10),
                        _buildScoringButton(
                          icon: Icons.circle,
                          label: 'Mount / Back Take',
                          points: '+4',
                          color: BJJColors.gold,
                          onTap: () =>
                              notifier.scorePt4(_selectedFighter),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactButton(
                                label: 'Advantage',
                                icon: Icons.add,
                                color: BJJColors.gold,
                                onTap: () =>
                                    notifier.scoreAdv(_selectedFighter),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildCompactButton(
                                label: 'Penalty',
                                icon: Icons.remove,
                                color: BJJColors.error,
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
                            label: const Text('Undo Last Action'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BJJColors.grey,
                              side: BorderSide(
                                color: state.canUndo
                                    ? BJJColors.grey
                                    : BJJColors.greyDark,
                              ),
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
  }

  Widget _buildTimer(BuildContext context, MatchControlState state) {
    final isLow = state.remainingSeconds <= 30 && state.isRunning;
    final timerColor = isLow ? BJJColors.error : BJJColors.green;
    final displayText = state.match.status == MatchStatus.canceled
        ? 'CANCELED'
        : _formatTime(state.remainingSeconds);

    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: BJJColors.navyDark,
          border: Border.all(
            color: timerColor.withValues(alpha: 0.4),
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
                  color: isLow ? BJJColors.error : BJJColors.white,
                  fontSize: state.match.status == MatchStatus.canceled ? 20 : 40,
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
                  color: _statusColor(state.match.status)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _statusLabel(state.match.status),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BJJColors.navyDark,
        borderRadius: BorderRadius.circular(16),
        border: isLeading
            ? Border.all(color: color, width: 2)
            : null,
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
            style: const TextStyle(
              color: BJJColors.grey,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: TextStyle(
              color: isLeading ? color : BJJColors.white,
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildFighterSelector(Match match, Color f1Color, Color f2Color) {
    return Container(
      decoration: BoxDecoration(
        color: BJJColors.white,
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
                  color: _selectedFighter == 1
                      ? f1Color
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  match.f1Name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedFighter == 1
                        ? BJJColors.white
                        : BJJColors.navy,
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
                  color: _selectedFighter == 2
                      ? f2Color
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  match.f2Name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedFighter == 2
                        ? BJJColors.white
                        : BJJColors.navy,
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
    required IconData icon,
    required String label,
    required String points,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: BJJColors.navy,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                points,
                style: const TextStyle(
                  color: BJJColors.white,
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
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: BJJColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
    if (state.isWaiting) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: notifier.startMatch,
          icon: const Icon(Icons.play_arrow),
          label: const Text(
            'Start Match',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: BJJColors.green,
            foregroundColor: BJJColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: BJJColors.green,
                  foregroundColor: BJJColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Finish',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                  foregroundColor: BJJColors.error,
                  side: const BorderSide(color: BJJColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
            ? 'Match Finished'
            : 'Match Canceled',
        style: const TextStyle(
          color: BJJColors.greyDark,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _confirmFinish(BuildContext context, MatchControlNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BJJColors.navyDark,
        title: const Text('Finish Match?',
            style: TextStyle(color: BJJColors.white)),
        content: const Text(
          'This will end the match and publish the final score.',
          style: TextStyle(color: BJJColors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: BJJColors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.finishMatch();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BJJColors.green,
            ),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, MatchControlNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BJJColors.navyDark,
        title: const Text('Cancel Match?',
            style: TextStyle(color: BJJColors.white)),
        content: const Text(
          'This will cancel the match. Scores will not be saved.',
          style: TextStyle(color: BJJColors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go Back',
                style: TextStyle(color: BJJColors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.cancelMatch();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BJJColors.error,
            ),
            child: const Text('Cancel Match'),
          ),
        ],
      ),
    );
  }

  void _onBack(BuildContext context, MatchControlState state) {
    if (state.isRunning) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: BJJColors.navyDark,
          title: const Text('Leave Match?',
              style: TextStyle(color: BJJColors.white)),
          content: const Text(
            'The match is still in progress. Are you sure you want to leave?',
            style: TextStyle(color: BJJColors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Stay',
                  style: TextStyle(color: BJJColors.green)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pop();
              },
              child: const Text('Leave',
                  style: TextStyle(color: BJJColors.error)),
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

  String _statusLabel(MatchStatus status) {
    return switch (status) {
      MatchStatus.waiting => 'Waiting',
      MatchStatus.inProgress => 'In Progress',
      MatchStatus.finished => 'Finished',
      MatchStatus.canceled => 'Canceled',
    };
  }
}
