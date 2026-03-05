import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'shared/theme/app_theme.dart';
import 'shared/providers/locale_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/match_duration_provider.dart';
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
    final enabledRelayUrls =
        relayConfigs.where((r) => r.isEnabled).map((r) => r.url).toList();
    await nostrService.initialize(
      relayUrls: enabledRelayUrls.isNotEmpty ? enabledRelayUrls : null,
    );
    // Subscribe to user's match events
    await nostrService.subscribeToUserEvents();
  } catch (e, st) {
    debugPrint('NostrService initialization failed: $e\n$st');
  }

  // Load saved preferences before first frame to avoid flash
  final savedThemeMode = await ThemeModeNotifier.loadSavedThemeMode();
  final savedDuration = await MatchDurationNotifier.loadSavedDuration();

  // Create notifiers with hydrated values (no flash on startup)
  final themeNotifier = ThemeModeNotifier()..hydrate(savedThemeMode);
  final durationNotifier = MatchDurationNotifier()..hydrate(savedDuration);

  runApp(
    ProviderScope(
      overrides: [
        keyManagerProvider.overrideWithValue(keyManager),
        nostrServiceProvider.overrideWithValue(nostrService),
        relayConfigServiceProvider.overrideWithValue(relayConfigService),
        themeModeProvider.overrideWith((_) => themeNotifier),
        matchDurationProvider.overrideWith((_) => durationNotifier),
      ],
      child: const ChokeApp(),
    ),
  );
}

/// Root application widget.
///
/// Watches [localeProvider] and [themeModeProvider] to configure the app's
/// locale and theme mode. Provides both light and dark themes, with the
/// active mode determined by user preference or system setting.
class ChokeApp extends ConsumerWidget {
  const ChokeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Choke',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.home_outlined),
            ),
            activeIcon: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.home),
            ),
            label: l10n.navHome,
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.sports_martial_arts_outlined),
            ),
            activeIcon: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.sports_martial_arts),
            ),
            label: l10n.navMatch,
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.person_outline),
            ),
            activeIcon: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.person),
            ),
            label: l10n.navAccount,
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.settings_outlined),
            ),
            activeIcon: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.settings),
            ),
            label: l10n.navSettings,
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Center(
        child: Text(
          l10n.matchListPlaceholder,
          style: const TextStyle(color: BJJColors.grey, fontSize: 16),
        ),
      ),
    );
  }
}
