import 'package:equatable/equatable.dart';
import 'enums.dart';

/// Mirror of `trade_alerts/{id}` - user-visible buy/watchlist alerts.
class TradeAlert extends Equatable {
  const TradeAlert({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.kind,
    required this.source,
    required this.channel,
    required this.entry,
    required this.reason,
    required this.confidence,
    required this.isHot,
    required this.visibility,
    required this.createdBy,
    required this.createdAt,
    this.target,
    this.stop,
    this.grade,
    this.expiresAt,
    this.notes,
    this.currentPrice,
    this.volume,
    this.dayChangePct,
    this.mode,
  });

  final String id;
  final String symbol;
  final SetupDirection direction;
  final String kind;
  final String source;     // 'manual' | 'scanner' | 'auto_promote'
  final AlertChannel channel;
  final double entry;
  final String reason;
  final int confidence;    // 0-100
  final bool isHot;
  final AlertVisibility visibility;
  final String createdBy;
  final DateTime createdAt;
  final double? target;
  final double? stop;
  final SetupGrade? grade;
  final DateTime? expiresAt;
  final String? notes;

  /// Latest stock price at alert time. Optional - backend may not always send.
  final double? currentPrice;

  /// Latest session volume.
  final int? volume;

  /// Day percent change (signed). Optional.
  final double? dayChangePct;

  /// Scanner mode that produced this alert — "swing" or "leaps".
  /// Auto-merged scanner alerts carry this so the Hot Trade card can render
  /// a SWING / LEAPS badge. Null for manual admin-created alerts.
  final ScannerMode? mode;

  bool get isBullish => direction == SetupDirection.bullish;

  factory TradeAlert.fromMap(String id, Map<String, dynamic> m) {
    return TradeAlert(
      id: id,
      symbol: (m['symbol'] ?? '') as String,
      direction: SetupDirectionX.fromWire(m['direction'] as String?),
      kind: (m['kind'] ?? 'manual') as String,
      source: (m['source'] ?? 'manual') as String,
      channel: AlertChannelX.fromWire(m['channel'] as String?),
      entry: (m['entry'] as num?)?.toDouble() ?? 0,
      reason: (m['reason'] ?? '') as String,
      confidence: (m['confidence'] as num?)?.toInt() ?? 0,
      isHot: (m['isHot'] as bool?) ?? false,
      visibility: AlertVisibilityX.fromWire(m['visibility'] as String?),
      createdBy: (m['createdBy'] ?? '') as String,
      createdAt: _parseDate(m['createdAt']) ?? DateTime.now(),
      target: (m['target'] as num?)?.toDouble(),
      stop: (m['stop'] as num?)?.toDouble(),
      grade: m['grade'] != null
          ? SetupGradeX.fromWire(m['grade'] as String?)
          : null,
      expiresAt: _parseDate(m['expiresAt']),
      notes: m['notes'] as String?,
      currentPrice: (m['currentPrice'] as num?)?.toDouble() ??
          (m['price'] as num?)?.toDouble(),
      volume: (m['volume'] as num?)?.toInt(),
      dayChangePct: (m['dayChangePct'] as num?)?.toDouble() ??
          (m['changePct'] as num?)?.toDouble(),
      mode: m['mode'] is String
          ? ScannerModeX.fromWire(m['mode'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        symbol,
        direction,
        kind,
        source,
        channel,
        entry,
        reason,
        confidence,
        isHot,
        visibility,
        createdBy,
        createdAt,
        target,
        stop,
        grade,
        expiresAt,
        notes,
        currentPrice,
        volume,
        dayChangePct,
        mode,
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
