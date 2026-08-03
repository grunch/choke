import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:choke/l10n/generated/app_localizations.dart';

import '../../shared/theme/app_theme.dart';
import 'announcement_inbox.dart';
import 'announcement_providers.dart';
import 'models/announcement.dart';

/// What the project has said lately, newest first.
///
/// Nothing here interrupts and nothing here is a form: the screen is reached
/// from the bell, an item is read by opening it, and a swipe is how it goes
/// away. A referee opening the app between matches never passes through it.
class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tk = ChokeTokens.of(context);
    final entries = ref.watch(announcementInboxProvider).entries;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.announcementsTitle)),
      body: SafeArea(
        child: entries.isEmpty
            ? _EmptyState(tk: tk)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _AnnouncementCard(
                  entry: entries[index],
                  tk: tk,
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tk});

  final ChokeTokens tk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 44, color: tk.faint),
            const SizedBox(height: 14),
            Text(
              l10n.announcementsEmpty,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            // The empty state says what the channel is for, because an empty
            // list otherwise reads as something being broken (§4.3).
            Text(
              l10n.announcementsEmptyDetail,
              style: TextStyle(fontSize: 13, color: tk.muted, height: 1.35),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard({required this.entry, required this.tk});

  final AnnouncementEntry entry;
  final ChokeTokens tk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final text = entry.announcement.textFor(locale);
    final inbox = ref.read(announcementInboxProvider.notifier);

    return Semantics(
      // Swiping is the only way to dismiss, and a swipe is not something
      // every user can perform. This exposes the same action to assistive
      // technology, which otherwise has no route to it at all.
      onDismiss: () => inbox.dismiss(entry.address),
      child: _dismissible(context, l10n, text, inbox),
    );
  }

  Widget _dismissible(
    BuildContext context,
    AppLocalizations l10n,
    AnnouncementText text,
    AnnouncementInbox inbox,
  ) {
    return Dismissible(
      key: ValueKey(entry.address),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => inbox.dismiss(entry.address),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: tk.card,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              l10n.announcementsDismiss,
              style: TextStyle(color: tk.muted, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline, color: tk.muted, size: 20),
          ],
        ),
      ),
      child: InkWell(
        onTap: () => inbox.markRead(entry.address),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          decoration: BoxDecoration(
            color: tk.card,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: tk.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!entry.isRead) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      // Labelled, because a coloured dot says nothing to a
                      // screen reader — and unread is the only state this
                      // screen actually tracks.
                      child: Semantics(
                        label: l10n.announcementsUnread,
                        child: _UnreadDot(color: tk.accent),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      text.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            entry.isRead ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _relativeDate(l10n, entry.announcement.createdAt),
                    style: TextStyle(fontSize: 11.5, color: tk.faint),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Plain text, always. No markup is parsed and no link inside the
              // body is detected: the sender is trusted with authorship, not
              // with rendering arbitrary things inside the app (§2.2).
              Text(
                text.body,
                style: TextStyle(fontSize: 13.5, color: tk.muted, height: 1.35),
              ),
              if (entry.announcement.url != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _open(entry.announcement, inbox),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(l10n.announcementsOpen),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Open the link, and count that as having read it.
  ///
  /// Externally, through `url_launcher`, as every other outbound link in this
  /// app does — an in-app browser would put the project's page inside the
  /// app's chrome, which is exactly the confusion the plain-text rule above
  /// exists to avoid.
  Future<void> _open(Announcement announcement, AnnouncementInbox inbox) async {
    final url = announcement.url;
    if (url == null) return;

    await inbox.markRead(announcement.address);
    try {
      // launchUrl reports a refusal by returning false, not by throwing: a
      // device with nothing registered for https answers the call and does
      // nothing at all. Dropping the result would have left that as the one
      // failure here with no trace of itself anywhere.
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) {
        debugPrint('Announcements: nothing on this device opened $url');
      }
    } catch (e) {
      // Nothing to say to the user either way: they tapped a link, no browser
      // took it, and no message here would help them (§4.4).
      debugPrint('Announcements: launching $url failed: $e');
    }
  }

  /// Coarse on purpose. This channel carries releases and outages, so the
  /// question a reader has is "is this current", not "was it 14:32 or 14:47".
  static String _relativeDate(AppLocalizations l10n, int createdAt) {
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    );
    if (age.inHours < 1) return l10n.announcementsWhenNow;
    if (age.inDays < 1) return l10n.announcementsWhenHours(age.inHours);
    return l10n.announcementsWhenDays(age.inDays);
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
