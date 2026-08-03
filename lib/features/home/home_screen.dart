import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../announcements/announcement_providers.dart';
import '../announcements/announcements_screen.dart';
import '../../services/deep_links/share_link.dart';
import '../../services/key_management/key_manager.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/match_card.dart';
import '../../shared/widgets/qr_dialog.dart';
import '../../shared/widgets/status_filter_bar.dart';
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
    // `valueOrNull`, not a `when`: the identity is read from storage and the
    // list must not wait on it. A card that appears before the key does simply
    // has no share icon for that frame.
    final npub = ref.watch(npubProvider).valueOrNull;
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
                  // Absent unless the project has actually said something —
                  // see the widget below.
                  const _AnnouncementsBell(),
                  // The same code the scoreboard offers, for the board on the
                  // other side of it: there it hands over the organizer being
                  // watched, here it hands over this app's own. Same icon,
                  // same dialog, same strings — a room pointing a camera at it
                  // cannot tell whose phone is holding it up, and should not
                  // have to.
                  //
                  // Hidden until an identity exists, like the cards' share
                  // icon: a board link with nobody in it names nothing.
                  if (npub != null)
                    IconButton(
                      onPressed: () => _showQr(context, npub),
                      tooltip: l10n.showQr,
                      color: tk.muted,
                      icon: const Icon(Icons.qr_code_2),
                    ),
                ],
              ),
            ),

            // Status filter cards
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: StatusFilterBar(
                matches: allMatches,
                selected: statusFilter,
                onToggle: (status) => _toggleStatus(ref, status),
              ),
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
                      // Deliberately not shadowing `context` with the builder's
                      // own: the share sheet asks its context for a RenderBox
                      // to anchor a popover to, and a builder inside a
                      // ListView hands back a RenderSliverList. The page's
                      // context is a box, and is the right anchor anyway — the
                      // sheet belongs to the screen, not to one row of it.
                      itemBuilder: (_, index) {
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
                            // The organizer's own feed, so the link names this
                            // app's identity: the same icon and the same link
                            // the scoreboard hands out, offered from the screen
                            // the person who created the fight is already on.
                            //
                            // No npub means no key generated yet, and a link
                            // with nobody in it names nothing — the card then
                            // renders exactly as it did before there was a
                            // share icon at all.
                            onShare: npub == null
                                ? null
                                : () => shareMatchLink(
                                      context,
                                      ref,
                                      npub: npub,
                                      matchId: match.id,
                                      logTag: 'HomeScreen',
                                    ),
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

  /// This app's own board, as a code for the room.
  ///
  /// The organizer holds up or projects it and the crowd points a camera at
  /// it — nothing typed, no key exchanged. Deliberately the same dialog and the
  /// same strings the scoreboard uses (`scoreboardQrTitle` / `scoreboardQrHint`)
  /// rather than new copy: it is the same board link, and the only difference
  /// is whose. Not the account screen's QR, which carries the raw public key
  /// for importing an identity — a different thing that happens to be square.
  void _showQr(BuildContext context, String npub) {
    final l10n = AppLocalizations.of(context);
    showQrDialog(
      context,
      title: l10n.scoreboardQrTitle,
      data: liveBoardShareUrl(npub),
      caption: l10n.scoreboardQrHint,
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

  void _toggleStatus(WidgetRef ref, MatchStatus status) {
    final current = Set<MatchStatus>.from(ref.read(statusFilterProvider));
    if (!current.remove(status)) current.add(status);
    ref.read(statusFilterProvider.notifier).state = current;
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

/// The bell, and only when there is something behind it.
///
/// Absent — not greyed out, not badged with a zero — while the inbox is
/// empty. A permanent bell is a piece of chrome advertising that a channel
/// exists, which is a claim on the top bar this feature has not earned; the
/// dot is the whole notification (§4.3).
class _AnnouncementsBell extends ConsumerWidget {
  const _AnnouncementsBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tk = ChokeTokens.of(context);
    final inbox = ref.watch(announcementInboxProvider);
    if (inbox.entries.isEmpty) return const SizedBox.shrink();

    return IconButton(
      tooltip: l10n.announcementsBell,
      color: tk.muted,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (inbox.hasUnread)
            Positioned(
              right: -1,
              top: -1,
              // Labelled like the dot on each item: the tooltip says what the
              // bell opens, and nothing else here says there is something
              // unread behind it. A coloured circle says that to exactly one
              // kind of user.
              child: Semantics(
                label: l10n.announcementsUnread,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tk.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
