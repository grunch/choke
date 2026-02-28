import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Model representing a Nostr relay configuration
class RelayConfig {
  final String url;
  final bool isEnabled;
  final bool isConnected;

  const RelayConfig({
    required this.url,
    this.isEnabled = true,
    this.isConnected = false,
  });

  RelayConfig copyWith({
    String? url,
    bool? isEnabled,
    bool? isConnected,
  }) {
    return RelayConfig(
      url: url ?? this.url,
      isEnabled: isEnabled ?? this.isEnabled,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'isEnabled': isEnabled,
    };
  }

  factory RelayConfig.fromJson(Map<String, dynamic> json) {
    return RelayConfig(
      url: json['url'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }
}

/// Service for managing relay configuration persistence
class RelayConfigService {
  static const String _relaysKey = 'nostr_relays';
  static const List<String> defaultRelays = [
    'wss://relay.mostro.network',
    'wss://nos.lol',
  ];

  final FlutterSecureStorage _secureStorage;

  RelayConfigService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  /// Load relay configuration from secure storage
  /// Returns default relays if none are configured
  Future<List<RelayConfig>> loadRelays() async {
    try {
      final jsonStr = await _secureStorage.read(key: _relaysKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        // First time - return default relays
        return defaultRelays
            .map((url) => RelayConfig(url: url, isEnabled: true))
            .toList();
      }

      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      return jsonList
          .map((json) => RelayConfig.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('RelayConfigService: Error loading relays: $e');
      // Return defaults on error
      return defaultRelays
          .map((url) => RelayConfig(url: url, isEnabled: true))
          .toList();
    }
  }

  /// Save relay configuration to secure storage
  Future<void> saveRelays(List<RelayConfig> relays) async {
    try {
      final jsonList = relays.map((r) => r.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);
      await _secureStorage.write(key: _relaysKey, value: jsonStr);
    } catch (e) {
      debugPrint('RelayConfigService: Error saving relays: $e');
      throw Exception('Failed to save relay configuration');
    }
  }

  /// Reset to default relays
  Future<List<RelayConfig>> resetToDefaults() async {
    final defaults = defaultRelays
        .map((url) => RelayConfig(url: url, isEnabled: true))
        .toList();
    await saveRelays(defaults);
    return defaults;
  }
}

/// Provider for RelayConfigService
final relayConfigServiceProvider = Provider<RelayConfigService>((ref) {
  return RelayConfigService();
});

/// State class for relay configuration
class RelayConfigState {
  final List<RelayConfig> relays;
  final bool isLoading;
  final String? error;

  const RelayConfigState({
    this.relays = const [],
    this.isLoading = false,
    this.error,
  });

  RelayConfigState copyWith({
    List<RelayConfig>? relays,
    bool? isLoading,
    String? error,
  }) {
    return RelayConfigState(
      relays: relays ?? this.relays,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get enabled relays only
  List<RelayConfig> get enabledRelays =>
      relays.where((r) => r.isEnabled).toList();

  /// Check if at least one relay is enabled
  bool get hasEnabledRelay => relays.any((r) => r.isEnabled);

  /// Check if a URL already exists
  bool containsUrl(String url) {
    final normalized = url.toLowerCase().trim();
    return relays.any((r) => r.url.toLowerCase().trim() == normalized);
  }
}

/// Notifier for managing relay configuration
class RelayConfigNotifier extends StateNotifier<RelayConfigState> {
  final RelayConfigService _service;

  RelayConfigNotifier(this._service) : super(const RelayConfigState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      final relays = await _service.loadRelays();
      state = RelayConfigState(relays: relays, isLoading: false);
    } catch (e) {
      state = RelayConfigState(
        isLoading: false,
        error: 'Failed to load relay configuration',
      );
    }
  }

  /// Reload relays from storage
  Future<void> refresh() async {
    await _initialize();
  }

  /// Add a new relay
  /// Returns true if added successfully, false if URL already exists
  Future<bool> addRelay(String url) async {
    // Validate URL format
    if (!_isValidRelayUrl(url)) {
      state = state.copyWith(error: 'Invalid relay URL. Must start with wss://');
      return false;
    }

    // Normalize URL
    final normalizedUrl = url.trim();

    // Check for duplicates
    if (state.containsUrl(normalizedUrl)) {
      state = state.copyWith(error: 'Relay already exists');
      return false;
    }

    try {
      final newRelay = RelayConfig(url: normalizedUrl, isEnabled: true);
      final newRelays = [...state.relays, newRelay];
      await _service.saveRelays(newRelays);
      state = RelayConfigState(relays: newRelays, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to add relay');
      return false;
    }
  }

  /// Remove a relay
  /// Returns true if removed, false if it was the last enabled relay
  Future<bool> removeRelay(String url) async {
    final normalizedUrl = url.toLowerCase().trim();

    // Check if this is the last enabled relay
    final relayToRemove = state.relays.firstWhere(
      (r) => r.url.toLowerCase().trim() == normalizedUrl,
      orElse: () => const RelayConfig(url: ''),
    );

    if (relayToRemove.url.isEmpty) return false;

    // If it's enabled, check we won't disable the last one
    if (relayToRemove.isEnabled) {
      final enabledCount = state.enabledRelays.length;
      if (enabledCount <= 1) {
        state = state.copyWith(
          error: 'Cannot remove the last active relay',
        );
        return false;
      }
    }

    try {
      final newRelays = state.relays
          .where((r) => r.url.toLowerCase().trim() != normalizedUrl)
          .toList();
      await _service.saveRelays(newRelays);
      state = RelayConfigState(relays: newRelays, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to remove relay');
      return false;
    }
  }

  /// Toggle relay enabled state
  /// Returns true if toggled, false if trying to disable the last enabled relay
  Future<bool> toggleRelay(String url) async {
    final normalizedUrl = url.toLowerCase().trim();

    final relayIndex = state.relays.indexWhere(
      (r) => r.url.toLowerCase().trim() == normalizedUrl,
    );

    if (relayIndex == -1) return false;

    final relay = state.relays[relayIndex];

    // Check if trying to disable the last enabled relay
    if (relay.isEnabled && state.enabledRelays.length <= 1) {
      state = state.copyWith(
        error: 'At least one relay must remain active',
      );
      return false;
    }

    try {
      final newRelays = [...state.relays];
      newRelays[relayIndex] = relay.copyWith(isEnabled: !relay.isEnabled);
      await _service.saveRelays(newRelays);
      state = RelayConfigState(relays: newRelays, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to toggle relay');
      return false;
    }
  }

  /// Update connection status for a relay
  void updateConnectionStatus(String url, bool isConnected) {
    final normalizedUrl = url.toLowerCase().trim();
    final relayIndex = state.relays.indexWhere(
      (r) => r.url.toLowerCase().trim() == normalizedUrl,
    );

    if (relayIndex == -1) return;

    final newRelays = [...state.relays];
    newRelays[relayIndex] =
        newRelays[relayIndex].copyWith(isConnected: isConnected);
    state = state.copyWith(relays: newRelays);
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Validate relay URL format
  bool _isValidRelayUrl(String url) {
    final trimmed = url.trim();
    return trimmed.startsWith('wss://') || trimmed.startsWith('ws://');
  }

  /// Test if a relay is reachable
  Future<bool> testRelay(String url) async {
    try {
      // Simple connection test
      final uri = Uri.parse(url.trim());
      // Note: Actual WebSocket test would require dart:io or web_socket_channel
      // For now, we just validate the URL can be parsed
      return uri.isScheme('wss') || uri.isScheme('ws');
    } catch (e) {
      return false;
    }
  }
}

/// Provider for RelayConfigNotifier
final relayConfigProvider =
    StateNotifierProvider<RelayConfigNotifier, RelayConfigState>((ref) {
  final service = ref.watch(relayConfigServiceProvider);
  return RelayConfigNotifier(service);
});
