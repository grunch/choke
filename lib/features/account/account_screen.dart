import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../services/key_management/key_manager.dart';

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

  @override
  Widget build(BuildContext context) {
    final npubAsync = ref.watch(npubProvider);
    final nsecAsync = ref.watch(nsecProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.importChangeKey,
            onPressed: _showImportDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary, colors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.shield,
                        size: 40,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.yourNostrIdentity,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.keypairDescription,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Public Key Section (npub)
              _buildSectionTitle(context, l10n.publicKeyNpub),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    npubAsync.when(
                      data: (npub) => Column(
                        children: [
                          Text(
                            npub ?? l10n.generating,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (npub != null) ...[
                                _buildActionButton(
                                  context: context,
                                  icon: Icons.copy,
                                  label: l10n.copy,
                                  onTap: () =>
                                      _copyToClipboard(npub, l10n.publicKey),
                                ),
                                _buildActionButton(
                                  context: context,
                                  icon: Icons.qr_code,
                                  label: l10n.showQr,
                                  onTap: () => _showQRCode(context, npub),
                                ),
                              ] else
                                Text(
                                  l10n.keyUnavailable,
                                  style: theme.textTheme.bodyMedium,
                                ),
                            ],
                          ),
                        ],
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => Text(
                        l10n.errorLoadingKey,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Private Key Section (nsec)
              _buildSectionTitle(context, l10n.privateKeyNsec),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: colors.error.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.neverSharePrivateKey,
                            style: TextStyle(
                              color: colors.error.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    nsecAsync.when(
                      data: (nsec) => Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() => _isNsecVisible = !_isNsecVisible);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _isNsecVisible
                                          ? (nsec ?? l10n.generating)
                                          : '••••••••••••••••••••••••••••••••••••••••••••••••••',
                                      style: TextStyle(
                                        color: _isNsecVisible
                                            ? colors.onSurface
                                            : theme.textTheme.bodyMedium?.color,
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _isNsecVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.tapToReveal,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_isNsecVisible)
                            _buildActionButton(
                              context: context,
                              icon: Icons.copy,
                              label: l10n.copyToClipboard,
                              onTap: () =>
                                  _copyToClipboard(nsec ?? '', l10n.privateKey),
                            ),
                        ],
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => Text(
                        l10n.errorLoadingKey,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Security Tips
              _buildSectionTitle(context, l10n.securityTips),
              const SizedBox(height: 8),
              _buildTipCard(
                context: context,
                icon: Icons.backup,
                title: l10n.tipBackupTitle,
                description: l10n.tipBackupDescription,
              ),
              const SizedBox(height: 8),
              _buildTipCard(
                context: context,
                icon: Icons.no_accounts,
                title: l10n.tipNeverShareTitle,
                description: l10n.tipNeverShareDescription,
              ),
              const SizedBox(height: 8),
              _buildTipCard(
                context: context,
                icon: Icons.phone_android,
                title: l10n.tipSecureStorageTitle,
                description: l10n.tipSecureStorageDescription,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: theme.textTheme.bodyMedium?.color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.primary, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w500,
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
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.secondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQRCode(BuildContext context, String data) {
    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            l10n.yourPublicKey,
            style: TextStyle(color: colors.onSurface),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                l10n.scanQrToShare,
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
      },
    );
  }
}
