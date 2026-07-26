import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/providers/theme_provider.dart';
import '../../shared/providers/match_duration_provider.dart';
import '../../shared/providers/match_sound_provider.dart';
import '../../shared/theme/app_theme.dart';
import 'screens/relay_management_screen.dart';
import 'screens/submissions_screen.dart';

/// Provider for package info
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// Map of supported locales to their display names.
///
/// Public so tests assert against the same source the UI renders from,
/// instead of duplicating the localized labels.
const localeDisplayNames = {
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
    final tk = ChokeTokens.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 2, 14),
              child: Text(
                l10n.settingsTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),

            // Language
            _buildSectionTitle(context, l10n.sectionLanguage, tk),
            _buildListRow(
              context: context,
              tk: tk,
              icon: Icons.language,
              title: l10n.language,
              subtitle: currentLocale != null
                  ? localeDisplayNames[currentLocale.languageCode] ??
                      currentLocale.languageCode
                  : l10n.systemDefault,
              onTap: () => _showLanguagePicker(context, ref),
            ),
            const SizedBox(height: 18),

            // Appearance — 3-segment theme selector, single line
            _buildSectionTitle(context, l10n.sectionAppearance, tk),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: tk.card,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: tk.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildIconTile(tk, Icons.contrast),
                      const SizedBox(width: 11),
                      Text(
                        l10n.themeMode,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  _buildThemeSegments(context, ref, currentThemeMode, tk),
                  const SizedBox(height: 11),
                  Text(
                    l10n.followSystemTheme,
                    style: TextStyle(fontSize: 12, color: tk.faint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Nostr
            _buildSectionTitle(context, l10n.sectionNostr, tk),
            _buildListRow(
              context: context,
              tk: tk,
              icon: Icons.dns_outlined,
              title: l10n.relays,
              subtitle: l10n.manageRelayConnections,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RelayManagementScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),

            // Match
            _buildSectionTitle(context, l10n.sectionMatch, tk),
            Consumer(
              builder: (context, ref, _) {
                final duration = ref.watch(matchDurationProvider);
                return _buildListRow(
                  context: context,
                  tk: tk,
                  icon: Icons.timer_outlined,
                  title: l10n.defaultMatchDuration,
                  subtitle: formatDuration(duration),
                  subtitleStyle: TextStyle(
                    color: tk.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                  onTap: () => _showDurationPicker(context, ref, duration),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildListRow(
              context: context,
              tk: tk,
              icon: Icons.sports_martial_arts_outlined,
              title: l10n.settingsSubmissions,
              subtitle: l10n.settingsSubmissionsDesc,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SubmissionsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final enabled = ref.watch(matchSoundEnabledProvider);
                return _buildSwitchRow(
                  context: context,
                  tk: tk,
                  icon: enabled ? Icons.volume_up_outlined : Icons.volume_off,
                  title: l10n.settingsMatchSound,
                  subtitle: enabled
                      ? l10n.settingsMatchSoundOn
                      : l10n.settingsMatchSoundOff,
                  value: enabled,
                  onChanged: (value) => ref
                      .read(matchSoundEnabledProvider.notifier)
                      .setEnabled(value),
                );
              },
            ),
            const SizedBox(height: 18),

            // About
            _buildSectionTitle(context, l10n.sectionAbout, tk),
            _buildListRow(
              context: context,
              tk: tk,
              icon: Icons.language,
              title: l10n.website,
              subtitle: 'protolayer.io/choke',
              trailingIcon: Icons.open_in_new,
              onTap: () => launchUrl(
                Uri.parse('https://protolayer.io/choke'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const SizedBox(height: 8),
            _buildListRow(
              context: context,
              tk: tk,
              icon: Icons.code,
              title: l10n.sourceCode,
              subtitle: 'github.com/protolayer-io/choke',
              trailingIcon: Icons.open_in_new,
              onTap: () => launchUrl(
                Uri.parse('https://github.com/protolayer-io/choke'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const SizedBox(height: 8),
            _buildListRow(
              context: context,
              tk: tk,
              icon: Icons.description_outlined,
              title: l10n.licenseLabel,
              subtitle: l10n.licenseSubtitle,
              onTap: () => _showLicenseScreen(context),
            ),
            const SizedBox(height: 32),

            // Built by ProtoLayer footer
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
                final isDark = theme.brightness == Brightness.dark;
                return Center(
                  child: Column(
                    children: [
                      Semantics(
                        link: true,
                        child: InkWell(
                          onTap: () => launchUrl(
                            Uri.parse('https://protolayer.io'),
                            mode: LaunchMode.externalApplication,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              l10n.builtBy('ProtoLayer'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tk.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        link: true,
                        child: InkWell(
                          onTap: () => launchUrl(
                            Uri.parse('https://protolayer.io'),
                            mode: LaunchMode.externalApplication,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: isDark
                                ? BoxDecoration(
                                    // Lighter backdrop so the black belt reads
                                    // against the dark theme. At 0.08 the belt
                                    // was all but invisible on the ink
                                    // scaffold; past ~0.32 the tile becomes a
                                    // grey block that pulls focus.
                                    color: colors.onSurface
                                        .withValues(alpha: 0.24),
                                    borderRadius: BorderRadius.circular(16),
                                  )
                                : null,
                            child: Image.asset(
                              'assets/branding/bjj_black_belt.webp',
                              width: 120,
                              fit: BoxFit.contain,
                              semanticLabel: l10n.bjjBlackBelt,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
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
      ),
    );
  }

  Widget _buildIconTile(ChokeTokens tk, IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: tk.accent.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: tk.accent, size: 20),
    );
  }

  Widget _buildListRow({
    required BuildContext context,
    required ChokeTokens tk,
    required IconData icon,
    required String title,
    required String subtitle,
    TextStyle? subtitleStyle,
    IconData trailingIcon = Icons.chevron_right,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: tk.card,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: tk.cardBorder),
        ),
        child: Row(
          children: [
            _buildIconTile(tk, icon),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: subtitleStyle ??
                        TextStyle(fontSize: 12.5, color: tk.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(trailingIcon, color: tk.faint, size: 19),
          ],
        ),
      ),
    );
  }

  /// A [_buildListRow] that carries a switch instead of a chevron.
  ///
  /// The whole row toggles, not just the switch: these rows are the width of
  /// the screen and the switch is a thumb-wide target at the far edge of it.
  Widget _buildSwitchRow({
    required BuildContext context,
    required ChokeTokens tk,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 13, 9, 13),
          decoration: BoxDecoration(
            color: tk.card,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: tk.cardBorder),
          ),
          child: Row(
            children: [
              _buildIconTile(tk, icon),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: tk.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Custom 3-segment theme selector — always a single line
  Widget _buildThemeSegments(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
    ChokeTokens tk,
  ) {
    final l10n = AppLocalizations.of(context);
    final segments = [
      (ThemeMode.system, Icons.brightness_auto_outlined, l10n.systemDefault),
      (ThemeMode.dark, Icons.dark_mode_outlined, l10n.dark),
      (ThemeMode.light, Icons.light_mode_outlined, l10n.light),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tk.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tk.cardBorder),
      ),
      child: Row(
        children: segments.map((seg) {
          final (mode, icon, label) = seg;
          final isSelected = current == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  ref.read(themeModeProvider.notifier).setThemeMode(mode),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: isSelected ? tk.gradient : null,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? Icons.check : icon,
                      size: 15,
                      color: isSelected ? tk.onGrad : tk.muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? tk.onGrad : tk.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
              onTap: () => _applyLocale(ctx, ref, null),
            ),
            const Divider(),
            // Language options
            ...localeDisplayNames.entries.map((entry) {
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
                onTap: () => _applyLocale(ctx, ref, Locale(entry.key)),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Applies a language choice made in the picker.
  ///
  /// The picker closes only once the choice has been stored: a selection that
  /// could not be written would come back as the system language on the next
  /// launch, so dismissing on it would mime an acceptance that never happened.
  /// On failure the dialog stays put and says so in the user's current
  /// language — the cause is logged by the notifier, not shown here.
  Future<void> _applyLocale(
    BuildContext pickerContext,
    WidgetRef ref,
    Locale? locale,
  ) async {
    final l10n = AppLocalizations.of(pickerContext);
    final messenger = ScaffoldMessenger.of(pickerContext);
    final colors = Theme.of(pickerContext).colorScheme;

    try {
      await ref.read(localeProvider.notifier).setLocale(locale);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.languageSaveFailed),
          backgroundColor: colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!pickerContext.mounted) return;
    Navigator.pop(pickerContext);
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

  Widget _buildSectionTitle(
      BuildContext context, String title, ChokeTokens tk) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 9),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: tk.sectionTint,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
