import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../providers/admin_providers.dart';

/// Scanner Performance Dashboard tab (Sep 2026).
///
/// The dashboard itself is a web page (Chart.js breakdowns by strategy /
/// mode / symbol / regime / session, an equity curve, auto-generated
/// insights, a glossary) served by the backend and gated by a secret
/// DASHBOARD_TOKEN. Rather than reimplementing all of that natively —
/// which would mean an app rebuild + store upload every time a chart or
/// insight changes — this tab fetches the ready-to-open URL through the
/// authenticated admin session (see admin_repository.dart
/// fetchDashboardUrl()) and opens it in an in-app browser view via
/// url_launcher's LaunchMode.inAppWebView. That keeps the token out of
/// the shipped binary entirely and means the dashboard can keep evolving
/// on the backend with zero app releases.
class AnalyticsTab extends ConsumerWidget {
  const AnalyticsTab({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.inAppWebView);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the dashboard.')),
      );
    }
  }

  Future<void> _copy(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    HapticFeedback.selectionClick();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dashboard link copied'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardUrlProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.graphite,
      onRefresh: () async {
        ref.invalidate(dashboardUrlProvider);
        await ref.read(dashboardUrlProvider.future);
      },
      child: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 400,
              child: ErrorState(
                message: 'Could not load the dashboard link',
                details: e.toString(),
                onRetry: () => ref.invalidate(dashboardUrlProvider),
              ),
            ),
          ],
        ),
        data: (url) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            _Hero(onOpen: () => _open(context, url)),
            const SizedBox(height: 16),
            _InfoCard(onCopy: () => _copy(context, url)),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.steel),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.query_stats, color: AppColors.gold, size: 26),
          ),
          const SizedBox(height: 14),
          const Text(
            'Scanner Performance Dashboard',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Equity curve, win rate and expectancy by strategy / mode / symbol / '
            'regime / session, score calibration, hold time, and auto-generated '
            'plain-English insights — every grade, all-time by default.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.obsidian,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text(
                'Open Dashboard',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.onCopy});
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.steel),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textTertiary, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Opens inside the app — no separate login. Data is pulled live '
              'from every shadow-tracked trade, updated on every reload.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4),
            ),
          ),
          TextButton.icon(
            onPressed: onCopy,
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copy link',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
