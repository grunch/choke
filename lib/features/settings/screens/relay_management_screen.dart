import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/relay_config_provider.dart';

/// Screen for managing Nostr relay connections
class RelayManagementScreen extends ConsumerStatefulWidget {
  const RelayManagementScreen({super.key});

  @override
  ConsumerState<RelayManagementScreen> createState() =>
      _RelayManagementScreenState();
}

class _RelayManagementScreenState extends ConsumerState<RelayManagementScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAdding = false;
  String? _lastShownError;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final relayState = ref.watch(relayConfigProvider);
    final relayNotifier = ref.read(relayConfigProvider.notifier);
    final l10n = AppLocalizations.of(context);

    // Show error if any (prevent duplicates on rapid rebuilds)
    if (relayState.error != null && relayState.error != _lastShownError) {
      _lastShownError = relayState.error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showErrorSnackBar(context, relayState.error!);
          relayNotifier.clearError();
          _lastShownError = null;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.relayManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: relayNotifier.refresh,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Add relay section
          _buildAddRelaySection(context, relayNotifier),
          const Divider(),
          // Relay list
          Expanded(
            child: _buildRelayList(context, relayState, relayNotifier),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRelaySection(
    BuildContext context,
    RelayConfigNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: l10n.addCustomRelay,
                  hintText: l10n.relayHint,
                  prefixIcon: const Icon(Icons.dns),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.pleaseEnterRelayUrl;
                  }
                  if (!value.trim().startsWith('wss://') &&
                      !value.trim().startsWith('ws://')) {
                    return l10n.relayUrlMustStartWithWss;
                  }
                  return null;
                },
                enabled: !_isAdding,
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isAdding ? null : () => _addRelay(notifier),
                icon: _isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_isAdding ? l10n.adding : l10n.add),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BJJColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelayList(
    BuildContext context,
    RelayConfigState state,
    RelayConfigNotifier notifier,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.relays.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.relays.length,
      itemBuilder: (context, index) {
        final relay = state.relays[index];
        return _buildRelayCard(context, relay, notifier);
      },
    );
  }

  Widget _buildRelayCard(
    BuildContext context,
    RelayConfig relay,
    RelayConfigNotifier notifier,
  ) {
    final isDefault = RelayConfigService.defaultRelays.contains(relay.url);

    // Swipe-to-delete for custom relays
    if (!isDefault) {
      return Dismissible(
        key: Key(relay.url),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmDelete(context, relay, notifier),
        background: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: BJJColors.error,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(
            Icons.delete,
            color: BJJColors.white,
          ),
        ),
        child: _buildRelayCardContent(context, relay, notifier, isDefault),
      );
    }

    return _buildRelayCardContent(context, relay, notifier, isDefault);
  }

  Widget _buildRelayCardContent(
    BuildContext context,
    RelayConfig relay,
    RelayConfigNotifier notifier,
    bool isDefault,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: relay.isEnabled
                ? (relay.isConnected ? BJJColors.green : BJJColors.gold)
                : colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
        ),
        title: Text(
          relay.url,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            decoration: relay.isEnabled ? null : TextDecoration.lineThrough,
            color: relay.isEnabled ? null : colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          _getStatusText(context, relay, isDefault),
          style: TextStyle(
            color: relay.isEnabled
                ? (relay.isConnected ? BJJColors.green : BJJColors.gold)
                : colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(
          value: relay.isEnabled,
          onChanged: (value) => notifier.toggleRelay(relay.url),
          activeColor: BJJColors.green,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noRelaysConfigured,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addRelayToStart,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(
      BuildContext context, RelayConfig relay, bool isDefault) {
    final l10n = AppLocalizations.of(context);

    if (!relay.isEnabled) return l10n.relayStatusDisabled;
    if (isDefault) {
      return relay.isConnected
          ? l10n.relayStatusConnectedDefault
          : l10n.relayStatusConnectingDefault;
    }
    return relay.isConnected
        ? l10n.relayStatusConnected
        : l10n.relayStatusConnecting;
  }

  Future<void> _addRelay(RelayConfigNotifier notifier) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAdding = true);

    final url = _urlController.text.trim();
    final success = await notifier.addRelay(url);

    if (!mounted) return;

    setState(() => _isAdding = false);

    if (success) {
      _urlController.clear();
      final l10n = AppLocalizations.of(context);
      _showSuccessSnackBar(context, l10n.relayAddedSuccessfully);
    }
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    RelayConfig relay,
    RelayConfigNotifier notifier,
  ) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeRelayQuestion),
        content: Text(l10n.removeRelayConfirmation(relay.url)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.remove,
              style: const TextStyle(color: BJJColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await notifier.removeRelay(relay.url);
      if (success && mounted) {
        _showSuccessSnackBar(context, l10n.relayRemoved);
      }
      return success;
    }
    return false;
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: BJJColors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
