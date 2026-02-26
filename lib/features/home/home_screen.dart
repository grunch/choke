import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: BJJColors.navy,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choke',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: BJJColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Score your BJJ matches',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: BJJColors.grey),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BJJColors.navyDark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: BJJColors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: BJJColors.navyDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: BJJColors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: BJJColors.white),
                            decoration: InputDecoration(
                              hintText: 'Search matches or gyms...',
                              hintStyle: TextStyle(
                                color: BJJColors.grey.withValues(alpha: 0.6),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Sheet Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: BJJColors.offWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: Match Types
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Match Types',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: BJJColors.navy,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'All >',
                              style: TextStyle(color: BJJColors.green),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildMatchTypeCard(
                            context,
                            icon: Icons.sports_mma,
                            title: 'Gi',
                            count: '12 active',
                            color: BJJColors.green,
                            bgColor: const Color(0xFFE8F5E9),
                          ),
                          const SizedBox(width: 12),
                          _buildMatchTypeCard(
                            context,
                            icon: Icons.sports_kabaddi,
                            title: 'No-Gi',
                            count: '8 active',
                            color: BJJColors.gold,
                            bgColor: const Color(0xFFFFF8E1),
                          ),
                          const SizedBox(width: 12),
                          _buildMatchTypeCard(
                            context,
                            icon: Icons.emoji_events,
                            title: 'Open Mat',
                            count: '4 gyms',
                            color: BJJColors.navy,
                            bgColor: const Color(0xFFE3F2FD),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Section: Gyms Near You
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Gyms Near You',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: BJJColors.navy,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Map >',
                              style: TextStyle(color: BJJColors.green),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildGymCard(
                        context,
                        name: 'Gracie Barra Buenos Aires',
                        hours: '6 AM - 10 PM',
                        specialties: ['Gi', 'No-Gi', 'Competition'],
                        statusColor: BJJColors.green,
                        isOpen: true,
                      ),
                      const SizedBox(height: 12),
                      _buildGymCard(
                        context,
                        name: 'Alliance Academy',
                        hours: '7 AM - 9 PM',
                        specialties: ['Gi', 'MMA'],
                        statusColor: BJJColors.gold,
                        isOpen: false,
                      ),
                      const SizedBox(height: 32),

                      // Quick Actions
                      Text(
                        'Quick Start',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: BJJColors.navy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildQuickActionButton(
                        context,
                        icon: Icons.add_circle,
                        title: 'Create New Match',
                        subtitle: 'Start scoring a match now',
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _buildQuickActionButton(
                        context,
                        icon: Icons.qr_code_scanner,
                        title: 'Join Match',
                        subtitle: 'Scan QR to join as scorer',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchTypeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String count,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: BJJColors.navy,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(color: BJJColors.greyDark, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGymCard(
    BuildContext context, {
    required String name,
    required String hours,
    required List<String> specialties,
    required Color statusColor,
    required bool isOpen,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BJJColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: BJJColors.navy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.location_on, color: statusColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: BJJColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hours,
                  style: TextStyle(color: BJJColors.greyDark, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: specialties.map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: BJJColors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          color: BJJColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BJJColors.navy,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BJJColors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: BJJColors.green),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: BJJColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: BJJColors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: BJJColors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
