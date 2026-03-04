import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/providers/locale_provider.dart';
import 'screens/relay_management_screen.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Language
          _buildSectionTitle(context, l10n.sectionLanguage),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: BJJColors.green),
              title: Text(l10n.language),
              subtitle: Text(
                currentLocale != null
                    ? _localeNames[currentLocale.languageCode] ?? currentLocale.languageCode
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
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.darkMode),
                  subtitle: Text(l10n.alwaysUseDarkTheme),
                  value: true,
                  onChanged: (value) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Nostr
          _buildSectionTitle(context, l10n.sectionNostr),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dns, color: BJJColors.green),
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
            child: ListTile(
              leading: const Icon(Icons.timer, color: BJJColors.green),
              title: Text(l10n.defaultMatchDuration),
              subtitle: Text(l10n.fiveMinutes),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 16),
          // About
          _buildSectionTitle(context, l10n.sectionAbout),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: BJJColors.green,
                  ),
                  title: Text(l10n.version),
                  subtitle: const Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code, color: BJJColors.green),
                  title: Text(l10n.sourceCode),
                  subtitle: const Text('github.com/grunch/choke'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.read(localeProvider);
    final currentCode = currentLocale?.languageCode ??
        Localizations.localeOf(context).languageCode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BJJColors.navyDark,
        title: Text(
          l10n.selectLanguage,
          style: const TextStyle(color: BJJColors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // System default option
            ListTile(
              title: Text(
                l10n.systemDefault,
                style: TextStyle(
                  color: currentLocale == null ? BJJColors.green : BJJColors.white,
                  fontWeight: currentLocale == null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: currentLocale == null
                  ? const Icon(Icons.check, color: BJJColors.green)
                  : null,
              onTap: () {
                ref.read(localeProvider.notifier).state = null;
                Navigator.pop(ctx);
              },
            ),
            const Divider(color: BJJColors.greyDark),
            // Language options
            ..._localeNames.entries.map((entry) {
              final isSelected = currentLocale != null && entry.key == currentCode;
              return ListTile(
                title: Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected ? BJJColors.green : BJJColors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: BJJColors.green)
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: BJJColors.grey,
              letterSpacing: 1.5,
            ),
      ),
    );
  }
}
