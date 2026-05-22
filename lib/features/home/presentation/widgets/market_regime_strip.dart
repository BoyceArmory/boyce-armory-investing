import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/home_overview_model.dart';
import '../providers/home_providers.dart';

/// Slim regime + open/close countdown strip. Designed to slot above or below
/// the MarketPulseCard without competing with the brand artwork — uses the
/// same graphite/steel palette as other layered cards.
class MarketRegimeStrip extends ConsumerWidget {
  const MarketRegimeStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeOverviewStreamProvider);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border.all(color: AppColors.steel),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          async.when(
            loading: () => _RegimeBadge.loading(),
            error: (_, __) => _RegimeBadge.unavailable(),
            data: (o) => _RegimeBadge(regime: o.regime),
          ),
          const Spacer(),
          const _MarketCountdown(),
        ],
      ),
    );
  }
}

class _RegimeBadge extends StatelessWidget {
  const _RegimeBadge({required this.regime}) : _loading = false, _err = false;
  _RegimeBadge.loading()
      : regime = const MarketRegime.empty(), _loading = true, _err = false;
  _RegimeBadge.unavailable()
      : regime = const MarketRegime.empty(), _loading = false, _err = true;
  final MarketRegime regime;
  final bool _loading;
  final bool _err;

  Color get _color {
    if (_loading || _err) return AppColors.textTertiary;
    switch (regime.color) {
      case 'green': return AppColors.bullish;
      case 'amber': return AppColors.warning;
      case 'red': return AppColors.bearish;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _loading
        ? 'LOADING…'
        : _err
            ? 'DATA UNAVAILABLE'
            : regime.label.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: _color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
        ],
      ),
    );
  }
}

class _MarketCountdown extends StatefulWidget {
  const _MarketCountdown();
  @override
  State<_MarketCountdown> createState() => _MarketCountdownState();
}

class _MarketCountdownState extends State<_MarketCountdown> {
  late final Timer _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }
  @override
  void dispose() { _t.cancel(); super.dispose(); }

  ({String label, bool isOpen}) _next() {
    final now = DateTime.now().toUtc();
    final isDst = _isUsDst(now);
    final et = now.add(Duration(hours: isDst ? -4 : -5));
    final weekday = et.weekday;
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      final daysUntilMon = (8 - weekday) % 7 == 0 ? 1 : (8 - weekday) % 7;
      final nextOpen = DateTime(et.year, et.month, et.day, 9, 30)
          .add(Duration(days: daysUntilMon));
      return (label: 'Opens ${_fmt(nextOpen.difference(et))}', isOpen: false);
    }
    final open = DateTime(et.year, et.month, et.day, 9, 30);
    final close = DateTime(et.year, et.month, et.day, 16, 0);
    if (et.isBefore(open)) return (label: 'Opens in ${_fmt(open.difference(et))}', isOpen: false);
    if (et.isBefore(close)) return (label: 'Closes in ${_fmt(close.difference(et))}', isOpen: true);
    final daysAhead = weekday == DateTime.friday ? 3 : 1;
    final nextOpen = open.add(Duration(days: daysAhead));
    return (label: 'Opens ${_fmt(nextOpen.difference(et))}', isOpen: false);
  }

  String _fmt(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  bool _isUsDst(DateTime utc) {
    final y = utc.year;
    final marchSecondSunday = _nthSunday(y, 3, 2);
    final novFirstSunday = _nthSunday(y, 11, 1);
    final dstStart = DateTime.utc(y, 3, marchSecondSunday, 7);
    final dstEnd = DateTime.utc(y, 11, novFirstSunday, 6);
    return utc.isAfter(dstStart) && utc.isBefore(dstEnd);
  }

  int _nthSunday(int year, int month, int n) {
    int day = 1, count = 0;
    while (day <= 31) {
      final d = DateTime(year, month, day);
      if (d.month != month) break;
      if (d.weekday == DateTime.sunday) {
        count++;
        if (count == n) return day;
      }
      day++;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final r = _next();
    final color = r.isOpen ? AppColors.bullish : AppColors.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(r.isOpen ? Icons.fiber_manual_record : Icons.access_time, size: 12, color: color),
        const SizedBox(width: 6),
        Text(r.label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      ],
    );
  }
}
