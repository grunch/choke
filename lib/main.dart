import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'shared/theme/app_theme.dart';
import 'shared/providers/locale_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/match_duration_provider.dart';
import 'shared/providers/match_sound_provider.dart';
import 'features/home/home_screen.dart';

import 'features/account/account_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/match/providers/submissions_provider.dart';
import 'features/settings/providers/relay_config_provider.dart';
import 'services/key_management/key_manager.dart';
import 'services/nostr/crypto/nostr_crypto.dart';
import 'services/nostr/crypto/rust_nostr_crypto.dart';
import 'services/nostr/nostr_service.dart';
import 'services/nostr/relay/nostr_relay_backend.dart';
import 'services/nostr/relay/rust_relay_backend.dart';
import 'src/rust/frb_generated.dart';

/// Load the native library the app's Nostr stack is built on.
///
/// Deliberately not wrapped in a try/catch, unlike every other initialization
/// in `main()`. Without it nothing can be signed and nothing can be published,
/// so the app could only limp on doing neither — a referee would score a whole
/// match into the void and find out afterwards. Failing at launch is the honest
/// outcome, and CI's Android job links exactly this path.
Future<void> _initRust() => RustLib.init();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initRust();

  // The Nostr stack, in one place. Both sides are interfaces (NostrCrypto,
  // NostrRelayBackend) so the app never names an implementation twice — which
  // is what made swapping them a flag, and then a deletion.
  final NostrCrypto crypto = const RustNostrCrypto();

  // Initialize KeyManager
  final keyManager = KeyManager(crypto: crypto);
  try {
    await keyManager.initialize();
  } catch (_) {
    // Not logging the exception object: initialize() derives from stored key
    // material, so its message can carry that material into the device log —
    // and debugPrint is not stripped from release builds. KeyManager keeps
    // this invariant everywhere else; this catch must not be the one leak.
    debugPrint('KeyManager initialization failed');
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
  final nostrService = NostrService(
    keyManager,
    crypto: crypto,
    backend: RustRelayBackend(),
  );
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
  final savedLocale = await LocaleNotifier.loadSavedLocale();
  final savedDuration = await MatchDurationNotifier.loadSavedDuration();
  final savedSubmissions = await SubmissionsNotifier.loadSaved();
  final savedMatchSound = await MatchSoundEnabledNotifier.loadSaved();

  // Create notifiers with hydrated values (no flash on startup)
  final themeNotifier = ThemeModeNotifier()..hydrate(savedThemeMode);
  final localeNotifier = LocaleNotifier()..hydrate(savedLocale);
  final durationNotifier = MatchDurationNotifier()..hydrate(savedDuration);
  final submissionsNotifier = SubmissionsNotifier()..hydrate(savedSubmissions);
  final matchSoundNotifier = MatchSoundEnabledNotifier()
    ..hydrate(savedMatchSound);

  runApp(
    ProviderScope(
      overrides: [
        nostrCryptoProvider.overrideWithValue(crypto),
        keyManagerProvider.overrideWithValue(keyManager),
        nostrServiceProvider.overrideWithValue(nostrService),
        relayConfigServiceProvider.overrideWithValue(relayConfigService),
        themeModeProvider.overrideWith((_) => themeNotifier),
        localeProvider.overrideWith((_) => localeNotifier),
        matchDurationProvider.overrideWith((_) => durationNotifier),
        submissionsProvider.overrideWith((_) => submissionsNotifier),
        matchSoundEnabledProvider.overrideWith((_) => matchSoundNotifier),
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
///
/// Also watches the app lifecycle: relay sockets rarely survive
/// backgrounding — the OS kills them without a close frame, leaving
/// connections that look open but drop every event — so on resume all
/// relay connections are recycled before the operator's next action.
class ChokeApp extends ConsumerStatefulWidget {
  const ChokeApp({super.key});

  @override
  ConsumerState<ChokeApp> createState() => _ChokeAppState();
}

class _ChokeAppState extends ConsumerState<ChokeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(nostrServiceProvider).reconnectAll();
    }
  }

  @override
  Widget build(BuildContext context) {
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
    const AccountScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _ChokeNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          (Icons.home_outlined, l10n.navHome),
          (Icons.person_outline, l10n.navAccount),
          (Icons.settings_outlined, l10n.navSettings),
        ],
      ),
    );
  }
}

/// Bottom navigation styled after the ChokeNav design component:
/// translucent scaffold-colored bar with backdrop blur, hairline top
/// border, 23px stroke icons and 11px labels. Active item tints green;
/// the icon shape never changes, only its color.
class _ChokeNavBar extends StatelessWidget {
  const _ChokeNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tk = ChokeTokens.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.fromLTRB(6, 10, 6, 16 + bottomInset),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withValues(alpha: .92),
            border: Border(top: BorderSide(color: tk.cardBorder)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _buildItem(context, tk, i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, ChokeTokens tk, int index) {
    final (icon, label) = items[index];
    final isActive = index == currentIndex;
    final color = isActive ? tk.accent : tk.faint;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
