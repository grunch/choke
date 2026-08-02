/// The numbers and names §2 fixes, and nothing else.
///
/// Deliberately free of every import, Flutter included. The publisher tool in
/// `tool/` runs on the plain Dart VM, where `dart:ui` does not exist, so
/// anything it shares with the app has to live somewhere that pulls in no
/// Flutter — and the constants are exactly what must not drift between the end
/// that writes an announcement and the end that reads one.
///
/// See docs/specs/announcement-channel.md §2.
library;

/// The announcement kind: addressable, adjacent to the match kind 31415.
const int kAnnouncementKind = 31416;

/// The only content schema version this build understands. An event with any
/// other `v` is ignored rather than rendered best-effort (§2.2).
const int kAnnouncementSchemaVersion = 1;

/// Exactly the locales the app ships. An announcement must carry all four and
/// no others: there is no fallback, because a fallback is a bug that ships
/// quietly — the reader gets a language they did not choose and nobody finds
/// out (§2.2). Pinned to `AppLocalizations.supportedLocales` by test.
const Set<String> kAnnouncementLocales = {'en', 'es', 'ja', 'pt'};

/// Nothing older than this is news, however long a relay has been serving it
/// (§3.3). Shared with the publisher tool because it is the one rule a sender
/// can silently work against: an expiry beyond this window does not extend
/// anything, it just ends somewhere the sender did not choose.
const int kAnnouncementMaxAgeDays = 30;

const int kAnnouncementTitleMaxLength = 80;
const int kAnnouncementBodyMaxLength = 500;
