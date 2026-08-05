import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:choke/l10n/generated/app_localizations.dart';

import '../theme/app_theme.dart';

/// A scannable code, and the thing it encodes spelled out underneath it.
///
/// Two screens hand out the same kind of thing — the account screen a public
/// key, the scoreboard a link to a live board — and a camera pointed at a phone
/// is how both travel across a room. [data] is always shown as text as well:
/// codes fail to scan in bad light, at an angle, and on cracked glass, and
/// somebody has to be able to read it out.
class QrDialog extends StatelessWidget {
  const QrDialog({
    super.key,
    required this.title,
    required this.data,
    required this.caption,
    this.copyLabel,
    this.share,
  });

  /// What this code is, in the reader's language.
  final String title;

  /// What the code encodes. Shown as text as well as scanned.
  final String data;

  /// What to do with it — "scan this to…".
  final String caption;

  /// What [data] is called in the confirmation — "Link copied to clipboard".
  ///
  /// Null leaves the text inert, which is what the account screen wants: its
  /// code carries a public key and the screen already offers a labelled copy
  /// control for it. A second, invisible one hiding under the code would be a
  /// tap target nothing announces.
  final String? copyLabel;

  /// Send [data] somewhere the room is not — the platform share sheet.
  ///
  /// A code carries a link across a room; a share sheet carries it to everyone
  /// who is not in one. Both are ways off this screen, which is why the control
  /// sits beside the link rather than in the actions row.
  ///
  /// [onTap] is the caller's, not this widget's: what a shared link SAYS
  /// belongs to the screen sending it — its message, its subject line, its log
  /// tag — and a dialog that guessed at those would put the scoreboard's
  /// wording on the account screen's link. [label] names the action for a
  /// screen reader and a long-press tooltip, which an icon on its own does not.
  ///
  /// Null means no control at all, which is what the account screen wants: its
  /// code carries a raw public key rather than a link, and handing that to a
  /// share sheet is a different act from sharing a board.
  final ({String label, VoidCallback onTap})? share;

  /// Put [data] on the clipboard and say so.
  ///
  /// The dialog stays open on purpose. Copying the link is not being finished
  /// with the code — the person across the room is still pointing a camera at
  /// it, and closing here would take the code away from them.
  Future<void> _copy(BuildContext context, String label) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final color = Theme.of(context).colorScheme.primary;

    await Clipboard.setData(ClipboardData(text: data));

    // A copy that says nothing is indistinguishable from a tap that missed.
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.copiedToClipboard(label)),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// [data] as text: a tap target when it can be copied, inert when it cannot.
  ///
  /// Coloured and underlined in the copyable case, because nothing else on a
  /// line of monospace text says it is a tap target.
  Widget _buildLink(BuildContext context) {
    final theme = Theme.of(context);

    if (copyLabel case final label?) {
      return InkWell(
        onTap: () => _copy(context, label),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            data,
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: theme.colorScheme.primary,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Text(
      data,
      style: TextStyle(
        color: theme.textTheme.bodyMedium?.color,
        fontSize: 11,
        fontFamily: 'monospace',
      ),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        title,
        style: TextStyle(color: colors.onSurface),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Always a white plate with navy modules, in either theme. A scanner
          // needs the contrast, and a code tinted to match the dark theme is a
          // code that does not read.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BJJColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: data,
                backgroundColor: BJJColors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: BJJColors.navy,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: BJJColors.navy,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // The link and the two things you can do with it, on one line. Both
          // move it off the screen — one to this phone's clipboard, one to
          // somebody else's — so neither belongs down in the actions row, away
          // from the thing it acts on.
          //
          // Flexible, not Expanded: a short link should not stretch, but a long
          // one has to wrap rather than overflow the dialog.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: _buildLink(context)),
              // Deliberately an icon and nothing more. The account screen's
              // share control is a filled, full-width, labelled CTA because
              // sharing the board is what that screen is FOR; here the code is
              // the point and this is a way out of it, so it gets the weight of
              // a hint rather than of an instruction.
              if (share case final action?)
                IconButton(
                  onPressed: action.onTap,
                  icon: const Icon(Icons.ios_share, size: 18),
                  color: colors.primary,
                  tooltip: action.label,
                  // The GLYPH is what stays small — 18px, so it reads as a hint
                  // beside the link. The tap target is left at IconButton's
                  // default 48x48, which is the documented minimum a thumb
                  // needs and what the platform accessibility checks measure.
                  // Shrinking the box to match the icon was making the one way
                  // to send this link a target that misses.
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

/// Show [QrDialog] over [context].
Future<void> showQrDialog(
  BuildContext context, {
  required String title,
  required String data,
  required String caption,
  String? copyLabel,
  ({String label, VoidCallback onTap})? share,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => QrDialog(
      title: title,
      data: data,
      caption: caption,
      copyLabel: copyLabel,
      share: share,
    ),
  );
}
