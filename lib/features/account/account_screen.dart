import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../services/deep_links/share_link.dart';
import '../../services/nostr/nostr_service.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../../shared/share_sheet.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/qr_dialog.dart';
import '../../services/key_management/key_manager.dart';

/// Point the relays and the home feed at the identity that is now stored.
///
/// Best-effort on purpose. The key has already been written by the time this
/// runs, so a relay that will not take the new subscription must not turn a
/// successful import into a failed one — and the next launch resubscribes from
/// scratch anyway.
Future<void> _refreshIdentity(WidgetRef ref) async {
  try {
    await ref.read(nostrServiceProvider).refreshIdentity();
  } catch (e) {
    debugPrint('Account: identity changed but the resubscribe failed: $e');
  }
}

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _isNsecVisible = false;
  final _importController = TextEditingController();

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      final primaryColor = Theme.of(context).colorScheme.primary;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.copiedToClipboard(label)),
          backgroundColor: primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Open the platform share sheet with a bjjscore.live link for this npub, so
  /// a spectator only has to tap it — no key to copy or paste on the web.
  Future<void> _shareLiveBoard(String npub) async {
    final l10n = AppLocalizations.of(context);
    await shareLink(
      context,
      message: l10n.shareLiveBoardMessage,
      url: liveBoardShareUrl(npub),
      subject: l10n.shareLiveBoard,
      logTag: 'AccountScreen',
    );
  }

  Future<void> _showImportDialog() async {
    String? dialogError;
    bool dialogImporting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogBuildContext, setDialogState) {
          final l10n = AppLocalizations.of(dialogBuildContext);
          final theme = Theme.of(dialogBuildContext);
          final colors = theme.colorScheme;
          return AlertDialog(
            backgroundColor: colors.surface,
            title: Text(
              l10n.importPrivateKey,
              style: TextStyle(color: colors.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.importWarning,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _importController,
                  style: TextStyle(color: colors.onSurface),
                  decoration: InputDecoration(
                    hintText: l10n.enterNsec,
                    errorText: dialogError,
                    errorStyle: TextStyle(color: colors.error),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _importController.clear();
                },
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: dialogImporting
                    ? null
                    : () async {
                        final nsec = _importController.text.trim();
                        if (nsec.isEmpty) {
                          setDialogState(
                            () => dialogError = l10n.pleaseEnterNsec,
                          );
                          return;
                        }

                        if (!nsec.toLowerCase().startsWith('nsec1')) {
                          setDialogState(
                            () => dialogError = l10n.invalidNsecFormat,
                          );
                          return;
                        }

                        setDialogState(() {
                          dialogImporting = true;
                          dialogError = null;
                        });

                        final keyManager = ref.read(keyManagerProvider);
                        final success = await keyManager.importFromNsec(nsec);

                        // The relays are still following the old identity, and
                        // the home feed still believes it is this user's. Move
                        // both across, or the app quietly stops showing the
                        // matches it is about to publish.
                        if (success) await _refreshIdentity(ref);

                        if (!mounted || !dialogBuildContext.mounted) return;

                        setDialogState(() => dialogImporting = false);

                        if (success) {
                          Navigator.pop(dialogContext);
                          _importController.clear();
                          ref.invalidate(npubProvider);
                          ref.invalidate(nsecProvider);
                          if (mounted) {
                            final primaryColor =
                                Theme.of(context).colorScheme.primary;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.keyImportedSuccessfully),
                                backgroundColor: primaryColor,
                              ),
                            );
                          }
                        } else {
                          if (dialogBuildContext.mounted) {
                            setDialogState(
                              () => dialogError = l10n.failedToImportKey,
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.secondary,
                  foregroundColor: colors.onSecondary,
                ),
                child: dialogImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.import),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showGenerateKeyDialog() async {
    bool dialogGenerating = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogBuildContext, setDialogState) {
          final l10n = AppLocalizations.of(dialogBuildContext);
          final theme = Theme.of(dialogBuildContext);
          final colors = theme.colorScheme;
          final tk = ChokeTokens.of(dialogBuildContext);
          return AlertDialog(
            backgroundColor: colors.surface,
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: tk.dangerFg, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.generateNewKeyTitle,
                    style: TextStyle(color: colors.onSurface),
                  ),
                ),
              ],
            ),
            content: Text(
              l10n.generateNewKeyWarning,
              style: theme.textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: dialogGenerating
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: dialogGenerating
                    ? null
                    : () async {
                        setDialogState(() => dialogGenerating = true);

                        try {
                          final keyManager = ref.read(keyManagerProvider);
                          await keyManager.generateNewKeypair();
                          await _refreshIdentity(ref);
                        } catch (_) {
                          // Not logging the exception object: it was raised
                          // while handling freshly generated key material, so
                          // its message could carry that material into the log.
                          debugPrint('AccountScreen: Error generating keypair');
                          if (dialogBuildContext.mounted) {
                            setDialogState(() => dialogGenerating = false);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.failedToGenerateKey),
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                          return;
                        }

                        // The new keypair is now the stored identity, so the
                        // screen must refresh even if the dialog was dismissed
                        // mid-flight. Closing the dialog is the only step that
                        // depends on it still being on screen.
                        if (dialogBuildContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (!mounted) return;

                        ref.invalidate(npubProvider);
                        ref.invalidate(nsecProvider);
                        setState(() => _isNsecVisible = false);

                        final primaryColor =
                            Theme.of(context).colorScheme.primary;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.keyGeneratedSuccessfully),
                            backgroundColor: primaryColor,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: tk.dangerFg,
                  foregroundColor: BJJColors.white,
                ),
                child: dialogGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.generate),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final npubAsync = ref.watch(npubProvider);
    final nsecAsync = ref.watch(nsecProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tk = ChokeTokens.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header: title + import/change key action
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 14, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.accountTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.autorenew, color: tk.muted, size: 21),
                        tooltip: l10n.generateNewKey,
                        onPressed: _showGenerateKeyDialog,
                      ),
                      IconButton(
                        icon: Icon(Icons.logout, color: tk.muted, size: 21),
                        tooltip: l10n.importChangeKey,
                        onPressed: _showImportDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  6,
                  20,
                  MediaQuery.of(context).padding.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Identity header
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                BJJColors.brandGradStart,
                                BJJColors.brandGradEnd,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: const Icon(
                            Icons.shield,
                            size: 28,
                            color: BJJColors.white,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.yourNostrIdentity,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                l10n.keypairDescription,
                                style:
                                    TextStyle(fontSize: 12.5, color: tk.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Public Key (npub)
                    _buildSectionTitle(context, l10n.publicKeyNpub, tk),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: tk.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: tk.cardBorder),
                      ),
                      child: npubAsync.when(
                        data: (npub) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              npub ?? l10n.generating,
                              style: TextStyle(
                                color: tk.keyFg,
                                fontFamily: 'monospace',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (npub != null)
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildActionButton(
                                          context: context,
                                          icon: Icons.copy,
                                          label: l10n.copy,
                                          onTap: () => _copyToClipboard(
                                              npub, l10n.publicKey),
                                        ),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: _buildActionButton(
                                          context: context,
                                          icon: Icons.qr_code,
                                          label: l10n.showQr,
                                          onTap: () =>
                                              _showQRCode(context, npub),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 9),
                                  _buildShareButton(
                                    context: context,
                                    label: l10n.shareLiveBoard,
                                    onTap: () => _shareLiveBoard(npub),
                                  ),
                                ],
                              )
                            else
                              Text(
                                l10n.keyUnavailable,
                                style: theme.textTheme.bodyMedium,
                              ),
                          ],
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => Text(
                          l10n.errorLoadingKey,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Private Key (nsec)
                    _buildSectionTitle(context, l10n.privateKeyNsec, tk),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: tk.dangerFg.withOpacity(.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: tk.dangerFg.withOpacity(.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: tk.dangerFg,
                                size: 17,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.neverSharePrivateKey,
                                  style: TextStyle(
                                    color: tk.dangerFg,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 11),
                          nsecAsync.when(
                            data: (nsec) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(
                                        () => _isNsecVisible = !_isNsecVisible);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: tk.field,
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(
                                        color: tk.dangerFg.withOpacity(.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _isNsecVisible
                                                ? (nsec ?? l10n.generating)
                                                : '••••••••••••••••••••',
                                            style: TextStyle(
                                              color: _isNsecVisible
                                                  ? colors.onSurface
                                                  : tk.muted,
                                              fontFamily: 'monospace',
                                              fontSize:
                                                  _isNsecVisible ? 12.5 : 15,
                                              letterSpacing:
                                                  _isNsecVisible ? 0 : 3,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          _isNsecVisible
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: tk.muted,
                                          size: 19,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  l10n.tapToReveal,
                                  style: TextStyle(
                                      fontSize: 11.5, color: tk.faint),
                                ),
                                if (_isNsecVisible) ...[
                                  const SizedBox(height: 11),
                                  _buildActionButton(
                                    context: context,
                                    icon: Icons.copy,
                                    label: l10n.copyToClipboard,
                                    onTap: () => _copyToClipboard(
                                        nsec ?? '', l10n.privateKey),
                                  ),
                                ],
                              ],
                            ),
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (_, __) => Text(
                              l10n.errorLoadingKey,
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Security Tips
                    _buildSectionTitle(context, l10n.securityTips, tk),
                    const SizedBox(height: 8),
                    _buildTipCard(
                      context: context,
                      icon: Icons.cloud_upload_outlined,
                      iconColor: tk.accent,
                      title: l10n.tipBackupTitle,
                      description: l10n.tipBackupDescription,
                    ),
                    const SizedBox(height: 8),
                    _buildTipCard(
                      context: context,
                      icon: Icons.block,
                      iconColor: tk.goldFg,
                      title: l10n.tipNeverShareTitle,
                      description: l10n.tipNeverShareDescription,
                    ),
                    const SizedBox(height: 8),
                    _buildTipCard(
                      context: context,
                      icon: Icons.phone_android,
                      iconColor: tk.statusFinishedFg,
                      title: l10n.tipSecureStorageTitle,
                      description: l10n.tipSecureStorageDescription,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
      BuildContext context, String title, ChokeTokens tk) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: tk.muted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final tk = ChokeTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tk.accent.withOpacity(.1),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: tk.accent.withOpacity(.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: tk.accent, size: 16),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tk.accent,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The share CTA: filled accent, full width, sitting just under Copy/QR — the
  /// one action that hands someone else the live board rather than the raw key.
  Widget _buildShareButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    final tk = ChokeTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: tk.accent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ios_share, color: BJJColors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BJJColors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final colors = Theme.of(context).colorScheme;
    final tk = ChokeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tk.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: tk.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQRCode(BuildContext context, String data) {
    final l10n = AppLocalizations.of(context);
    showQrDialog(
      context,
      title: l10n.yourPublicKey,
      data: data,
      caption: l10n.scanQrToShare,
    );
  }
}
