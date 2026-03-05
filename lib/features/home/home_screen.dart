import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../match/create_match_screen.dart';
import '../match/match_control_screen.dart';
import '../match/models/match.dart';
import '../match/providers/match_control_provider.dart';
import 'providers/home_providers.dart';

/// Parse hex color string (#RRGGBB) to Color with fallback
Color _hexToColor(String hex) {
  try {
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return BJJColors.grey;
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return BJJColors.grey;
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredMatches = ref.watch(filteredMatchListProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: BJJColors.navy,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateMatchScreen()),
          );
        },
        backgroundColor: BJJColors.green,
        child: const Icon(Icons.add, color: BJJColors.white),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: BJJColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.homeSubtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: BJJColors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildFilterChips(context, ref, statusFilter),
            ),

            const SizedBox(height: 16),

            // Match list
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: BJJColors.offWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: filteredMatches.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: filteredMatches.length,
                        itemBuilder: (context, index) {
                          final match = filteredMatches[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildMatchCard(context, ref, match),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, WidgetRef ref, Set<MatchStatus> selected) {
    final l10n = AppLocalizations.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MatchStatus.values.map((status) {
        final isSelected = selected.contains(status);
        return FilterChip(
          label: Text(_statusLabel(l10n, status)),
          selected: isSelected,
          onSelected: (value) {
            final current = Set<MatchStatus>.from(
                ref.read(statusFilterProvider));
            if (value) {
              current.add(status);
            } else {
              current.remove(status);
            }
            ref.read(statusFilterProvider.notifier).state = current;
          },
          selectedColor: _statusColor(status).withOpacity(0.2),
          checkmarkColor: _statusColor(status),
          labelStyle: TextStyle(
            color: isSelected ? _statusColor(status) : BJJColors.grey,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
          backgroundColor: BJJColors.navyDark,
          side: BorderSide(
            color: isSelected
                ? _statusColor(status).withOpacity(0.5)
                : BJJColors.greyDark.withOpacity(0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🥋', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            l10n.noMatchesYet,
            style: const TextStyle(
              color: BJJColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.createNewOne,
            style: TextStyle(
              color: BJJColors.greyDark,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, WidgetRef ref, Match match) {
    final l10n = AppLocalizations.of(context);
    final f1Color = _hexToColor(match.f1Color);
    final f2Color = _hexToColor(match.f2Color);

    return InkWell(
      onTap: () {
        ref.read(activeMatchProvider.notifier).state = match;
        ref.invalidate(matchControlProvider);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MatchControlScreen(match: match),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BJJColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: BJJColors.navy.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top row: match ID + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${match.id}',
                  style: TextStyle(
                    color: BJJColors.greyDark,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(match.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(l10n, match.status),
                    style: TextStyle(
                      color: _statusColor(match.status),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Score row
            Row(
              children: [
                // Fighter 1
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: f1Color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    match.f1Name,
                    style: const TextStyle(
                      color: BJJColors.navy,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${match.f1Score}',
                  style: TextStyle(
                    color: match.f1Score > match.f2Score
                        ? BJJColors.green
                        : BJJColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    l10n.vs,
                    style: TextStyle(
                      color: BJJColors.greyDark,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '${match.f2Score}',
                  style: TextStyle(
                    color: match.f2Score > match.f1Score
                        ? BJJColors.green
                        : BJJColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Expanded(
                  child: Text(
                    match.f2Name,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: BJJColors.navy,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: f2Color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),

            // Advantages/Penalties row
            if (match.f1Adv > 0 ||
                match.f2Adv > 0 ||
                match.f1Pen > 0 ||
                match.f2Pen > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (match.f1Adv > 0)
                        _buildSmallBadge(
                            'A:${match.f1Adv}', BJJColors.gold),
                      if (match.f1Pen > 0) ...[
                        const SizedBox(width: 4),
                        _buildSmallBadge(
                            'P:${match.f1Pen}', BJJColors.error),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      if (match.f2Adv > 0)
                        _buildSmallBadge(
                            'A:${match.f2Adv}', BJJColors.gold),
                      if (match.f2Pen > 0) ...[
                        const SizedBox(width: 4),
                        _buildSmallBadge(
                            'P:${match.f2Pen}', BJJColors.error),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
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
