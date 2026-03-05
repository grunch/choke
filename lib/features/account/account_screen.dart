import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.copiedToClipboard(label)),
          backgroundColor: BJJColors.green,
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
          return AlertDialog(
            backgroundColor: BJJColors.navyDark,
            title: Text(
              l10n.importPrivateKey,
              style: const TextStyle(color: BJJColors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.importWarning,
                  style: const TextStyle(color: BJJColors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _importController,
                  style: const TextStyle(color: BJJColors.white),
                  decoration: InputDecoration(
                    hintText: l10n.enterNsec,
                    hintStyle: TextStyle(
                      color: BJJColors.grey.withValues(alpha: 0.6),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: BJJColors.greyDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: BJJColors.greyDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: BJJColors.green),
                    ),
                    errorText: dialogError,
                    errorStyle: const TextStyle(color: Colors.red),
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
                child: Text(
                  l10n.cancel,
                  style: const TextStyle(color: BJJColors.grey),
                ),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.keyImportedSuccessfully),
                                backgroundColor: BJJColors.green,
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
                  backgroundColor: BJJColors.gold,
                  foregroundColor: BJJColors.navy,
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

    return Scaffold(
      backgroundColor: BJJColors.navy,
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
                        gradient: const LinearGradient(
                          colors: [BJJColors.green, BJJColors.gold],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.shield,
                        size: 40,
                        color: BJJColors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.yourNostrIdentity,
                      style: const TextStyle(
                        color: BJJColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.keypairDescription,
                      style: TextStyle(
                        color: BJJColors.grey.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Public Key Section (npub)
              _buildSectionTitle(l10n.publicKeyNpub),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BJJColors.navyDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: BJJColors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    npubAsync.when(
                      data: (npub) => Column(
                        children: [
                          Text(
                            npub ?? l10n.generating,
                            style: const TextStyle(
                              color: BJJColors.white,
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
                                  icon: Icons.copy,
                                  label: l10n.copy,
                                  onTap: () =>
                                      _copyToClipboard(npub, l10n.publicKey),
                                ),
                                _buildActionButton(
                                  icon: Icons.qr_code,
                                  label: l10n.showQr,
                                  onTap: () => _showQRCode(context, npub),
                                ),
                              ] else
                                Text(
                                  l10n.keyUnavailable,
                                  style: const TextStyle(color: BJJColors.grey),
                                ),
                            ],
                          ),
                        ],
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => Text(
                        l10n.errorLoadingKey,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Private Key Section (nsec)
              _buildSectionTitle(l10n.privateKeyNsec),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BJJColors.navyDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.red.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.neverSharePrivateKey,
                            style: TextStyle(
                              color: Colors.red.withValues(alpha: 0.8),
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
                                color: BJJColors.navy,
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
                                            ? BJJColors.white
                                            : BJJColors.grey,
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _isNsecVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: BJJColors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.tapToReveal,
                            style: TextStyle(
                              color: BJJColors.grey.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_isNsecVisible)
                            _buildActionButton(
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
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Security Tips
              _buildSectionTitle(l10n.securityTips),
              const SizedBox(height: 8),
              _buildTipCard(
                icon: Icons.backup,
                title: l10n.tipBackupTitle,
                description: l10n.tipBackupDescription,
              ),
              const SizedBox(height: 8),
              _buildTipCard(
                icon: Icons.no_accounts,
                title: l10n.tipNeverShareTitle,
                description: l10n.tipNeverShareDescription,
              ),
              const SizedBox(height: 8),
              _buildTipCard(
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: BJJColors.grey,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: BJJColors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: BJJColors.green, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: BJJColors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BJJColors.navyDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: BJJColors.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: BJJColors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: BJJColors.grey.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
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
        return AlertDialog(
          backgroundColor: BJJColors.navyDark,
          title: Text(
            l10n.yourPublicKey,
            style: const TextStyle(color: BJJColors.white),
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
                style: const TextStyle(
                  color: BJJColors.grey,
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
                style: const TextStyle(color: BJJColors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.close,
                style: const TextStyle(color: BJJColors.green),
              ),
            ),
          ],
        );
      },
    );
  }
}
