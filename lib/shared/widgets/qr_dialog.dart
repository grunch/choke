import 'package:flutter/material.dart';
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
  });

  /// What this code is, in the reader's language.
  final String title;

  /// What the code encodes. Shown as text as well as scanned.
  final String data;

  /// What to do with it — "scan this to…".
  final String caption;

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
          Text(
            data,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => QrDialog(title: title, data: data, caption: caption),
  );
}
