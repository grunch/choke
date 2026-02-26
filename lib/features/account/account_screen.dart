import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  bool _isImporting = false;
  String? _importError;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          backgroundColor: BJJColors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showImportDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BJJColors.navyDark,
        title: const Text(
          'Import Private Key',
          style: TextStyle(color: BJJColors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Warning: Importing a new private key will replace your current identity. This action cannot be undone.',
              style: TextStyle(color: BJJColors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _importController,
              style: const TextStyle(color: BJJColors.white),
              decoration: InputDecoration(
                hintText: 'Enter nsec...',
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
                errorText: _importError,
                errorStyle: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _importController.clear();
              setState(() => _importError = null);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: BJJColors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: _isImporting ? null : _handleImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: BJJColors.gold,
              foregroundColor: BJJColors.navy,
            ),
            child: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImport() async {
    final nsec = _importController.text.trim();
    if (nsec.isEmpty) {
      setState(() => _importError = 'Please enter an nsec');
      return;
    }

    if (!nsec.toLowerCase().startsWith('nsec1')) {
      setState(
        () => _importError = 'Invalid nsec format (should start with nsec1)',
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _importError = null;
    });

    final keyManager = ref.read(keyManagerProvider);
    final success = await keyManager.importFromNsec(nsec);

    if (!mounted) return;

    setState(() => _isImporting = false);

    if (success) {
      Navigator.pop(context);
      _importController.clear();
      ref.invalidate(npubProvider);
      ref.invalidate(nsecProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Private key imported successfully'),
            backgroundColor: BJJColors.green,
          ),
        );
      }
    } else {
      setState(
        () => _importError = 'Failed to import key. Please check the format.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final npubAsync = ref.watch(npubProvider);
    final nsecAsync = ref.watch(nsecProvider);

    return Scaffold(
      backgroundColor: BJJColors.navy,
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Import/Change Key',
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
                    const Text(
                      'Your Nostr Identity',
                      style: TextStyle(
                        color: BJJColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This keypair identifies you on the network',
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
              _buildSectionTitle('Public Key (npub)'),
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
                            npub ?? 'Generating...',
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
                              _buildActionButton(
                                icon: Icons.copy,
                                label: 'Copy',
                                onTap: () =>
                                    _copyToClipboard(npub ?? '', 'Public key'),
                              ),
                              _buildActionButton(
                                icon: Icons.qr_code,
                                label: 'Show QR',
                                onTap: () => _showQRCode(context, npub ?? ''),
                              ),
                            ],
                          ),
                        ],
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text(
                        'Error loading key',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Private Key Section (nsec)
              _buildSectionTitle('Private Key (nsec)'),
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
                            'Never share your private key with anyone!',
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
                                          ? (nsec ?? 'Generating...')
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
                            'Tap to reveal • Keep this secret!',
                            style: TextStyle(
                              color: BJJColors.grey.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_isNsecVisible)
                            _buildActionButton(
                              icon: Icons.copy,
                              label: 'Copy to Clipboard',
                              onTap: () =>
                                  _copyToClipboard(nsec ?? '', 'Private key'),
                            ),
                        ],
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text(
                        'Error loading key',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Security Tips
              _buildSectionTitle('Security Tips'),
              const SizedBox(height: 8),
              _buildTipCard(
                icon: Icons.backup,
                title: 'Backup your keys',
                description:
                    'Write down your nsec and store it in a safe place.',
              ),
              const SizedBox(height: 8),
              _buildTipCard(
                icon: Icons.no_accounts,
                title: 'Never share your nsec',
                description: 'Anyone with your nsec can impersonate you.',
              ),
              const SizedBox(height: 8),
              _buildTipCard(
                icon: Icons.phone_android,
                title: 'Secure storage',
                description: 'Keys are stored securely on your device.',
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
      builder: (context) => AlertDialog(
        backgroundColor: BJJColors.navyDark,
        title: const Text(
          'Your Public Key',
          style: TextStyle(color: BJJColors.white),
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
              child: QrImageView(
                data: data,
                size: 200,
                backgroundColor: BJJColors.white,
                foregroundColor: BJJColors.navy,
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
            const Text(
              'Scan this QR code to share your public key',
              style: TextStyle(color: BJJColors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: BJJColors.green),
            ),
          ),
        ],
      ),
    );
  }
}
