import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choke'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Choke',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create and score BJJ matches in real-time via Nostr.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _buildActionCard(
              context,
              icon: Icons.add_circle_outline,
              title: 'Create Match',
              subtitle: 'Start a new BJJ match',
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              icon: Icons.qr_code_scanner,
              title: 'Join Match',
              subtitle: 'Scan QR to join a match',
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              icon: Icons.history,
              title: 'Recent Matches',
              subtitle: 'View your match history',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: BJJColors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: BJJColors.green),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
