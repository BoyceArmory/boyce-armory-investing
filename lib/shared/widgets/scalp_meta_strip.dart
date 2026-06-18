import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/option_contract_model.dart';
import '../../core/theme/app_colors.dart';
import '../../features/scanner/presentation/providers/live_price_provider.dart';

/// Compact metadata strip shown on every scalp-mode alert card.
///
/// Surfaces the two numbers that decide whether a 10-minute scalp is worth
/// taking right now: a live "expires in N:NN" countdown derived from the
/// alert's createdAt + 10-minute TTL, and a theta-per-minute decay chip
/// computed from the contract's daily theta.
///
/// Why theta-per-minute: 0DTE contracts decay aggressively in the final
/// hours. Showing "θ −$0.05/min" plus the % of premium lost over a 5-min
/// hold tells the user instantly whether they can afford to wait for a
/// move or need to be filled within seconds.
///
/// Countdown ticks every second so the user can see urgency mounting.
/// When TTL has expired we still render the strip but with the countdown
/// flipped to a red "EXPIRED" label — should be filtered out upstream
/// but defensive.
class ScalpMetaStrip extends ConsumerStatefulWidget {
  const ScalpMetaStrip({
    super.key,
    required this.createdAt,
    required this.contract,
    this.symbol,
    this.entry,
    this.ttlSeconds = 600, // 10 minutes — matches backend SCALP_ALERT_TTL_MINUTES
  });

  final DateTime createdAt;
  final OptionContract? contract;

  /// Underlying ticker — when present, the strip subscribes to a 30-second
  /// polling stream and renders a live "$P (+x.xx%)" chip vs `entry`.
  final String? symbol;

  /// Entry price at fire time. Used as the baseline for the live delta
  /// chip. Falls back to no delta display when missing.
  final double? entry;
  final int ttlSeconds;

  @override
  ConsumerState<ScalpMetaStrip> createState() => _ScalpMetaStripState();
}

class _ScalpMetaStripState extends ConsumerState<ScalpMetaStrip> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 1-second cadence so the countdown reads MM:SS and the user feels
    // urgency. Single timer per card; disposed on unmount.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _remaining {
    final expiresAt = widget.createdAt.add(Duration(seconds: widget.ttlSeconds));
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get _countdownLabel {
    final r = _remaining;
    if (r == Duration.zero) return 'EXPIRED';
    final mm = r.inMinutes;
    final ss = (r.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// theta from Polygon is per-day. Convert to per-minute using 390
  /// trading minutes (6.5h * 60). Returns null when theta unavailable so
  /// caller can hide the chip entirely.
  double? get _thetaPerMin {
    final t = widget.contract?.theta;
    if (t == null) return null;
    return t.abs() / 390.0;
  }

  /// % of contract premium lost over a 5-min hold at current theta.
  /// Uses mid (or last as fallback) for the contract price. Null when
  /// neither is available.
  double? get _pctLossOver5Min {
    final tpm = _thetaPerMin;
    if (tpm == null) return null;
    final price = widget.contract?.mid ?? widget.contract?.last;
    if (price == null || price <= 0) return null;
    return (tpm * 5 / price) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining;
    final urgent = remaining.inSeconds <= 60 && remaining > Duration.zero;
    final expired = remaining == Duration.zero;
    final countdownColor = expired
        ? Colors.redAccent
        : urgent
            ? Colors.orangeAccent
            : AppColors.gold;

    final tpm = _thetaPerMin;
    final pct5 = _pctLossOver5Min;

    // Live price chip — polls /market/quote/:symbol every 30s when symbol
    // is provided. Renders nothing while the first fetch is in flight and
    // when the request errors, so the strip never shows a stale or fake
    // number. Delta vs entry uses signed % and colours green / red.
    double? livePrice;
    if (widget.symbol != null) {
      final asyncPrice = ref.watch(livePriceProvider(widget.symbol!));
      livePrice = asyncPrice.maybeWhen(
        data: (p) => p,
        orElse: () => null,
      );
    }
    final double? entry = widget.entry;
    String? liveLabel;
    Color liveColor = AppColors.gold;
    if (livePrice != null && entry != null && entry > 0) {
      final pct = ((livePrice - entry) / entry) * 100;
      liveLabel =
          '\$${livePrice.toStringAsFixed(2)} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)';
      liveColor = pct >= 0 ? Colors.greenAccent : Colors.redAccent;
    } else if (livePrice != null) {
      liveLabel = '\$${livePrice.toStringAsFixed(2)}';
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: [
        _Chip(
          icon: Icons.timer_outlined,
          label: 'EXP $_countdownLabel',
          color: countdownColor,
        ),
        if (tpm != null)
          _Chip(
            icon: Icons.trending_down,
            label: pct5 != null
                ? 'θ \$${tpm.toStringAsFixed(2)}/m · ${pct5.toStringAsFixed(0)}%/5m'
                : 'θ \$${tpm.toStringAsFixed(2)}/m',
            color: Colors.amberAccent,
          ),
        if (liveLabel != null)
          _Chip(
            icon: Icons.show_chart,
            label: liveLabel,
            color: liveColor,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
