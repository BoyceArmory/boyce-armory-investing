import 'package:equatable/equatable.dart';

/// Strongly-typed mirror of the JSON returned by `GET /api/admin/system/status`.
/// Lives in `features/admin/data/` because it's admin-only — no point polluting
/// `core/models/` with internal-ops shapes.
class SystemStatus extends Equatable {
  const SystemStatus({
    required this.service,
    required this.scheduler,
    required this.scanner,
    required this.api,
    required this.push,
    required this.devices,
    required this.firebase,
    required this.queryTimeMs,
    required this.fetchedAt,
  });

  final ServiceInfo service;
  final SchedulerInfo scheduler;
  final ScannerInfo scanner;
  final ApiInfo api;
  final PushInfo push;
  final DevicesInfo devices;
  final FirebaseInfo firebase;
  final int queryTimeMs;

  /// Set on the client side when we received the payload. Useful for "X seconds
  /// ago" indicators in the UI.
  final DateTime fetchedAt;

  factory SystemStatus.fromJson(Map<String, dynamic> j) {
    return SystemStatus(
      service: ServiceInfo.fromJson(_obj(j['service'])),
      scheduler: SchedulerInfo.fromJson(_obj(j['scheduler'])),
      scanner: ScannerInfo.fromJson(_obj(j['scanner'])),
      api: ApiInfo.fromJson(_obj(j['api'])),
      push: PushInfo.fromJson(_obj(j['push'])),
      devices: DevicesInfo.fromJson(_obj(j['devices'])),
      firebase: FirebaseInfo.fromJson(_obj(j['firebase'])),
      queryTimeMs: (j['queryTimeMs'] as num?)?.toInt() ?? 0,
      fetchedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        service, scheduler, scanner, api, push, devices, firebase, queryTimeMs,
        fetchedAt,
      ];
}

class ServiceInfo extends Equatable {
  const ServiceInfo({required this.env, required this.serverTime, required this.uptimeSec});
  final String env;
  final DateTime? serverTime;
  final int uptimeSec;

  factory ServiceInfo.fromJson(Map<String, dynamic> j) => ServiceInfo(
        env: (j['env'] as String?) ?? 'unknown',
        serverTime: _parseDt(j['serverTime']),
        uptimeSec: (j['uptimeSec'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [env, serverTime, uptimeSec];
}

class SchedulerInfo extends Equatable {
  const SchedulerInfo({required this.enabled, required this.note});
  final bool enabled;
  final String note;

  factory SchedulerInfo.fromJson(Map<String, dynamic> j) => SchedulerInfo(
        enabled: (j['enabled'] as bool?) ?? false,
        note: (j['note'] as String?) ?? '',
      );

  @override
  List<Object?> get props => [enabled, note];
}

class ScannerInfo extends Equatable {
  const ScannerInfo({
    required this.lastRuns,
    required this.cooldownTableSize,
    required this.recentRuns,
  });
  final Map<String, RunSummary?> lastRuns;
  final int cooldownTableSize;
  final List<RunSummary> recentRuns;

  factory ScannerInfo.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> lr = _obj(j['lastRuns']);
    final Map<String, RunSummary?> typed = {};
    for (final mode in const ['day', 'swing', 'leaps']) {
      final v = lr[mode];
      typed[mode] = (v is Map<String, dynamic>) ? RunSummary.fromJson(v) : null;
    }
    final recent = (j['recentRuns'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(RunSummary.fromJson)
            .toList(growable: false) ??
        const <RunSummary>[];
    return ScannerInfo(
      lastRuns: typed,
      cooldownTableSize: (j['cooldownTableSize'] as num?)?.toInt() ?? 0,
      recentRuns: recent,
    );
  }

  @override
  List<Object?> get props => [lastRuns, cooldownTableSize, recentRuns];
}

class RunSummary extends Equatable {
  const RunSummary({
    required this.runId,
    required this.mode,
    required this.startedAt,
    required this.finishedAt,
    required this.tickersScanned,
    required this.signalsFound,
    required this.signalsPublished,
    required this.signalsPromoted,
    this.durationMs,
    this.apiCallsUsed,
    this.cacheHits,
    this.cacheMisses,
    this.pushesSent,
    this.pushesSkipped,
    this.skippedTickers,
    this.rejectReasons,
  });

  final String runId;
  final String mode;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int tickersScanned;
  final int signalsFound;
  final int signalsPublished;
  final int signalsPromoted;
  final int? durationMs;
  final int? apiCallsUsed;
  final int? cacheHits;
  final int? cacheMisses;
  final int? pushesSent;
  final int? pushesSkipped;
  final int? skippedTickers;
  final Map<String, int>? rejectReasons;

  factory RunSummary.fromJson(Map<String, dynamic> j) => RunSummary(
        runId: (j['runId'] as String?) ?? '',
        mode: (j['mode'] as String?) ?? 'swing',
        startedAt: _parseDt(j['startedAt']),
        finishedAt: _parseDt(j['finishedAt']),
        tickersScanned: (j['tickersScanned'] as num?)?.toInt() ?? 0,
        signalsFound: (j['signalsFound'] as num?)?.toInt() ?? 0,
        signalsPublished: (j['signalsPublished'] as num?)?.toInt() ?? 0,
        signalsPromoted: (j['signalsPromoted'] as num?)?.toInt() ?? 0,
        durationMs: (j['durationMs'] as num?)?.toInt(),
        apiCallsUsed: (j['apiCallsUsed'] as num?)?.toInt(),
        cacheHits: (j['cacheHits'] as num?)?.toInt(),
        cacheMisses: (j['cacheMisses'] as num?)?.toInt(),
        pushesSent: (j['pushesSent'] as num?)?.toInt(),
        pushesSkipped: (j['pushesSkipped'] as num?)?.toInt(),
        skippedTickers: (j['skippedTickers'] as num?)?.toInt(),
        rejectReasons: (j['rejectReasons'] is Map<String, dynamic>)
            ? (j['rejectReasons'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
              )
            : null,
      );

  @override
  List<Object?> get props => [runId, mode, startedAt, signalsFound, signalsPublished];
}

class ApiInfo extends Equatable {
  const ApiInfo({required this.lifetime, required this.currentRun});
  final ApiStats lifetime;
  final ApiStats currentRun;

  factory ApiInfo.fromJson(Map<String, dynamic> j) => ApiInfo(
        lifetime: ApiStats.fromJson(_obj(j['lifetime'])),
        currentRun: ApiStats.fromJson(_obj(j['currentRun'])),
      );

  @override
  List<Object?> get props => [lifetime, currentRun];
}

class ApiStats extends Equatable {
  const ApiStats({required this.totalCalls, required this.byProvider, required this.warnings});
  final int totalCalls;
  final Map<String, int> byProvider;
  final int warnings;

  factory ApiStats.fromJson(Map<String, dynamic> j) {
    final bp = (j['byProvider'] is Map<String, dynamic>)
        ? (j['byProvider'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0))
        : <String, int>{};
    return ApiStats(
      totalCalls: (j['totalCalls'] as num?)?.toInt() ?? 0,
      byProvider: bp,
      warnings: (j['warnings'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [totalCalls, byProvider, warnings];
}

class PushInfo extends Equatable {
  const PushInfo({required this.scannerPromotesEnabled, required this.queue});
  final bool scannerPromotesEnabled;
  final PushQueue queue;

  factory PushInfo.fromJson(Map<String, dynamic> j) => PushInfo(
        scannerPromotesEnabled: (j['scannerPromotesEnabled'] as bool?) ?? true,
        queue: PushQueue.fromJson(_obj(j['queue'])),
      );

  @override
  List<Object?> get props => [scannerPromotesEnabled, queue];
}

class PushQueue extends Equatable {
  const PushQueue({
    required this.recentCount,
    required this.pending,
    required this.sentRecent,
    required this.failedRecent,
    required this.lastSentAt,
    required this.recent,
  });
  final int recentCount;
  final int pending;
  final int sentRecent;
  final int failedRecent;
  final DateTime? lastSentAt;
  final List<PushEntry> recent;

  factory PushQueue.fromJson(Map<String, dynamic> j) => PushQueue(
        recentCount: (j['recentCount'] as num?)?.toInt() ?? 0,
        pending: (j['pending'] as num?)?.toInt() ?? 0,
        sentRecent: (j['sentRecent'] as num?)?.toInt() ?? 0,
        failedRecent: (j['failedRecent'] as num?)?.toInt() ?? 0,
        lastSentAt: _parseDt(j['lastSentAt']),
        recent: (j['recent'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(PushEntry.fromJson)
                .toList(growable: false) ??
            const <PushEntry>[],
      );

  @override
  List<Object?> get props => [recentCount, pending, sentRecent, failedRecent, lastSentAt, recent];
}

class PushEntry extends Equatable {
  const PushEntry({
    required this.id,
    required this.status,
    required this.source,
    required this.title,
    this.symbol,
    this.mode,
    this.grade,
    this.recipientCount,
    this.createdAt,
    this.sentAt,
    this.lastError,
  });
  final String id;
  final String status;
  final String source;
  final String title;
  final String? symbol;
  final String? mode;
  final String? grade;
  final int? recipientCount;
  final DateTime? createdAt;
  final DateTime? sentAt;
  final String? lastError;

  factory PushEntry.fromJson(Map<String, dynamic> j) => PushEntry(
        id: (j['id'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'unknown',
        source: (j['source'] as String?) ?? 'manual',
        title: (j['title'] as String?) ?? '',
        symbol: j['symbol'] as String?,
        mode: j['mode'] as String?,
        grade: j['grade'] as String?,
        recipientCount: (j['recipientCount'] as num?)?.toInt(),
        createdAt: _parseDt(j['createdAt']),
        sentAt: _parseDt(j['sentAt']),
        lastError: j['lastError'] as String?,
      );

  @override
  List<Object?> get props => [id, status, source, title, symbol, mode, grade, recipientCount, createdAt, sentAt];
}

class DevicesInfo extends Equatable {
  const DevicesInfo({required this.activeTokenCount});
  final int? activeTokenCount;

  factory DevicesInfo.fromJson(Map<String, dynamic> j) =>
      DevicesInfo(activeTokenCount: (j['activeTokenCount'] as num?)?.toInt());

  @override
  List<Object?> get props => [activeTokenCount];
}

class FirebaseInfo extends Equatable {
  const FirebaseInfo({required this.initialized});
  final bool initialized;

  factory FirebaseInfo.fromJson(Map<String, dynamic> j) =>
      FirebaseInfo(initialized: (j['initialized'] as bool?) ?? false);

  @override
  List<Object?> get props => [initialized];
}

Map<String, dynamic> _obj(dynamic v) =>
    v is Map<String, dynamic> ? v : <String, dynamic>{};

DateTime? _parseDt(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}
