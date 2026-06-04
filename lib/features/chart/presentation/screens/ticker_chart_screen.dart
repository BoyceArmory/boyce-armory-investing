import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_providers.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';

/// In-app chart for any ticker. Users tap a "view chart" icon on alert
/// cards and land here without leaving the app to ThinkOrSwim / TradingView.
///
/// Timeframe selector: 1D (5-min intraday) / 1M / 3M / 1Y (daily).
/// Renders a line chart of closes — simple but readable. Future passes can
/// add candlesticks (no native fl_chart support) or volume bars.
class TickerChartScreen extends ConsumerStatefulWidget {
  const TickerChartScreen({
    super.key,
    required this.symbol,
    this.alertPrice,
    this.stopPrice,
    this.targetPrice,
  });

  final String symbol;
  final double? alertPrice;
  final double? stopPrice;
  final double? targetPrice;

  @override
  ConsumerState<TickerChartScreen> createState() => _TickerChartScreenState();
}

class _TickerChartScreenState extends ConsumerState<TickerChartScreen> {
  String _timeframe = '1D';
  Future<List<_Candle>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final ApiClient api = ref.read(apiClientProvider);
    setState(() {
      _future = _fetchCandles(api, widget.symbol, _timeframe);
    });
    AnalyticsService.chartOpened(
      symbol: widget.symbol,
      timeframe: _timeframe,
    );
  }

  Future<List<_Candle>> _fetchCandles(
    ApiClient api,
    String symbol,
    String tf,
  ) async {
    final Map<String, dynamic> r =
        await api.getJson('/api/market/candles/$symbol?timeframe=$tf');
    final List<dynamic> raw = (r['candles'] as List<dynamic>?) ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_Candle.fromJson)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        elevation: 0,
        title: Text(
          widget.symbol,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            _TimeframeChips(
              value: _timeframe,
              onChanged: (String v) {
                _timeframe = v;
                _refresh();
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<_Candle>>(
                future: _future,
                builder: (BuildContext ctx,
                    AsyncSnapshot<List<_Candle>> snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: LoadingIndicator());
                  }
                  if (snap.hasError) {
                    return ErrorState(
                      message: 'Could not load chart',
                      details: '${snap.error}',
                    );
                  }
                  final List<_Candle> data = snap.data ?? <_Candle>[];
                  if (data.isEmpty) {
                    return const Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(color: Colors.white60),
                      ),
                    );
                  }
                  return Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: _ChartView(
                      candles: data,
                      alertPrice: widget.alertPrice,
                      stopPrice: widget.stopPrice,
                      targetPrice: widget.targetPrice,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeframeChips extends StatelessWidget {
  const _TimeframeChips({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<String> opts = <String>['1D', '1M', '3M', '1Y'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: opts.map((String tf) {
          final bool selected = tf == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tf),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.gold : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppColors.gold
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    tf,
                    style: TextStyle(
                      color: selected ? AppColors.obsidian : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChartView extends StatelessWidget {
  const _ChartView({
    required this.candles,
    this.alertPrice,
    this.stopPrice,
    this.targetPrice,
  });
  final List<_Candle> candles;
  final double? alertPrice;
  final double? stopPrice;
  final double? targetPrice;

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < candles.length; i++)
        FlSpot(i.toDouble(), candles[i].close),
    ];
    final double minY = candles.map((_Candle c) => c.low).reduce(
          (double a, double b) => a < b ? a : b,
        );
    final double maxY = candles.map((_Candle c) => c.high).reduce(
          (double a, double b) => a > b ? a : b,
        );
    final List<HorizontalLine> lines = <HorizontalLine>[];
    if (alertPrice != null) {
      lines.add(HorizontalLine(
        y: alertPrice!,
        color: AppColors.gold,
        strokeWidth: 1.2,
        dashArray: <int>[6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 6, bottom: 2),
          labelResolver: (HorizontalLine _) => 'ENTRY',
          style: const TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ));
    }
    if (stopPrice != null) {
      lines.add(HorizontalLine(
        y: stopPrice!,
        color: const Color(0xFFE07A6B),
        strokeWidth: 1.2,
        dashArray: <int>[3, 3],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.bottomRight,
          padding: const EdgeInsets.only(right: 6, top: 2),
          labelResolver: (HorizontalLine _) => 'STOP',
          style: const TextStyle(
            color: Color(0xFFE07A6B),
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ));
    }
    if (targetPrice != null) {
      lines.add(HorizontalLine(
        y: targetPrice!,
        color: const Color(0xFF8FD89F),
        strokeWidth: 1.2,
        dashArray: <int>[3, 3],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 6, bottom: 2),
          labelResolver: (HorizontalLine _) => 'TARGET',
          style: const TextStyle(
            color: Color(0xFF8FD89F),
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ));
    }
    return LineChart(
      LineChartData(
        minY: minY * 0.998,
        maxY: maxY * 1.002,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (double _) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(horizontalLines: lines),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: AppColors.gold,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.gold.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _Candle {
  _Candle({
    required this.t,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
  final int t;
  final double open;
  final double high;
  final double low;
  final double close;

  factory _Candle.fromJson(Map<String, dynamic> j) {
    return _Candle(
      t: (j['t'] as num?)?.toInt() ?? 0,
      open: (j['o'] as num?)?.toDouble() ?? 0,
      high: (j['h'] as num?)?.toDouble() ?? 0,
      low: (j['l'] as num?)?.toDouble() ?? 0,
      close: (j['c'] as num?)?.toDouble() ?? 0,
    );
  }
}
