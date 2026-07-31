import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:choke/l10n/generated/app_localizations.dart';

/// Hand a link to the platform share sheet, and say so when it will not open.
///
/// Three screens send links now — the account screen's board link, the
/// scoreboard header's, and a match's — and every one of them needs the same
/// three things: an origin rect so an iPad has somewhere to anchor the popover,
/// a `PlatformException` caught so a failure does not escape a tap callback as
/// an unhandled async error, and the [AppLocalizations.shareFailed] snackbar
/// that tells the user why nothing happened. Written once here rather than
/// three times, because three copies of a `try`/`catch` is where a difference
/// between them stops being deliberate.
///
/// [message] precedes the link and [url] follows it on its own line: what
/// arrives in a chat is a sentence and then something tappable, never a bare
/// URL nobody asked for. [subject] is what the sheet calls the thing being
/// shared, and must name it — "share this board" and "share this match" produce
/// different links, and a bare "Share" on either is how somebody sends the
/// wrong one.
///
/// [logTag] names the caller in the one debug line this writes. Never the URL,
/// which carries a pubkey, and never the platform's message, which could echo
/// shared content back out to the device log.
Future<void> shareLink(
  BuildContext context, {
  required String message,
  required String url,
  required String subject,
  required String logTag,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final errorColor = Theme.of(context).colorScheme.error;

  // iPad requires a non-null origin to anchor the share popover; the caller's
  // render box is a safe fallback on phones.
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

  try {
    await Share.share(
      '$message\n$url',
      subject: subject,
      sharePositionOrigin: origin,
    );
  } on PlatformException catch (e) {
    debugPrint('$logTag: share sheet failed (${e.code})');
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.shareFailed), backgroundColor: errorColor),
    );
  }
}
