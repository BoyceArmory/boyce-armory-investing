import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Risk calculator bottom sheet. Open from any alert detail or Hot Trade card
/// long-press. Inputs: account size, % risk per trade, entry, stop.
/// Outputs: position size in shares, $ at risk, $ reward at T1/T2/T3
/// assuming R-multiple targets (T1=1R, T2=2R, T3=3R).
///
/// All math runs client-side. No backend, no persisted state — the user can
/// fire it from any alert and tune values without affecting anything else.
///
/// Usage:
///   showModalBottomSheet(
///     context: context,
///     builder: (_) => RiskCalculatorSheet(
///       entry: alert.entry,
///       stop: alert.stop,
///       symbol: alert.symbol,
///     ),
///   );
class RiskCalculatorSheet extends StatefulWidget {
  const RiskCalculatorSheet({
    super.key,
    required this.symbol,
    required this.entry,
    this.stop,
  });

  final String symbol;
  final double entry;
  final double? stop;

  @override
  State<RiskCalculatorSheet> createState() => _RiskCalculatorSheetState();
}

class _RiskCalculatorSheetState extends State<RiskCalculatorSheet> {
  // Sensible defaults — most retail traders run $10k accounts at 1-2% per trade.
  final _accountCtrl = TextEditingController(text: '10000');
  final _riskPctCtrl = TextEditingController(text: '1.0');
  late final TextEditingController _entryCtrl =
      TextEditingController(text: widget.entry.toStringAsFixed(2));
  late final TextEditingController _stopCtrl = TextEditingController(
      text: widget.stop?.toStringAsFixed(2) ?? '');

  double get _accountSize => double.tryParse(_accountCtrl.text) ?? 0;
  double get _riskPct => double.tryParse(_riskPctCtrl.text) ?? 0;
  double get _entry => double.tryParse(_entryCtrl.text) ?? 0;
  double get _stop => double.tryParse(_stopCtrl.text) ?? 0;

  /// Dollar amount willing to risk on this trade.
  double get _dollarRisk => _accountSize * (_riskPct / 100);

  /// Distance from entry to stop. The "R" in R-multiple math.
  double get _riskPerShare => (_entry - _stop).abs();

  /// Position size in shares (or contracts × 100 if it's an option).
  int get _shares =>
      _riskPerShare > 0 ? (_dollarRisk / _riskPerShare).floor() : 0;

  /// Reward at T1 (1R), T2 (2R), T3 (3R).
  double get _t1Reward => _riskPerShare * _shares;
  double get _t2Reward => _riskPerShare * _shares * 2;
  double get _t3Reward => _riskPerShare * _shares * 3;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _riskPctCtrl.dispose();
    _entryCtrl.dispose();
    _stopCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.graphite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: AppColors.gold, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const Icon(Icons.calculate_outlined,
                    color: AppColors.gold, size: 22),
                const SizedBox(width: 8),
                Text(
                  'RISK CALCULATOR · ${widget.symbol}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Input(
                    label: 'Account size (\$)',
                    controller: _accountCtrl,
                    onChange: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Input(
                    label: 'Risk per trade (%)',
                    controller: _riskPctCtrl,
                    onChange: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Input(
                    label: 'Entry',
                    controller: _entryCtrl,
                    onChange: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Input(
                    label: 'Stop',
                    controller: _stopCtrl,
                    onChange: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ResultsCard(
              dollarRisk: _dollarRisk,
              shares: _shares,
              riskPerShare: _riskPerShare,
              t1: _t1Reward,
              t2: _t2Reward,
              t3: _t3Reward,
            ),
            const SizedBox(height: 14),
            const Text(
              'R = entry − stop. Position size = (\$ risk) ÷ R, rounded down to whole shares. '
              "Targets assume scaled exits at 1R/2R/3R, which matches the Boyce Armory scanner's default target ladder.",
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.label,
    required this.controller,
    required this.onChange,
  });
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChange,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.obsidian,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.steel),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.dollarRisk,
    required this.shares,
    required this.riskPerShare,
    required this.t1,
    required this.t2,
    required this.t3,
  });
  final double dollarRisk;
  final int shares;
  final double riskPerShare;
  final double t1;
  final double t2;
  final double t3;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.obsidian,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  label: 'POSITION SIZE',
                  value: shares > 0 ? '$shares shares' : '—',
                  color: AppColors.gold,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'AT RISK',
                  value: shares > 0
                      ? '-${Formatters.price(shares * riskPerShare)}'
                      : '—',
                  color: AppColors.bearish,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.steel, height: 1),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  label: 'T1 (+1R)',
                  value: shares > 0 ? '+${Formatters.price(t1)}' : '—',
                  color: AppColors.bullish,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'T2 (+2R)',
                  value: shares > 0 ? '+${Formatters.price(t2)}' : '—',
                  color: AppColors.bullish,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'T3 (+3R)',
                  value: shares > 0 ? '+${Formatters.price(t3)}' : '—',
                  color: AppColors.bullish,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
