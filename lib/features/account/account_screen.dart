import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: BJJColors.green.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.person,
                    size: 40,
                    color: BJJColors.green,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'BJJ Practitioner',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'npub1...',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat('Matches', '0'),
                  _buildStat('Wins', '0'),
                  _buildStat('Points', '0'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Menu items
          _buildMenuItem(
            context,
            icon: Icons.key,
            title: 'Nostr Keys',
            subtitle: 'Manage your keys',
          ),
          _buildMenuItem(
            context,
            icon: Icons.share,
            title: 'Share Profile',
            subtitle: 'Share your npub',
          ),
          _buildMenuItem(
            context,
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Clear all data',
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: BJJColors.gold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: BJJColors.grey),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    bool isDestructive = false,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? BJJColors.error : BJJColors.green,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {},
      ),
    );
  }
}
