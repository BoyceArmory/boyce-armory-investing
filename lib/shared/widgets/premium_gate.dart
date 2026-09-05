import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_state_provider.dart';
import '../../core/routing/route_paths.dart';
import '../../core/theme/app_colors.dart';

/// Wraps a premium-only feature (Scanner, ADMIN BUYS, Learn — Sep 2026).
/// Admins and premium-tier customers see [child] unchanged; everyone else
/// sees a locked upsell card instead of the feature content.
///
/// This is a UX convenience, not the security boundary — the real
/// enforcement is firestore.rules' isPremium(). A user who somehow bypasses
/// this widget just hits permission-denied on the underlying Firestore
/// read instead of a friendly lock screen.
///
/// There's no self-serve purchase flow yet (no Stripe/IAP wired up), so the
/// CTA here routes to the existing support-ticket screen rather than a
/// checkout — upgrading today is still an admin-side action
/// (users_tab.dart "Set tier: premium").
class PremiumGate extends ConsumerWidget {
  const PremiumGate({
    super.key,
    required this.featureName,
    required this.description,
    required this.child,
  });

  final String featureName;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool unlocked = ref.watch(hasPremiumAccessProvider);
    if (unlocked) return child;
    return _PremiumLockedView(
      featureName: featureName,
      description: description,
    );
  }
}

class _PremiumLockedView extends StatelessWidget {
  const _PremiumLockedView({
    required this.featureName,
    required this.description,
  });

  final String featureName;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(Icons.lock_outline,
                  color: AppColors.gold, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              '$featureName is a premium feature',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(RoutePaths.supportTicket),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Contact us to upgrade',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
