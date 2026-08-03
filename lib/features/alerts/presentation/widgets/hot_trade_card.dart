import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/trade_alert_model.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/alert_actions_sheet.dart';
import '../../../../shared/widgets/card_background.dart';
import '../../../../shared/widgets/ticker_logo.dart';
import '../../../scanner/data/setup_education.dart';
import '../../../scanner/presentation/widgets/alert_action_bar.dart';
import '../../../scanner/presentation/widgets/direction_indicator.dart';
import '../../../scanner/presentation/widgets/grade_badge.dart';
import '../../../scanner/presentation/widgets/watchlist_star.dart';

/// Hot trade card. Same composition as ScannerAlertCard: full-bleed art,
/// all info right-aligned on the right half, tap to expand for education.
class HotTradeCard extends StatefulWidget {
  const HotTradeCard({
    super.key,
    required this.alert,
    this.onOpenDetail,
    this.initiallyExpanded = false,
  });

  final TradeAlert alert;
  final VoidCallback? onOpenDetail;
  final bool initiallyExpanded;

  @override
  State<HotTradeCard> createState() => _HotTradeCardState();
}

class _HotTradeCardState extends State<HotTradeCard> {
  late bool _expanded = widget.initiallyExpanded;

  // Hot Trades cards use the same bull_call_bg / bear_put_bg artwork as the
  // scanner cards for visual consistency across the alert surface. The HOT
  // eyebrow + gold glow distinguishes them from the standard scanner card.
  CardArt get _art =>
      widget.alert.isBullish ? CardArt.bullCall : CardArt.bearPut;

  @override
  Widget build(BuildContext context) {
    final TradeAlert a = widget.alert;
    return CardBackground(
      art: _art,
      accentColor: AppColors.gold,
      glow: true,
      minHeight: 252,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      onTap: () => setState(() => _expanded = !_expanded),
      onLongPress: () => AlertActionsSheet.show(context, a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: _HotEyebrow(mode: a.mode, source: a.source),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.52,
              child: _RightInfoColumn(alert: a),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _ExpandedSection(
                    alert: a,
                    onOpenDetail: widget.onOpenDetail,
                  )
                : const SizedBox.shrink(),
          ),
          // Engagement row — same as scanner card. Hot Trades cards get the
          // chart button, star, and 3-button action row so customers can
          // capture intent on the highest-conviction alerts.
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: <Widget>[
                _HotChartButton(alert: a),
                const Spacer(),
                WatchlistStar(symbol: a.symbol),
              ],
            ),
          ),
          AlertActionBar(
            alertId: a.id,
            grade: a.grade?.wire ?? 'A',
          ),
          const SizedBox(height: 8),
          _Footer(alert: a, expanded: _expanded),
        ],
      ),
    );
  }
}

class _HotEyebrow extends StatelessWidget {
  const _HotEyebrow({this.mode, this.source});

  /// Scanner mode this alert came from. When present we render a DAY / SWING /
  /// LEAPS pill next to the "HOT TRADE" label so users see at a glance what
  /// timeframe the setup applies to.
  final ScannerMode? mode;

  /// Provenance string from the TradeAlert. 'manual' = admin-curated pick;
  /// 'scanner' / 'auto_promote' = algorithmically detected. Drives the
  /// ADMIN PICK pill so customers know which alerts are hand-selected.
  final String? source;

  @override
  Widget build(BuildContext context) {
    final bool isManual = source == 'manual';
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (isManual) ...<Widget>[
          const _AdminPickPill(),
          const SizedBox(width: 6),
        ],
        if (mode != null) ...<Widget>[
          _ModePill(mode: mode!),
          const SizedBox(width: 8),
        ],
        const Icon(Icons.local_fire_department,
            color: AppColors.gold, size: 18),
        const SizedBox(width: 4),
        const _ShadowedText(
          'HOT TRADE',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Distinctive pill shown on hand-picked admin alerts. Uses the info-blue
/// hue so it doesn't compete with the gold HOT TRADE / mode pill, and so
/// scanner-generated alerts (the majority) remain visually dominant in
/// brand-gold while admin picks read as "curated" rather than "automated".
class _AdminPickPill extends StatelessWidget {
  const _AdminPickPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.55)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.verified_user, size: 10, color: AppColors.info),
          SizedBox(width: 3),
          Text(
            'ADMIN PICK',
            style: TextStyle(
              color: AppColors.info,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              shadows: <Shadow>[
                Shadow(
                  color: Color(0xAA000000),
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small gold pill rendering SWING / LEAPS so users can scan the Hot
/// Trades feed and immediately understand the timeframe of each setup. The
/// pill is intentionally small + bordered so it doesn't compete with the
/// HOT TRADE eyebrow next to it.
class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode});
  final ScannerMode mode;

  String get _label => switch (mode) {
        ScannerMode.day => 'DAY',
        ScannerMode.swing => 'SWING',
        ScannerMode.leaps => 'LEAPS',
      };

  Color get _pillColor => AppColors.gold;

  @override
  Widget build(BuildContext context) {
    final color = _pillColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          shadows: const <Shadow>[
            Shadow(
              color: Color(0xAA000000),
              offset: Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}

class _RightInfoColumn extends StatelessWidget {
  const _RightInfoColumn({required this.alert});
  final TradeAlert alert;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        // Grade + confidence (top).
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            _ShadowedText(
              '${alert.confidence}',
              style: AppTypography.mono(
                size: 14,
                weight: FontWeight.w800,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(width: 8),
            if (alert.grade != null)
              GradeBadge(grade: alert.grade!)
            else
              const SizedBox.shrink(),
          ],
        ),
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

        DirectionIndicator(direction: alert.direction, dense: true),
        const SizedBox(height: 10),

        _MetricLine(
          label: 'VOL',
          value: alert.volume != null
              ? Formatters.number(alert.volume, fractionDigits: 0)
              : '—',
        ),
        const SizedBox(height: 4),
        _MetricLine(
          label: 'PRICE',
          value: alert.currentPrice != null
              ? Formatters.price(alert.currentPrice)
              : Formatters.price(alert.entry),
        ),
        const SizedBox(height: 4),
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
  const _ExpandedSection({required this.alert, required this.onOpenDetail});
  final TradeAlert alert;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          const _SectionTitle('WHY THIS STOCK'),
          const SizedBox(height: 6),
          _ShadowedText(
            alert.reason,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (alert.kind.isNotEmpty && alert.kind != 'manual') ...<Widget>[
            const SizedBox(height: 14),
            const _SectionTitle('HOW THIS SETUP WORKS'),
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
          ],
          const SizedBox(height: 14),
          _PlanRow(alert: alert),
          if (alert.notes != null && alert.notes!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _ShadowedText(
              alert.notes!,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFE7E9EE),
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
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
  const _PlanRow({required this.alert});
  final TradeAlert alert;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PlanCell(
          label: 'ENTRY',
          value: Formatters.price(alert.entry),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return _ShadowedText(
      text,
      style: const TextStyle(
        color: AppColors.gold,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// "View Chart" button for Hot Trades cards. Opens the in-app chart
/// pre-loaded with the alert's entry/stop/target overlay lines.
class _HotChartButton extends StatelessWidget {
  const _HotChartButton({required this.alert});
  final TradeAlert alert;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        AnalyticsService.chartOpened(
          symbol: alert.symbol,
          timeframe: '1D',
        );
        final StringBuffer qs = StringBuffer();
        if (alert.entry > 0) qs.write('alertPrice=${alert.entry}');
        if (alert.stop != null) {
          if (qs.isNotEmpty) qs.write('&');
          qs.write('stopPrice=${alert.stop}');
        }
        if (alert.target != null) {
          if (qs.isNotEmpty) qs.write('&');
          qs.write('targetPrice=${alert.target}');
        }
        final String path =
            qs.isEmpty ? '/chart/${alert.symbol}' : '/chart/${alert.symbol}?$qs';
        context.push(path);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.show_chart, size: 14, color: Colors.white70),
            SizedBox(width: 6),
            Text(
              'CHART',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.alert, required this.expanded});
  final TradeAlert alert;
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

/// Local text helper with a soft drop shadow so labels stay legible on the
/// full-bleed artwork without darkening the image.
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
