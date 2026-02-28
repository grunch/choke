import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        title: const Text('Relay Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: relayNotifier.refresh,
            tooltip: 'Refresh',
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
                  labelText: 'Add Custom Relay',
                  hintText: 'wss://relay.example.com',
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
                    return 'Please enter a relay URL';
                  }
                  if (!value.trim().startsWith('wss://') &&
                      !value.trim().startsWith('ws://')) {
                    return 'URL must start with wss:// or ws://';
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
                onPressed: _isAdding
                    ? null
                    : () => _addRelay(notifier),
                icon: _isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_isAdding ? 'Adding...' : 'Add'),
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
          _getStatusText(relay, isDefault),
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
            'No relays configured',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add a relay to start publishing events',
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(RelayConfig relay, bool isDefault) {
    if (!relay.isEnabled) return 'Disabled';
    if (isDefault) return relay.isConnected ? 'Connected • Default' : 'Connecting • Default';
    return relay.isConnected ? 'Connected' : 'Connecting';
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
      _showSuccessSnackBar(context, 'Relay added successfully');
    }
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    RelayConfig relay,
    RelayConfigNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Relay?'),
        content: Text('Are you sure you want to remove ${relay.url}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: BJJColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await notifier.removeRelay(relay.url);
      if (success && mounted) {
        _showSuccessSnackBar(context, 'Relay removed');
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
