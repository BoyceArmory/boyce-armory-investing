import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/admin_providers.dart';

/// Detector control panel — list every (mode, kind) the scanner can fire,
/// with a kill switch per row. Pulls the current backtest expectancy for
/// context so admins know which detectors are losing money before they
/// flip them off.
///
/// Data sources:
///   - All known (mode, kind) pairs derived from setup_stats rows + the
///     hard-coded list of detector kinds known to the backend (so newly
///     added detectors with no backtest data still show up).
///   - The current disabled list from system_config/flags.disabledDetectors
///     (read on screen open + after each toggle to stay in sync).
class DetectorsTab extends ConsumerStatefulWidget {
  const DetectorsTab({super.key});
  @override
  ConsumerState<DetectorsTab> createState() => _DetectorsTabState();
}

class _DetectorsTabState extends ConsumerState<DetectorsTab> {
  // Master list of every detector key the engine knows about. Kept in sync
  // with `scanner.types.SetupKind` and `scanner.analyzer.{DAY,SWING,LEAPS}_DETECTORS`.
  // We list (mode, kind) pairs explicitly so newly-added detectors that
  // haven't backtested yet still appear here for the admin to control.
  static const List<_DetSpec> _knownDetectors = <_DetSpec>[
    // Day mode
    _DetSpec('day', 'vwap_reclaim'),
    _DetSpec('day', 'vwap_rejection'),
    _DetSpec('day', 'orb_breakout'),
    _DetSpec('day', 'orb_breakdown'),
    _DetSpec('day', 'breakout'),
    _DetSpec('day', 'breakdown'),
    _DetSpec('day', 'bull_flag'),
    _DetSpec('day', 'bear_flag'),
    _DetSpec('day', 'high_volume_move'),
    _DetSpec('day', 'gap_continuation_long'),
    _DetSpec('day', 'gap_fade_short'),
    _DetSpec('day', 'stop_hunt_reversal_long'),
    _DetSpec('day', 'stop_hunt_reversal_short'),
    _DetSpec('day', 'hammer_at_support'),
    _DetSpec('day', 'shooting_star_at_resistance'),
    _DetSpec('day', 'nr7_compression_long'),
    _DetSpec('day', 'nr7_compression_short'),
    _DetSpec('day', 'inside_bar_at_resistance'),
    _DetSpec('day', 'inside_bar_at_support'),
    // Swing mode
    _DetSpec('swing', 'breakout'),
    _DetSpec('swing', 'breakdown'),
    _DetSpec('swing', 'bull_flag'),
    _DetSpec('swing', 'bear_flag'),
    _DetSpec('swing', 'oversold_bounce'),
    _DetSpec('swing', 'overbought_fade'),
    _DetSpec('swing', 'high_volume_move'),
    _DetSpec('swing', 'oversold_reversal_long'),
    _DetSpec('swing', 'overbought_reversal_short'),
    _DetSpec('swing', 'failed_breakdown_long'),
    _DetSpec('swing', 'failed_breakout_short'),
    _DetSpec('swing', 'bullish_engulfing_long'),
    _DetSpec('swing', 'bearish_engulfing_short'),
    _DetSpec('swing', 'stop_hunt_reversal_long'),
    _DetSpec('swing', 'stop_hunt_reversal_short'),
    _DetSpec('swing', 'hammer_at_support'),
    _DetSpec('swing', 'shooting_star_at_resistance'),
    _DetSpec('swing', 'nr7_compression_long'),
    _DetSpec('swing', 'nr7_compression_short'),
    _DetSpec('swing', 'inside_bar_at_resistance'),
    _DetSpec('swing', 'inside_bar_at_support'),
    // LEAPS mode
    _DetSpec('leaps', 'bull_flag'),
    _DetSpec('leaps', 'breakout'),
    _DetSpec('leaps', 'oversold_bounce'),
    _DetSpec('leaps', 'oversold_reversal_long'),
    _DetSpec('leaps', 'failed_breakdown_long'),
    _DetSpec('leaps', 'bullish_engulfing_long'),
  ];

  Set<String> _disabled = <String>{};
  Map<String, Map<String, dynamic>> _statsByKey = const {};
  bool _loading = false;
  String? _saving;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final flags = await repo.fetchFlags();
      final disabled =
          (flags['effective']?['disabledDetectors'] as List?) ?? const <dynamic>[];
      final stats = await repo.fetchBacktestStats();
      final statMap = <String, Map<String, dynamic>>{
        for (final r in stats)
          if (r['key'] is String) (r['key'] as String): r,
      };
      if (!mounted) return;
      setState(() {
        _disabled = disabled.map((e) => e.toString()).toSet();
        _statsByKey = statMap;
      });
    } catch (_) {
      // silent
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAutoDemote() async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.graphite,
        title: const Text('Run auto-demote sweep?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Reads setup_stats and disables every (mode,kind) detector with '
          'expectancyPct ≤ -0.1% and ≥100 sampled trades. Already-disabled '
          'detectors are left alone. Logs to Audit.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.obsidian,
            ),
            child: const Text('Run sweep'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = '__auto_demote__');
    try {
      final r =
          await ref.read(adminRepositoryProvider).runAutoDemote();
      if (!mounted) return;
      final newly = (r['newlyDisabled'] as List?) ?? const <dynamic>[];
      final flagged = r['flagged'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Sweep: $flagged flagged, ${newly.length} newly disabled.'),
          backgroundColor:
              newly.isEmpty ? AppColors.bullish : AppColors.warning,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Sweep failed: $e'),
            backgroundColor: AppColors.bearish),
      );
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _toggle(String key, bool enabled) async {
    HapticFeedback.lightImpact();
    final updated = Set<String>.from(_disabled);
    if (enabled) {
      updated.remove(key);
    } else {
      updated.add(key);
    }
    setState(() {
      _disabled = updated;
      _saving = key;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      final out = await repo.setDisabledDetectors(updated.toList());
      if (!mounted) return;
      setState(() => _disabled = out.toSet());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: AppColors.bearish),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final byMode = <String, List<_DetSpec>>{};
    for (final d in _knownDetectors) {
      (byMode[d.mode] ??= <_DetSpec>[]).add(d);
    }
    final modes = ['day', 'swing', 'leaps'];
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.graphite,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        children: <Widget>[
          // Summary strip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.graphite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.power_settings_new,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _disabled.isEmpty
                        ? 'All ${_knownDetectors.length} detectors enabled'
                        : '${_disabled.length} of ${_knownDetectors.length} detectors disabled',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold),
                  )
                else
                  TextButton.icon(
                    onPressed: _saving == '__auto_demote__'
                        ? null
                        : _runAutoDemote,
                    icon: const Icon(Icons.auto_fix_high,
                        size: 14, color: AppColors.warning),
                    label: Text(
                      _saving == '__auto_demote__'
                          ? 'Running…'
                          : 'Auto-demote',
                      style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w800),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final mode in modes) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
              child: Text(
                '${mode.toUpperCase()} (${(byMode[mode] ?? []).length})',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ),
            for (final spec in (byMode[mode] ?? const <_DetSpec>[]))
              _Row(
                spec: spec,
                disabled: _disabled.contains(spec.key),
                saving: _saving == spec.key,
                stats: _statsByKey[spec.key],
                onChanged: (v) => _toggle(spec.key, v),
              ),
          ],
        ],
      ),
    );
  }
}

class _DetSpec {
  const _DetSpec(this.mode, this.kind);
  final String mode;
  final String kind;
  String get key => '${mode}_$kind';
}

class _Row extends StatelessWidget {
  const _Row({
    required this.spec,
    required this.disabled,
    required this.saving,
    required this.stats,
    required this.onChanged,
  });
  final _DetSpec spec;
  final bool disabled;
  final bool saving;
  final Map<String, dynamic>? stats;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final expectancy = (stats?['expectancyPct'] as num?)?.toDouble();
    final n = (stats?['totalTrades'] as num?)?.toInt() ?? 0;
    Color edgeColor;
    String edgeLabel;
    if (expectancy == null || n < 30) {
      edgeColor = AppColors.textTertiary;
      edgeLabel = n > 0 ? 'n=$n (small)' : 'no data';
    } else if (expectancy >= 0.15) {
      edgeColor = AppColors.bullish;
      edgeLabel = '+${expectancy.toStringAsFixed(2)}%/trade';
    } else if (expectancy >= 0) {
      edgeColor = AppColors.gold;
      edgeLabel = '+${expectancy.toStringAsFixed(2)}%/trade';
    } else {
      edgeColor = AppColors.bearish;
      edgeLabel = '${expectancy.toStringAsFixed(2)}%/trade';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.graphite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                disabled ? AppColors.bearish.withValues(alpha: 0.5) : AppColors.steel,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    spec.kind.replaceAll('_', ' '),
                    style: TextStyle(
                      color: disabled
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      decoration: disabled
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    edgeLabel,
                    style: TextStyle(
                      color: edgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (saving)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.gold),
              )
            else
              Switch(
                value: !disabled,
                onChanged: onChanged,
                activeColor: AppColors.gold,
                inactiveThumbColor: AppColors.bearish,
              ),
          ],
        ),
      ),
    );
  }
}
