import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/engagement_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Three-button row at the bottom of every customer alert card:
///
///   [ I TOOK IT ]   [ WATCHING ]   [ PASS ]
///
/// Captures real engagement so we can:
///   - Build a "real trades from alerts" dataset (vs shadow simulated)
///   - Measure conversion (what % of alerts trigger an action)
///   - Feed setup_stats with REAL outcomes when users mark "took"
///   - Personalize the experience over time
///
/// Optimistic UI: button highlights immediately on tap, network roundtrip
/// happens in the background. Failure silently reverts; the next refresh
/// reconciles. We never want the user to wait on the server for visual
/// feedback on a tap that primarily benefits us.
class AlertActionBar extends ConsumerStatefulWidget {
  const AlertActionBar({
    super.key,
    required this.alertId,
    required this.grade,
  });
  final String alertId;
  final String grade;

  @override
  ConsumerState<AlertActionBar> createState() => _AlertActionBarState();
}

class _AlertActionBarState extends ConsumerState<AlertActionBar> {
  String? _current;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final EngagementService svc = ref.read(engagementServiceProvider);
    final String? prior = await svc.getAction(widget.alertId);
    if (!mounted) return;
    setState(() {
      _current = prior;
      _hydrated = true;
    });
  }

  Future<void> _set(String action) async {
    setState(() => _current = action);
    AnalyticsService.alertActioned(
      alertId: widget.alertId,
      action: action,
      grade: widget.grade,
    );
    final EngagementService svc = ref.read(engagementServiceProvider);
    final bool ok = await svc.setAction(widget.alertId, action);
    if (!ok && mounted) {
      // Revert on failure — we shouldn't lie about what got saved.
      setState(() => _current = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          _ActionButton(
            label: 'TOOK IT',
            icon: Icons.check_circle_outline,
            selected: _current == 'took',
            disabled: !_hydrated,
            color: const Color(0xFF8FD89F),
            onTap: () => _set('took'),
          ),
          _ActionButton(
            label: 'WATCHING',
            icon: Icons.visibility_outlined,
            selected: _current == 'watching',
            disabled: !_hydrated,
            color: AppColors.gold,
            onTap: () => _set('watching'),
          ),
          _ActionButton(
            label: 'PASS',
            icon: Icons.close,
            selected: _current == 'pass',
            disabled: !_hydrated,
            color: const Color(0xFFE07A6B),
            onTap: () => _set('pass'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.disabled,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final bool disabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color base = disabled ? Colors.white24 : color;
    return Expanded(
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? base.withValues(alpha: 0.18)
                : Colors.transparent,
            border: Border.all(
              color: selected ? base : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 14, color: selected ? base : Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? base : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
