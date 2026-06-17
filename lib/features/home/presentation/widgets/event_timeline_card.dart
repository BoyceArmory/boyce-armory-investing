import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/home_overview_model.dart';
import '../providers/home_providers.dart';

/// Today's high-impact econ events (CPI, FOMC, NFP, etc.).
/// Empty list = no card shown.
class EventTimelineCard extends ConsumerWidget {
  const EventTimelineCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeOverviewStreamProvider);
    return async.maybeWhen(
      data: (o) {
        final events = o.events.where((e) => _isHighImpact(e)).take(5).toList();
        if (events.isEmpty) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            color: AppColors.graphite,
            border: Border.all(color: AppColors.steel),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.event_note_outlined, color: AppColors.gold, size: 16),
                  SizedBox(width: 8),
                  Text('TODAY · ECONOMIC EVENTS',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
                ],
              ),
              const SizedBox(height: 10),
              for (final e in events) _EventRow(event: e),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  bool _isHighImpact(EconEvent e) {
    final i = (e.impact ?? '').toLowerCase();
    return i == 'high' || i == 'medium' || i.isEmpty;
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final EconEvent event;
  @override
  Widget build(BuildContext context) {
    final impact = (event.impact ?? '').toLowerCase();
    final color = impact == 'high'
        ? AppColors.bearish
        : (impact == 'medium' ? AppColors.warning : AppColors.textSecondary);
    final hhmm = _hhmm(event.time);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(hhmm,
                style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
          ),
          Container(
            width: 6, height: 6, margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(event.event,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600,
                    height: 1.3)),
          ),
          if (event.forecast != null) ...[
            const SizedBox(width: 6),
            Text('est ${event.forecast}',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
          ],
        ],
      ),
    );
  }

  String _hhmm(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final t = DateTime.tryParse(iso);
    if (t == null) return iso.length >= 5 ? iso.substring(11, 16) : iso;
    final local = t.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
