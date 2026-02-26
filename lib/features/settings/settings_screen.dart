import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Appearance
          _buildSectionTitle(context, 'Appearance'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Always use dark theme'),
                  value: true,
                  onChanged: (value) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Nostr
          _buildSectionTitle(context, 'Nostr'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dns, color: BJJColors.green),
                  title: const Text('Relays'),
                  subtitle: const Text('Manage relay connections'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security, color: BJJColors.green),
                  title: const Text('Key Management'),
                  subtitle: const Text('Backup and restore keys'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Match
          _buildSectionTitle(context, 'Match'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.timer, color: BJJColors.green),
                  title: const Text('Default Match Duration'),
                  subtitle: const Text('5 minutes'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Sound Effects'),
                  subtitle: const Text('Play sounds during scoring'),
                  value: true,
                  onChanged: (value) {},
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Vibration'),
                  subtitle: const Text('Vibrate on point scored'),
                  value: true,
                  onChanged: (value) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // About
          _buildSectionTitle(context, 'About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: BJJColors.green,
                  ),
                  title: const Text('Version'),
                  subtitle: const Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code, color: BJJColors.green),
                  title: const Text('Source Code'),
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
