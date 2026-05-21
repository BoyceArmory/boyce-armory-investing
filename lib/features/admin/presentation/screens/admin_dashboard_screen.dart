import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/premium_card.dart';
import '../../../../shared/widgets/section_header.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isAdmin = ref.watch(isAdminProvider);
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        title: const Text('Admin'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RoutePaths.home),
        ),
      ),
      body: SafeArea(
        child: !isAdmin
            ? const EmptyState(
                icon: Icons.lock_outline,
                title: 'Admin only',
                message:
                    'This dashboard is restricted to admin accounts.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: <Widget>[
                  const SectionHeader(
                    eyebrow: 'Internal',
                    title: 'Admin Dashboard',
                  ),
                  const SizedBox(height: 16),
                  PremiumCard(
                    accent: PremiumCardAccent.gold,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Scanner ops, alert publishing, push controls, and analytics will live here.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 14),
                        const _AdminRow(
                            label: 'Run scanner', icon: Icons.radar),
                        const _AdminRow(
                            label: 'Manage alerts',
                            icon: Icons.campaign_outlined),
                        const _AdminRow(
                            label: 'Promote setup',
                            icon: Icons.local_fire_department_outlined),
                        const _AdminRow(
                            label: 'User management',
                            icon: Icons.people_outline),
                        const _AdminRow(
                            label: 'Push notifications',
                            icon: Icons.notifications_active_outlined),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AdminRow extends StatelessWidget {
  const _AdminRow({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 16, color: AppColors.gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
          const Icon(Icons.lock_clock, color: AppColors.textTertiary, size: 16),
        ],
      ),
    );
  }
}
