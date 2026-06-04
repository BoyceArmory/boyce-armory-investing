import 'package:flutter/material.dart';

import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/models/option_contract_model.dart';
import '../../../../core/models/scanner_alert_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/card_background.dart';
import '../../../../shared/widgets/ticker_logo.dart';
import '../../data/setup_education.dart';
import 'direction_indicator.dart';
import 'grade_badge.dart';

/// Premium scanner alert card.
///
/// Layout rule: the background art is full-bleed and fills the entire card.
/// ALL information is right-aligned on the right half of the card. Nothing
/// is rendered on the left side so the artwork stays visually dominant.
///
/// Collapsed state (always visible):
///   - Grade + score (top right)
///   - Stock ticker + logo
///   - Direction (CALL / PUT)
///   - Volume
///   - Current price
///   - Day % move
///
/// Tap to expand reveals the educational explanation of the setup, the
/// scanner reasoning, the trade plan, and the suggested contract.
class ScannerAlertCard extends StatefulWidget {
  const ScannerAlertCard({
    super.key,
    required this.alert,
    this.onOpenDetail,
    this.initiallyExpanded = false,
  });

  final ScannerAlert alert;
  final VoidCallback? onOpenDetail;
  final bool initiallyExpanded;

  @override
  State<ScannerAlertCard> createState() => _ScannerAlertCardState();
}

class _ScannerAlertCardState extends State<ScannerAlertCard> {
  late bool _expanded = widget.initiallyExpanded;

  // All scanner cards (promoted or not) use bull_call_bg / bear_put_bg for
  // consistent branding. Promoted cards still get the gold accent + glow via
  // the accentColor + glow flags on CardBackground below.
  CardArt get _art =>
      widget.alert.isBullish ? CardArt.bullCall : CardArt.bearPut;

  Color get _accent {
    if (widget.alert.promoted) return AppColors.gold;
    return widget.alert.isBullish ? AppColors.bullish : AppColors.bearish;
  }

  @override
  Widget build(BuildContext context) {
    final ScannerAlert a = widget.alert;
    return CardBackground(
      art: _art,
      accentColor: _accent,
      glow: a.promoted,
      minHeight: 240,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Right-aligned column over the full-bleed art.
          Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.52,
              child: _RightInfoColumn(alert: a, accent: _accent),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _ExpandedSection(
                    alert: a,
                    accent: _accent,
                    onOpenDetail: widget.onOpenDetail,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          _Footer(alert: a, expanded: _expanded),
        ],
      ),
    );
  }
}

class _RightInfoColumn extends StatelessWidget {
  const _RightInfoColumn({required this.alert, required this.accent});
  final ScannerAlert alert;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        // Grade + score (top).
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            _ShadowedText(
              '${alert.score}',
              style: AppTypography.mono(
                size: 14,
                weight: FontWeight.w800,
                color: accent,
              ),
            ),
            const SizedBox(width: 8),
            GradeBadge(grade: alert.grade),
          ],
        ),
        // Optional: historical win-rate chip when we have enough sample.
        if (alert.histWinRate != null &&
            (alert.histSampleSize ?? 0) >= 5) ...<Widget>[
          const SizedBox(height: 6),
          _WinRateChip(
            winRate: alert.histWinRate!,
            sampleSize: alert.histSampleSize!,
          ),
        ],
        const SizedBox(height: 10),

        // Ticker + logo.
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            _ShadowedText(
              alert.symbol,
              style: AppTypography.mono(
                size: 26,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            TickerLogo(symbol: alert.symbol, size: 34, borderRadius: 10),
          ],
        ),
        const SizedBox(height: 8),

        // Direction pill.
        DirectionIndicator(direction: alert.direction, dense: true),
        const SizedBox(height: 10),

        // Volume.
        _MetricLine(
          label: 'VOL',
          value: alert.volume != null
              ? Formatters.number(alert.volume, fractionDigits: 0)
              : '—',
        ),
        const SizedBox(height: 4),

        // Current price.
        _MetricLine(
          label: 'PRICE',
          value: alert.currentPrice != null
              ? Formatters.price(alert.currentPrice)
              : (alert.entry != null ? Formatters.price(alert.entry) : '—'),
        ),
        const SizedBox(height: 4),

        // Day % move.
        _MetricLine(
          label: '%',
          value: alert.dayChangePct != null
              ? Formatters.signedPercent(alert.dayChangePct,
                  alreadyPercent: true)
              : '—',
          valueColor: alert.dayChangePct == null
              ? Colors.white
              : (alert.dayChangePct! >= 0
                  ? AppColors.bullish
                  : AppColors.bearish),
        ),
      ],
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        _ShadowedText(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 8),
        _ShadowedText(
          value,
          style: AppTypography.mono(
            size: 15,
            weight: FontWeight.w700,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ExpandedSection extends StatelessWidget {
  const _ExpandedSection({
    required this.alert,
    required this.accent,
    required this.onOpenDetail,
  });
  final ScannerAlert alert;
  final Color accent;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _SectionTitle('WHY THIS STOCK', color: accent),
          const SizedBox(height: 6),
          _ShadowedText(
            // Prefer the server-generated per-alert narrative when present,
            // fall back to the detector's terse reason for legacy alerts.
            (alert.whyThisStock?.isNotEmpty ?? false)
                ? alert.whyThisStock!
                : alert.reason,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (alert.triggerSnapshot != null &&
              alert.triggerSnapshot!.hasAnyData) ...<Widget>[
            const SizedBox(height: 14),
            _SectionTitle('WHY THIS FIRED', color: accent),
            const SizedBox(height: 6),
            _WhyThisFiredPanel(alert: alert, accent: accent),
          ],
          const SizedBox(height: 14),
          _SectionTitle('HOW THIS SETUP WORKS', color: accent),
          const SizedBox(height: 6),
          _ShadowedText(
            SetupEducation.forKind(alert.kind),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFFE7E9EE),
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _PlanRow(alert: alert, accent: accent),
          if (alert.suggestedContract != null) ...<Widget>[
            const SizedBox(height: 12),
            _ContractLine(alert: alert),
            if (_hasOptionsWarnings(alert)) ...<Widget>[
              const SizedBox(height: 8),
              _OptionsWarningsRow(alert: alert),
            ],
            if (alert.flow != null && alert.flow!.hasAnyData) ...<Widget>[
              const SizedBox(height: 8),
              _OptionsFlowPanel(flow: alert.flow!),
            ],
            if (alert.chainAnalytics != null &&
                alert.chainAnalytics!.hasAnyData) ...<Widget>[
              const SizedBox(height: 8),
              _ChainAnalyticsPanel(
                  analytics: alert.chainAnalytics!,
                  accent: accent,
                  currentPrice: alert.currentPrice),
            ],
          ],
          if (onOpenDetail != null) ...<Widget>[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenDetail,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Full breakdown'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.alert, required this.accent});
  final ScannerAlert alert;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PlanCell(
          label: 'ENTRY',
          value: alert.entry != null ? Formatters.price(alert.entry) : '—',
          color: Colors.white,
        ),
        const SizedBox(width: 14),
        _PlanCell(
          label: 'TARGET',
          value: alert.target != null ? Formatters.price(alert.target) : '—',
          color: AppColors.bullish,
        ),
        const SizedBox(width: 14),
        _PlanCell(
          label: 'STOP',
          value: alert.stop != null ? Formatters.price(alert.stop) : '—',
          color: AppColors.bearish,
        ),
        if (alert.riskRewardRatio != null) ...<Widget>[
          const SizedBox(width: 14),
          _PlanCell(
            label: 'R / R',
            value: alert.riskRewardRatio!.toStringAsFixed(2),
            color: accent,
          ),
        ],
      ],
    );
  }
}

class _PlanCell extends StatelessWidget {
  const _PlanCell({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        _ShadowedText(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        _ShadowedText(
          value,
          style: AppTypography.mono(
            size: 13,
            weight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ContractLine extends StatelessWidget {
  const _ContractLine({required this.alert});
  final ScannerAlert alert;

  @override
  Widget build(BuildContext context) {
    final c = alert.suggestedContract!;
    // When live Polygon Options data is present (delta + iv + mid), render
    // the rich greeks / bid-ask / spread view. Otherwise fall back to the
    // simple "CALL $315 · 2026-06-15" headline.
    if (c.hasLiveData) {
      return _LiveContractBlock(contract: c);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        const Icon(Icons.local_offer_outlined,
            color: AppColors.gold, size: 14),
        const SizedBox(width: 6),
        _ShadowedText(
          '${c.type.toUpperCase()} ${Formatters.priceCompact(c.strike)} · ${c.expiration}',
          style: AppTypography.mono(
            size: 12,
            weight: FontWeight.w700,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }
}

/// Rich contract display — used when Polygon Options Advanced returns real
/// greeks/IV/spread. Shows mid price, spread health, delta, IV, OI, vol.
/// Right-aligned to match the rest of the card.
class _LiveContractBlock extends StatelessWidget {
  const _LiveContractBlock({required this.contract});
  final OptionContract contract;

  @override
  Widget build(BuildContext context) {
    final c = contract;
    final spreadHealthy = c.isTradeable;
    final spreadColor = spreadHealthy
        ? AppColors.bullish
        : AppColors.bearish;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              const Icon(Icons.local_offer_outlined,
                  color: AppColors.gold, size: 14),
              const SizedBox(width: 6),
              Text(
                '${c.type.toUpperCase()} ${Formatters.priceCompact(c.strike)} · ${c.expiration}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 2,
            children: <Widget>[
              if (c.mid != null)
                _ContractStat(label: 'MID', value: '\$${c.mid!.toStringAsFixed(2)}'),
              if (c.bid != null && c.ask != null)
                _ContractStat(
                  label: 'B/A',
                  value: '${c.bid!.toStringAsFixed(2)} × ${c.ask!.toStringAsFixed(2)}',
                ),
              if (c.spreadPct != null)
                _ContractStat(
                  label: 'SPREAD',
                  value: '${c.spreadPct!.toStringAsFixed(1)}%',
                  color: spreadColor,
                ),
              if (c.delta != null)
                _ContractStat(label: 'Δ', value: c.delta!.toStringAsFixed(2)),
              if (c.iv != null)
                _ContractStat(label: 'IV', value: '${(c.iv! * 100).toStringAsFixed(0)}%'),
              if (c.dte != null)
                _ContractStat(label: 'DTE', value: '${c.dte}d'),
              if (c.openInterest != null)
                _ContractStat(label: 'OI', value: _compactNum(c.openInterest!)),
              if (c.volume != null)
                _ContractStat(label: 'VOL', value: _compactNum(c.volume!)),
            ],
          ),
          if (!spreadHealthy) ...<Widget>[
            const SizedBox(height: 4),
            const Text(
              'Wide spread — consider a different strike.',
              style: TextStyle(
                color: AppColors.bearish,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContractStat extends StatelessWidget {
  const _ContractStat({
    required this.label,
    required this.value,
    this.color,
  });
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final v = color ?? AppColors.gold;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB6BBC4),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: v,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

String _compactNum(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toString();
}

bool _hasOptionsWarnings(ScannerAlert alert) {
  final c = alert.suggestedContract;
  if (c == null) return false;
  return c.isZeroDte == true ||
      c.earningsBeforeExpiry == true ||
      (c.ivRank != null && (c.ivRank! >= 80 || c.ivRank! <= 20));
}

/// Inline row of contextual warning chips: 0DTE risk, earnings IV crush
/// risk, expensive premium (IV rank ≥80), or cheap premium (≤20).
class _OptionsWarningsRow extends StatelessWidget {
  const _OptionsWarningsRow({required this.alert});
  final ScannerAlert alert;

  @override
  Widget build(BuildContext context) {
    final c = alert.suggestedContract!;
    final chips = <Widget>[];
    if (c.isZeroDte == true) {
      chips.add(const _WarnChip(
        label: '0DTE',
        tone: AppColors.bearish,
        tooltip: 'Expires today — extreme gamma/theta risk.',
      ));
    }
    if (c.earningsBeforeExpiry == true) {
      chips.add(const _WarnChip(
        label: 'IV CRUSH',
        tone: AppColors.bearish,
        tooltip: 'Earnings before expiry — premium will crush post-print.',
      ));
    }
    if (c.ivRank != null) {
      if (c.ivRank! >= 80) {
        chips.add(_WarnChip(
          label: 'IV RANK ${c.ivRank!.toStringAsFixed(0)}',
          tone: AppColors.warning,
          tooltip: 'Premium is in the top quintile of past year — expensive.',
        ));
      } else if (c.ivRank! <= 20) {
        chips.add(_WarnChip(
          label: 'IV RANK ${c.ivRank!.toStringAsFixed(0)}',
          tone: AppColors.bullish,
          tooltip: 'Premium is in the bottom quintile — cheap.',
        ));
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }
}

class _WarnChip extends StatelessWidget {
  const _WarnChip({required this.label, required this.tone, this.tooltip});
  final String label;
  final Color tone;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tone.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// Aggressive-flow direction summary on the suggested contract.
/// Shows buy/sell split, sweep count, biggest print.
class _OptionsFlowPanel extends StatelessWidget {
  const _OptionsFlowPanel({required this.flow});
  final OptionsFlow flow;

  @override
  Widget build(BuildContext context) {
    final tone = flow.isBullish
        ? AppColors.bullish
        : flow.isBearish
            ? AppColors.bearish
            : AppColors.textSecondary;
    final dirLabel = flow.isBullish
        ? 'BULLISH'
        : flow.isBearish
            ? 'BEARISH'
            : 'NEUTRAL';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              const Text(
                'FLOW',
                style: TextStyle(
                  color: Color(0xFFB6BBC4),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                dirLabel,
                style: TextStyle(
                  color: tone,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((flow.sweepCount ?? 0) > 0) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${flow.sweepCount} SWEEP${flow.sweepCount == 1 ? "" : "S"}',
                    style: TextStyle(
                      color: tone,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: <Widget>[
              if (flow.buyVolume != null)
                _ContractStat(
                    label: 'BUYS', value: _compactNum(flow.buyVolume!)),
              if (flow.sellVolume != null)
                _ContractStat(
                    label: 'SELLS', value: _compactNum(flow.sellVolume!)),
              if (flow.largestPrint != null)
                _ContractStat(
                    label: 'BIG', value: _compactNum(flow.largestPrint!)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chain-wide market context: max pain, put/call ratio, net GEX.
class _ChainAnalyticsPanel extends StatelessWidget {
  const _ChainAnalyticsPanel({
    required this.analytics,
    required this.accent,
    this.currentPrice,
  });
  final ChainAnalytics analytics;
  final Color accent;
  final double? currentPrice;

  String _gexLabel(double dollars) {
    final absM = dollars.abs() / 1000000;
    final sign = dollars >= 0 ? '+' : '-';
    return '$sign\$${absM.toStringAsFixed(0)}M';
  }

  String _regimeLabel(double? gex) {
    if (gex == null) return '';
    if (gex > 50000000) return 'mean revert';
    if (gex < -50000000) return 'amplify';
    return 'neutral';
  }

  String _pcInterp(double? ratio) {
    if (ratio == null) return '';
    if (ratio < 0.7) return 'call-heavy';
    if (ratio > 1.3) return 'put-heavy';
    return 'balanced';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.textTertiary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'CHAIN CONTEXT',
            style: TextStyle(
              color: Color(0xFFB6BBC4),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              if (analytics.maxPainStrike != null)
                _ContractStat(
                  label: 'MAX PAIN',
                  value: '\$${analytics.maxPainStrike!.toStringAsFixed(0)}',
                ),
              if (analytics.putCallVolumeRatio != null)
                _ContractStat(
                  label: 'P/C VOL',
                  value: analytics.putCallVolumeRatio!.toStringAsFixed(2),
                  color: analytics.putCallVolumeRatio! > 1.3
                      ? AppColors.bearish
                      : analytics.putCallVolumeRatio! < 0.7
                          ? AppColors.bullish
                          : null,
                ),
              if (analytics.netGexDollars != null)
                _ContractStat(
                  label: 'GEX',
                  value: _gexLabel(analytics.netGexDollars!),
                  color: analytics.netGexDollars! > 0
                      ? AppColors.bullish
                      : AppColors.bearish,
                ),
            ],
          ),
          if (analytics.netGexDollars != null ||
              analytics.putCallVolumeRatio != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _composeReadout(analytics),
              style: const TextStyle(
                color: Color(0xFFB6BBC4),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _composeReadout(ChainAnalytics a) {
    final parts = <String>[];
    if (a.netGexDollars != null) {
      parts.add('${_regimeLabel(a.netGexDollars)} regime');
    }
    if (a.putCallVolumeRatio != null) {
      parts.add(_pcInterp(a.putCallVolumeRatio));
    }
    return parts.join(' · ');
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _ShadowedText(
      text,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.alert, required this.expanded});
  final ScannerAlert alert;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        _ShadowedText(
          alert.createdAt.ago,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        AnimatedRotation(
          turns: expanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 220),
          child: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textTertiary,
            size: 18,
          ),
        ),
      ],
    );
  }
}

/// Text that lifts off the underlying artwork with a soft shadow.
/// The shadow is intentionally tiny - just enough to ensure legibility on any
/// background image without darkening the artwork.
class _ShadowedText extends StatelessWidget {
  const _ShadowedText(this.text, {required this.style, this.textAlign});
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: style.copyWith(
        shadows: const <Shadow>[
          Shadow(
            color: Color(0xAA000000),
            offset: Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

/// Historical win-rate badge. Surfaces the rolling closed-trades win rate
/// the backend attaches per (mode, kind) — gives the buyer immediate
/// "this setup actually works" credibility.
class _WinRateChip extends StatelessWidget {
  const _WinRateChip({required this.winRate, required this.sampleSize});
  final double winRate;
  final int sampleSize;

  Color get _color {
    if (winRate >= 60) return AppColors.bullish;
    if (winRate >= 50) return AppColors.warning;
    return AppColors.bearish;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        border: Border.all(color: _color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.trending_up, size: 11, color: _color),
          const SizedBox(width: 4),
          Text(
            '${winRate.toStringAsFixed(0)}% · ${sampleSize}',
            style: TextStyle(
              color: _color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Why this fired" panel — renders the frozen triggerSnapshot as a tight
// right-aligned grid of facts. Each fact is one short phrase so the panel
// stays scannable on a 14pt screen. Anything `null` is silently skipped.
// ---------------------------------------------------------------------------

class _WhyThisFiredPanel extends StatelessWidget {
  const _WhyThisFiredPanel({required this.alert, required this.accent});
  final ScannerAlert alert;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = alert.triggerSnapshot!;
    final facts = <_Fact>[];

    // ---- Momentum ----
    if (t.rsi14 != null) {
      facts.add(_Fact(
        'RSI(14)',
        t.rsi14!.toStringAsFixed(1),
        _rsiTone(t.rsi14!),
      ));
    }
    if (t.adx14 != null) {
      final adx = t.adx14!;
      String label;
      Color tone;
      if (adx >= 40) {
        label = 'very strong';
        tone = AppColors.bullish;
      } else if (adx >= 25) {
        label = 'trending';
        tone = AppColors.bullish;
      } else if (adx >= 20) {
        label = 'soft';
        tone = AppColors.textSecondary;
      } else {
        label = 'choppy';
        tone = AppColors.warning;
      }
      facts.add(_Fact(
          'ADX(14)', '${adx.toStringAsFixed(0)} · $label', tone));
    }

    // ---- VWAP / EMAs (Day mode is most relevant) ----
    if (t.vwapDistPct != null && t.vwap != null) {
      final d = t.vwapDistPct!;
      final sign = d >= 0 ? '+' : '';
      final tone = d >= 0 ? AppColors.bullish : AppColors.bearish;
      facts.add(_Fact(
          'vs VWAP', '$sign${d.toStringAsFixed(2)}%', tone));
    }
    if (t.ema9 != null && alert.currentPrice != null) {
      final above = alert.currentPrice! > t.ema9!;
      facts.add(_Fact('vs EMA9', above ? 'above' : 'below',
          above ? AppColors.bullish : AppColors.bearish));
    }
    if (t.ema20 != null && alert.currentPrice != null) {
      final above = alert.currentPrice! > t.ema20!;
      facts.add(_Fact('vs EMA20', above ? 'above' : 'below',
          above ? AppColors.bullish : AppColors.bearish));
    }
    if (t.ema50 != null && alert.currentPrice != null) {
      final above = alert.currentPrice! > t.ema50!;
      facts.add(_Fact('vs EMA50', above ? 'above' : 'below',
          above ? AppColors.bullish : AppColors.bearish));
    }

    // ---- Volume ----
    if (alert.relVolume != null) {
      final rv = alert.relVolume!;
      final tone = rv >= 1.5
          ? AppColors.bullish
          : rv >= 1.0
              ? AppColors.textSecondary
              : AppColors.bearish;
      facts.add(_Fact('Rel vol', '${rv.toStringAsFixed(2)}×', tone));
    }

    // ---- ATR (volatility context for the stop) ----
    if (t.atr14 != null && alert.entry != null) {
      final atrPct = (t.atr14! / alert.entry!) * 100;
      facts.add(_Fact(
          'ATR', '${atrPct.toStringAsFixed(2)}%', AppColors.textSecondary));
    }

    // ---- Compression flags ----
    if (t.nr7 == true) {
      facts.add(_Fact('NR7', 'narrowest 7', AppColors.bullish));
    }
    if (t.insideBar == true) {
      facts.add(_Fact('Inside bar', 'yes', AppColors.bullish));
    }

    // ---- Key levels ----
    if (t.swingHigh50 != null && alert.currentPrice != null) {
      final pct =
          ((t.swingHigh50! - alert.currentPrice!) / alert.currentPrice!) *
              100;
      final tone = pct.abs() < 1.0 ? AppColors.bullish : AppColors.textSecondary;
      facts.add(_Fact(
          '50d high', '${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(1)}% away',
          tone));
    }
    if (t.swingLow50 != null && alert.currentPrice != null) {
      final pct =
          ((alert.currentPrice! - t.swingLow50!) / t.swingLow50!) * 100;
      facts.add(_Fact('50d low',
          '${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(1)}% above',
          AppColors.textSecondary));
    }

    // ---- Market context ----
    if (t.sectorPerfPct != null) {
      final s = t.sectorPerfPct!;
      facts.add(_Fact(
        'Sector',
        '${s >= 0 ? "+" : ""}${s.toStringAsFixed(2)}%',
        s >= 0 ? AppColors.bullish : AppColors.bearish,
      ));
    }
    if (t.regime != null) {
      final r = t.regime!;
      final tone = r == 'bull'
          ? AppColors.bullish
          : r == 'bear'
              ? AppColors.bearish
              : AppColors.warning;
      facts.add(_Fact('Regime', r.toUpperCase(), tone));
    }
    if (t.weeklyTrend != null) {
      final w = t.weeklyTrend!;
      final tone = w == 'up'
          ? AppColors.bullish
          : w == 'down'
              ? AppColors.bearish
              : AppColors.textSecondary;
      facts.add(_Fact('Weekly', w.toUpperCase(), tone));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        // The fact grid itself, right-aligned to match the card.
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          runSpacing: 6,
          children: facts
              .map((f) => _FactChip(fact: f))
              .toList(growable: false),
        ),
        // Earnings warning — only show when earnings is within 7 days.
        // Critical risk flag: a swing breakout on a stock with earnings
        // tomorrow is a totally different trade than the same setup 6
        // weeks out. Yellow border so it stands out without screaming.
        if (alert.earningsInDays != null &&
            alert.earningsInDays! >= 0 &&
            alert.earningsInDays! <= 7) ...<Widget>[
          const SizedBox(height: 10),
          _EarningsWarningBar(
            daysAway: alert.earningsInDays!,
            isoDate: alert.earningsDate,
          ),
        ],
        // Backtest edge footer — measured per-detector expectancy. Only
        // shown when we have data and a meaningful sample size.
        if (alert.backtestExpectancyPct != null &&
            alert.histSampleSize != null &&
            alert.histSampleSize! >= 30) ...<Widget>[
          const SizedBox(height: 10),
          _BacktestEdgeBar(
            expectancyPct: alert.backtestExpectancyPct!,
            avgWinPct: alert.backtestAvgWinPct,
            avgLossPct: alert.backtestAvgLossPct,
            sampleSize: alert.histSampleSize!,
            accent: accent,
          ),
        ],
      ],
    );
  }

  Color _rsiTone(double rsi) {
    if (rsi >= 70) return AppColors.bearish;     // overbought
    if (rsi >= 55) return AppColors.bullish;     // bullish bias
    if (rsi >= 45) return AppColors.textSecondary;
    if (rsi >= 30) return AppColors.warning;     // weakening
    return AppColors.bearish;                    // oversold
  }
}

class _Fact {
  const _Fact(this.label, this.value, this.tone);
  final String label;
  final String value;
  final Color tone;
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.fact});
  final _Fact fact;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fact.tone.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            fact.label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFB6BBC4),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            fact.value,
            style: TextStyle(
              color: fact.tone,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BacktestEdgeBar extends StatelessWidget {
  const _BacktestEdgeBar({
    required this.expectancyPct,
    required this.avgWinPct,
    required this.avgLossPct,
    required this.sampleSize,
    required this.accent,
  });
  final double expectancyPct;
  final double? avgWinPct;
  final double? avgLossPct;
  final int sampleSize;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final positive = expectancyPct > 0;
    final tone = positive
        ? AppColors.bullish
        : (expectancyPct == 0
            ? AppColors.textSecondary
            : AppColors.bearish);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'MEASURED EDGE',
            style: TextStyle(
              color: tone,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${positive ? "+" : ""}${expectancyPct.toStringAsFixed(2)}% per trade',
            style: TextStyle(
              color: tone,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (avgWinPct != null && avgLossPct != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              'avg win +${avgWinPct!.toStringAsFixed(2)}% · '
              'avg loss -${avgLossPct!.toStringAsFixed(2)}%',
              style: const TextStyle(
                color: Color(0xFFB6BBC4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            'n = $sampleSize backtested trades',
            style: const TextStyle(
              color: Color(0xFF7C8290),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yellow earnings-warning card. Shows when the next earnings is within
/// 7 days. Render only — visibility decision lives in the parent panel.
class _EarningsWarningBar extends StatelessWidget {
  const _EarningsWarningBar({required this.daysAway, this.isoDate});
  final int daysAway;
  final String? isoDate;

  String _dateLabel() {
    if (isoDate == null || isoDate!.length < 8) return '';
    try {
      final dt = DateTime.parse(isoDate!);
      const months = <String>[
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return ' · ${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysLabel = daysAway == 0
        ? 'TODAY'
        : daysAway == 1
            ? 'TOMORROW'
            : 'in $daysAway days';
    const warn = Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warn.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: warn, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'EARNINGS RISK',
                  style: TextStyle(
                    color: warn,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reports $daysLabel${_dateLabel()} — gap risk overnight.',
                  style: const TextStyle(
                    color: Color(0xFFE7E9EE),
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
