import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/theme/app_theme.dart';
import 'features/home/home_screen.dart';

import 'features/account/account_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/providers/relay_config_provider.dart';
import 'services/key_management/key_manager.dart';
import 'services/nostr/nostr_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize KeyManager
  final keyManager = KeyManager();
  try {
    await keyManager.initialize();
  } catch (e, st) {
    debugPrint('KeyManager initialization failed: $e\n$st');
  }

  // Load relay configuration
  final relayConfigService = RelayConfigService();
  List<RelayConfig> relayConfigs = [];
  try {
    relayConfigs = await relayConfigService.loadRelays();
  } catch (e, st) {
    debugPrint('Relay config loading failed: $e\n$st');
  }

  // Initialize NostrService with configured relays
  final nostrService = NostrService(keyManager);
  try {
    final enabledRelayUrls = relayConfigs
        .where((r) => r.isEnabled)
        .map((r) => r.url)
        .toList();
    await nostrService.initialize(
      relayUrls: enabledRelayUrls.isNotEmpty ? enabledRelayUrls : null,
    );
    // Subscribe to user's match events
    await nostrService.subscribeToUserEvents();
  } catch (e, st) {
    debugPrint('NostrService initialization failed: $e\n$st');
  }

  runApp(
    ProviderScope(
      overrides: [
        keyManagerProvider.overrideWithValue(keyManager),
        nostrServiceProvider.overrideWithValue(nostrService),
        relayConfigServiceProvider.overrideWithValue(relayConfigService),
      ],
      child: const ChokeApp(),
    ),
  );
}

class ChokeApp extends StatelessWidget {
  const ChokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Choke',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigation(),
    );
  }
}

/// Main navigation with bottom navigation bar
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const _MatchListPlaceholder(),
    const AccountScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_martial_arts_outlined),
            activeIcon: Icon(Icons.sports_martial_arts),
            label: 'Match',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Account',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Placeholder for the Match tab — will show match list in future
class _MatchListPlaceholder extends StatelessWidget {
  const _MatchListPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Create a match from the Home screen',
          style: TextStyle(color: BJJColors.grey, fontSize: 16),
        ),
      ),
    );
  }
}
