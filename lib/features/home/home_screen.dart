import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/match_card.dart';
import '../match/create_match_screen.dart';
import '../match/match_control_screen.dart';
import '../match/models/match.dart';
import '../match/providers/match_control_provider.dart';
import 'providers/home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredMatches = ref.watch(filteredMatchListProvider);
    final allMatches = ref.watch(recentMatchListProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tk = ChokeTokens.of(context);

    return Scaffold(
      // Lift the FAB above the translucent nav bar (extendBody lets the
      // body — and this inner Scaffold — extend beneath it).
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 9,
          right: 4,
        ),
        child: _buildFab(context, tk),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: logo + title + subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    // Tighter inset so the mark fills ~78% of the tile — the
                    // usual icon-in-tile proportion. At the previous 9 it read
                    // as a small mark floating in a large tile.
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: BJJColors.greyLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset('assets/branding/choke-c-logo.png'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.appTitle,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -.5,
                            height: 1.05,
                          ),
                        ),
                        Text(
                          l10n.homeSubtitle,
                          style: TextStyle(fontSize: 12.5, color: tk.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Status filter cards
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child:
                  _buildStatusCards(context, ref, statusFilter, allMatches, tk),
            ),

            // Match list
            Expanded(
              child: filteredMatches.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        2,
                        20,
                        MediaQuery.of(context).padding.bottom + 80,
                      ),
                      itemCount: filteredMatches.length,
                      itemBuilder: (context, index) {
                        final match = filteredMatches[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 11),
                          child: MatchCard(
                            match: match,
                            onTap: () {
                              ref.read(activeMatchProvider.notifier).state =
                                  match;
                              ref.invalidate(matchControlProvider);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MatchControlScreen(match: match),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context, ChokeTokens tk) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateMatchScreen()),
        );
      },
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: tk.gradient,
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(
              color: tk.gradTop.withOpacity(.4),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(Icons.add, color: tk.onGrad, size: 28),
      ),
    );
  }

  Widget _buildStatusCards(
    BuildContext context,
    WidgetRef ref,
    Set<MatchStatus> selected,
    List<Match> allMatches,
    ChokeTokens tk,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in MatchStatus.values)
          _buildStatusCard(context, ref, status, selected, allMatches, tk),
      ],
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    WidgetRef ref,
    MatchStatus status,
    Set<MatchStatus> selected,
    List<Match> allMatches,
    ChokeTokens tk,
  ) {
    final l10n = AppLocalizations.of(context);
    final isSelected = selected.contains(status);
    final count = allMatches.where((m) => m.status == status).length;
    final color = matchStatusAccent(tk, status);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${matchStatusLabel(l10n, status)}: $count',
      child: GestureDetector(
        onTap: () {
          final current = Set<MatchStatus>.from(ref.read(statusFilterProvider));
          if (isSelected) {
            current.remove(status);
          } else {
            current.add(status);
          }
          ref.read(statusFilterProvider.notifier).state = current;
        },
        child: Container(
          // Enforce the 44px minimum interactive height for an accessible tap
          // target; the visible layout and styling stay compact.
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(.12) : tk.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color.withOpacity(.5) : tk.cardBorder,
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
                  color: isSelected ? color : tk.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  color: count > 0 ? color : tk.faint,
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

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/branding/home-mascot.png',
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noMatchesYet,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.createNewOne,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

}
