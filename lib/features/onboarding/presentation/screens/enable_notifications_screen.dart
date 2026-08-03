import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Push opt-in priming screen.
///
/// Shown ONCE after sign-up before the OS permission prompt. Sells WHY
/// the user wants notifications enabled — A+ alerts during market hours,
/// with the per-mode and quiet-hours controls preserved.
///
/// Industry practice: priming the user with context before the OS prompt
/// roughly doubles opt-in rates vs the cold OS dialog (~70% vs ~40%).
/// The OS prompt cannot be re-shown after the user denies it once, so
/// the cold-prompt path is one-shot — getting this right matters.
class EnableNotificationsScreen extends ConsumerStatefulWidget {
  const EnableNotificationsScreen({super.key});

  @override
  ConsumerState<EnableNotificationsScreen> createState() =>
      _EnableNotificationsScreenState();
}

class _EnableNotificationsScreenState
    extends ConsumerState<EnableNotificationsScreen> {
  bool _requesting = false;

  Future<void> _enable() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final bool granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) {
        AnalyticsService.notificationsEnabled();
      } else {
        AnalyticsService.notificationsDenied();
      }
    } catch (_) {
      AnalyticsService.notificationsDenied();
    }
    // Always continue, but only if still mounted. Moved out of `finally`
    // because `return` in a finally clause swallows any pending exception
    // (lint: control_flow_in_finally).
    if (!mounted) return;
    _continueToApp();
  }

  void _skip() {
    AnalyticsService.notificationsDenied();
    _continueToApp();
  }

  void _continueToApp() {
    if (!mounted) return;
    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.notifications_active,
                  color: AppColors.gold, size: 56),
              const SizedBox(height: 24),
              const Text(
                "Don't miss\nA+ setups.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Smart Alerts ping you only when the scanner finds an A+ '
                'graded setup — fewer than 5 per session on average. '
                'You control the rest in Settings.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              const _BenefitRow(
                icon: Icons.bolt,
                title: 'Real-time A+ alerts',
                subtitle:
                    'Push as soon as a top-grade setup fires — never miss the entry window.',
              ),
              const SizedBox(height: 18),
              const _BenefitRow(
                icon: Icons.tune,
                title: 'You control everything',
                subtitle:
                    'Choose mode (Swing / LEAPS), minimum grade, and quiet hours.',
              ),
              const SizedBox(height: 18),
              const _BenefitRow(
                icon: Icons.lock_clock,
                title: 'Quiet by default outside market hours',
                subtitle:
                    'Nothing on nights, weekends, or holidays unless you opt in.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requesting ? null : _enable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.obsidian,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _requesting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.obsidian,
                          ),
                        )
                      : const Text(
                          'Enable Smart Alerts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _requesting ? null : _skip,
                child: Text(
                  'Not now',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.gold, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
