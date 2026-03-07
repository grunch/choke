import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/providers/theme_provider.dart';
import '../../shared/providers/match_duration_provider.dart';
import 'screens/relay_management_screen.dart';

/// Provider for package info
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// Map of supported locales to their display names
const _localeNames = {
  'en': 'English',
  'es': 'Español',
  'pt': 'Português (Brasil)',
  'ja': '日本語',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Language
          _buildSectionTitle(context, l10n.sectionLanguage),
          Card(
            child: ListTile(
              leading: Icon(Icons.language, color: colors.primary),
              title: Text(l10n.language),
              subtitle: Text(
                currentLocale != null
                    ? _localeNames[currentLocale.languageCode] ??
                        currentLocale.languageCode
                    : l10n.systemDefault,
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showLanguagePicker(context, ref),
            ),
          ),
          const SizedBox(height: 16),
          // Appearance
          _buildSectionTitle(context, l10n.sectionAppearance),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette, color: colors.primary),
                      const SizedBox(width: 12),
                      Text(
                        l10n.themeMode,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          icon: const Icon(Icons.brightness_auto),
                          label: Text(l10n.systemDefault),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          icon: const Icon(Icons.dark_mode),
                          label: Text(l10n.dark),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          icon: const Icon(Icons.light_mode),
                          label: Text(l10n.light),
                        ),
                      ],
                      selected: {currentThemeMode},
                      onSelectionChanged: (Set<ThemeMode> selected) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(selected.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.followSystemTheme,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Nostr
          _buildSectionTitle(context, l10n.sectionNostr),
          Card(
            child: ListTile(
              leading: Icon(Icons.dns, color: colors.primary),
              title: Text(l10n.relays),
              subtitle: Text(l10n.manageRelayConnections),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RelayManagementScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Match
          _buildSectionTitle(context, l10n.sectionMatch),
          Card(
            child: Consumer(
              builder: (context, ref, _) {
                final duration = ref.watch(matchDurationProvider);
                return ListTile(
                  leading: Icon(Icons.timer, color: colors.primary),
                  title: Text(l10n.defaultMatchDuration),
                  subtitle: Text(formatDuration(duration)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showDurationPicker(context, ref, duration),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // About
          _buildSectionTitle(context, l10n.sectionAbout),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.code, color: colors.primary),
                  title: Text(l10n.sourceCode),
                  subtitle: const Text('github.com/grunch/choke'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => launchUrl(
                    Uri.parse('https://github.com/grunch/choke'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.description, color: colors.primary),
                  title: Text(l10n.licenseLabel),
                  subtitle: Text(l10n.licenseSubtitle),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showLicenseScreen(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Built by Pana footer
          Consumer(
            builder: (context, ref, child) {
              final packageInfo = ref.watch(packageInfoProvider);
              final versionText = packageInfo.when(
                data: (info) => 'v${info.version}',
                loading: () => '...',
                error: (error, stackTrace) {
                  debugPrint('Failed to load package info: $error');
                  return '—';
                },
              );
              return Center(
                child: Column(
                  children: [
                    const Text(
                      '⬛⬛⬛🟥⬛',
                      style: TextStyle(fontSize: 12, letterSpacing: 2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Built by Pana',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      versionText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showDurationPicker(
    BuildContext context,
    WidgetRef ref,
    int currentDuration,
  ) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.defaultMatchDuration),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: defaultDurationOptions.map((seconds) {
              final isSelected = seconds == currentDuration;
              return ListTile(
                title: Text(formatDuration(seconds)),
                trailing: isSelected
                    ? Icon(Icons.check, color: colors.primary)
                    : null,
                selected: isSelected,
                selectedColor: colors.primary,
                onTap: () {
                  ref.read(matchDurationProvider.notifier).setDuration(seconds);
                  Navigator.pop(dialogContext);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final currentLocale = ref.read(localeProvider);
    final currentCode = currentLocale?.languageCode ??
        Localizations.localeOf(context).languageCode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // System default option
            ListTile(
              title: Text(
                l10n.systemDefault,
                style: TextStyle(
                  color: currentLocale == null
                      ? colors.primary
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: currentLocale == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              trailing: currentLocale == null
                  ? Icon(Icons.check, color: colors.primary)
                  : null,
              onTap: () {
                ref.read(localeProvider.notifier).state = null;
                Navigator.pop(ctx);
              },
            ),
            const Divider(),
            // Language options
            ..._localeNames.entries.map((entry) {
              final isSelected =
                  currentLocale != null && entry.key == currentCode;
              return ListTile(
                title: Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected
                        ? colors.primary
                        : Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: colors.primary)
                    : null,
                onTap: () {
                  ref.read(localeProvider.notifier).state = Locale(entry.key);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showLicenseScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.licenseTitle),
        content: SingleChildScrollView(
          child: Text(AppLocalizations.of(context)!.licenseText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              letterSpacing: 1.5,
            ),
      ),
    );
  }
}
