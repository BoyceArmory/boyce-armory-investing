import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../providers/admin_providers.dart';

/// Reverse-chronological audit log feed (admin_logs collection). Every admin
/// write action across the system gets a row here.
class AuditTab extends ConsumerWidget {
  const AuditTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditLogsProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.graphite,
      onRefresh: () async {
        ref.invalidate(auditLogsProvider);
        await ref.read(auditLogsProvider.future);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => ErrorState(
          message: 'Could not load audit log',
          details: e.toString(),
          onRetry: () => ref.invalidate(auditLogsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                Center(child: Text('No admin actions logged yet.',
                    style: TextStyle(color: AppColors.textTertiary))),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _AuditRow(entry: list[i]),
          );
        },
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});
  final Map<String, dynamic> entry;
  @override
  Widget build(BuildContext context) {
    final action = (entry['action'] ?? 'unknown').toString();
    final actor = (entry['actor'] ?? 'system').toString();
    final target = entry['target'];
    final at = entry['at']?.toString();
    DateTime? t;
    if (at != null) t = DateTime.tryParse(at);
    final ago = t == null ? '—' : _agoShort(t);
    final color = _actionColor(action);

    // Pull the "extra" fields (everything that isn't a standard column).
    final extras = <String, dynamic>{...entry}
      ..remove('id')
      ..remove('action')
      ..remove('actor')
      ..remove('target')
      ..remove('at');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border.all(color: AppColors.steel),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(action,
                    style: TextStyle(
                        color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  target == null ? '' : 'target: $target',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Text(ago, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text('by $actor',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              extras.entries.map((e) => '${e.key}=${e.value}').join('  ·  '),
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    if (action.startsWith('set_disabled') || action.contains('hide')) return AppColors.bearish;
    if (action.startsWith('set_role') || action.startsWith('set_tier')) return AppColors.gold;
    if (action.contains('promote') || action.contains('create')) return AppColors.bullish;
    if (action.startsWith('trigger_') || action.startsWith('run_')) return AppColors.info;
    if (action.startsWith('set_flags')) return AppColors.warning;
    return AppColors.textSecondary;
  }
}

String _agoShort(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}
