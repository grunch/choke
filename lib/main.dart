import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/match/match_screen.dart';
import 'features/account/account_screen.dart';
import 'features/settings/settings_screen.dart';
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

  // Initialize NostrService (connect to default relays)
  final nostrService = NostrService(keyManager);
  try {
    await nostrService.initialize();
  } catch (e, st) {
    debugPrint('NostrService initialization failed: $e\n$st');
  }

  runApp(
    ProviderScope(
      overrides: [
        keyManagerProvider.overrideWithValue(keyManager),
        nostrServiceProvider.overrideWithValue(nostrService),
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
    const MatchScreen(),
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
