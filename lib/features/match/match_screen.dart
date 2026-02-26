import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BJJColors.navy,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BJJColors.navyDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.arrow_back, color: BJJColors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Match',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: BJJColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gi Match • 5 min rounds',
                          style: TextStyle(
                            color: BJJColors.grey.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BJJColors.navyDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.more_vert, color: BJJColors.white),
                  ),
                ],
              ),
            ),

            // Timer Section
            Center(
              child: Column(
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BJJColors.navyDark,
                      border: Border.all(
                        color: BJJColors.green.withValues(alpha: 0.3),
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '04:32',
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  color: BJJColors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: BJJColors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Round 1 of 3',
                              style: TextStyle(
                                color: BJJColors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Control buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        icon: Icons.pause,
                        label: 'Pause',
                        onTap: () {},
                      ),
                      const SizedBox(width: 16),
                      _buildControlButton(
                        icon: Icons.stop,
                        label: 'End',
                        isDestructive: true,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Bottom Sheet - Scoring
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Score Board
                      Row(
                        children: [
                          Expanded(
                            child: _buildScoreCard(
                              context,
                              athlete: 'Athlete A',
                              score: '4',
                              advantages: '1',
                              penalties: '0',
                              isLeading: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: BJJColors.navy,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'VS',
                              style: TextStyle(
                                color: BJJColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildScoreCard(
                              context,
                              athlete: 'Athlete B',
                              score: '2',
                              advantages: '0',
                              penalties: '1',
                              isLeading: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Scoring Actions
                      Text(
                        'Score Points',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: BJJColors.navy,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Takedown / Sweep
                      _buildScoreAction(
                        context,
                        icon: Icons.sports_mma,
                        title: 'Takedown / Sweep',
                        points: '+2',
                        color: BJJColors.green,
                      ),
                      const SizedBox(height: 12),

                      // Guard Pass
                      _buildScoreAction(
                        context,
                        icon: Icons.arrow_circle_up,
                        title: 'Guard Pass',
                        points: '+3',
                        color: BJJColors.green,
                      ),
                      const SizedBox(height: 12),

                      // Mount / Back
                      _buildScoreAction(
                        context,
                        icon: Icons.circle,
                        title: 'Mount / Back Take',
                        points: '+4',
                        color: BJJColors.gold,
                      ),
                      const SizedBox(height: 12),

                      // Submission
                      _buildScoreAction(
                        context,
                        icon: Icons.emoji_events,
                        title: 'Submission',
                        points: 'WIN',
                        color: BJJColors.gold,
                        isWin: true,
                      ),
                      const SizedBox(height: 24),

                      // Secondary Actions
                      Row(
                        children: [
                          Expanded(
                            child: _buildSecondaryAction(
                              context,
                              icon: Icons.add,
                              label: 'Advantage',
                              color: BJJColors.gold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSecondaryAction(
                              context,
                              icon: Icons.remove,
                              label: 'Penalty',
                              color: const Color(0xFFD32F2F),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isDestructive
              ? const Color(0xFFD32F2F).withValues(alpha: 0.2)
              : BJJColors.navyDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? const Color(0xFFD32F2F) : BJJColors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color:
                    isDestructive ? const Color(0xFFD32F2F) : BJJColors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(
    BuildContext context, {
    required String athlete,
    required String score,
    required String advantages,
    required String penalties,
    required bool isLeading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BJJColors.white,
        borderRadius: BorderRadius.circular(20),
        border: isLeading ? Border.all(color: BJJColors.green, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: BJJColors.navy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            athlete,
            style: const TextStyle(color: BJJColors.greyDark, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            score,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: isLeading ? BJJColors.green : BJJColors.navy,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatBadge('A: $advantages', BJJColors.gold),
              const SizedBox(width: 8),
              _buildStatBadge('P: $penalties', const Color(0xFFD32F2F)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildScoreAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String points,
    required Color color,
    bool isWin = false,
  }) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: BJJColors.navy,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                points,
                style: TextStyle(
                  color: isWin ? BJJColors.navy : BJJColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BJJColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
