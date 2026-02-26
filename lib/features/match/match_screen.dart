import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Match')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_martial_arts,
              size: 64,
              color: BJJColors.green.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Match',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create or join a match to start scoring',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Create New Match'),
            ),
          ],
        ),
      ),
    );
  }
}
