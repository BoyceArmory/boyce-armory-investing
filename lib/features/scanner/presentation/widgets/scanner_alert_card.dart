import 'package:flutter/material.dart';

import '../../../../core/extensions/datetime_extensions.dart';
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

  CardArt get _art {
    if (widget.alert.promoted) {
      return widget.alert.isBullish
          ? CardArt.smartMoneyBull
          : CardArt.smartMoneyBear;
    }
    return widget.alert.isBullish ? CardArt.bullCall : CardArt.bearPut;
  }

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
