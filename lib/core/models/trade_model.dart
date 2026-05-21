import 'package:equatable/equatable.dart';
import 'enums.dart';

enum TradeStatus { open, closed }

extension TradeStatusX on TradeStatus {
  String get wire => name;
  static TradeStatus fromWire(String? s) =>
      s == 'closed' ? TradeStatus.closed : TradeStatus.open;
}

enum TradeResult { win, loss, breakeven }

extension TradeResultX on TradeResult {
  String get wire => name;
  static TradeResult? fromWire(String? s) => switch (s) {
        'win' => TradeResult.win,
        'loss' => TradeResult.loss,
        'breakeven' => TradeResult.breakeven,
        _ => null,
      };
}

/// Mirror of `active_trades` / `closed_trades`.
class Trade extends Equatable {
  const Trade({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.entry,
    required this.status,
    required this.openedAt,
    this.exit,
    this.target,
    this.stop,
    this.qty,
    this.result,
    this.pnlPct,
    this.pnlAbs,
    this.closedAt,
    this.notes,
    this.screenshotUrl,
  });

  final String id;
  final String symbol;
  final SetupDirection direction;
  final double entry;
  final TradeStatus status;
  final DateTime openedAt;
  final double? exit;
  final double? target;
  final double? stop;
  final int? qty;
  final TradeResult? result;
  final double? pnlPct;
  final double? pnlAbs;
  final DateTime? closedAt;
  final String? notes;
  final String? screenshotUrl;

  bool get isOpen => status == TradeStatus.open;
  bool get isBullish => direction == SetupDirection.bullish;

  factory Trade.fromMap(String id, Map<String, dynamic> m) {
    return Trade(
      id: id,
      symbol: (m['symbol'] ?? '') as String,
      direction: SetupDirectionX.fromWire(m['direction'] as String?),
      entry: (m['entry'] as num?)?.toDouble() ?? 0,
      status: TradeStatusX.fromWire(m['status'] as String?),
      openedAt: _parseDate(m['openedAt']) ?? DateTime.now(),
      exit: (m['exit'] as num?)?.toDouble(),
      target: (m['target'] as num?)?.toDouble(),
      stop: (m['stop'] as num?)?.toDouble(),
      qty: (m['qty'] as num?)?.toInt(),
      result: TradeResultX.fromWire(m['result'] as String?),
      pnlPct: (m['pnlPct'] as num?)?.toDouble(),
      pnlAbs: (m['pnlAbs'] as num?)?.toDouble(),
      closedAt: _parseDate(m['closedAt']),
      notes: m['notes'] as String?,
      screenshotUrl: m['screenshotUrl'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        symbol,
        direction,
        entry,
        status,
        openedAt,
        exit,
        target,
        stop,
        qty,
        result,
        pnlPct,
        pnlAbs,
        closedAt,
        notes,
        screenshotUrl,
      ];
}

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  try {
    final dynamic d = raw;
    return d.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
