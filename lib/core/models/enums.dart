// Domain enums shared across features. Strings match the backend exactly so
// parsing/serialization is symmetric.

enum SetupDirection { bullish, bearish }

extension SetupDirectionX on SetupDirection {
  String get wire => name;
  bool get isBull => this == SetupDirection.bullish;

  static SetupDirection fromWire(String? s) {
    return s == 'bearish' ? SetupDirection.bearish : SetupDirection.bullish;
  }
}

enum SetupGrade { aPlus, a, b, c, watch }

extension SetupGradeX on SetupGrade {
  String get wire => switch (this) {
        SetupGrade.aPlus => 'A+',
        SetupGrade.a => 'A',
        SetupGrade.b => 'B',
        SetupGrade.c => 'C',
        SetupGrade.watch => 'WATCH',
      };

  String get label => wire;

  /// True for grades that should display the "WATCH" tag — currently C and
  /// WATCH itself. The tag tells users "monitor this; don't trade it yet."
  bool get isWatchTier => this == SetupGrade.c || this == SetupGrade.watch;

  static SetupGrade fromWire(String? s) {
    return switch (s) {
      'A+' => SetupGrade.aPlus,
      'A' => SetupGrade.a,
      'B' => SetupGrade.b,
      'C' => SetupGrade.c,
      _ => SetupGrade.watch,
    };
  }
}

enum AlertVisibility { public, adminOnly }

extension AlertVisibilityX on AlertVisibility {
  String get wire => this == AlertVisibility.public ? 'public' : 'admin_only';
  static AlertVisibility fromWire(String? s) =>
      s == 'admin_only' ? AlertVisibility.adminOnly : AlertVisibility.public;
}

enum UserRole { admin, customer }

extension UserRoleX on UserRole {
  String get wire => name;
  static UserRole fromWire(String? s) =>
      s == 'admin' ? UserRole.admin : UserRole.customer;
}

// Premium-tier gate (Sep 2026). Scanner and the ADMIN BUYS chat room are
// premium-only; Learn (Academy) is gated the same way in the UI. Backend
// enforcement lives in firestore.rules (isPremium()) — this enum just
// mirrors the wire values so the client can match the same logic for UX
// (showing a PremiumGate upsell instead of a raw permission error).
enum UserTier { free, premium }

extension UserTierX on UserTier {
  String get wire => name;
  static UserTier fromWire(String? s) =>
      s == 'premium' ? UserTier.premium : UserTier.free;
}

// Strategy tag on TradingView-sourced scanner alerts (Sep 2026). Lets
// Settings offer per-strategy push toggles alongside the existing
// per-mode (day/swing/leaps) ones — see notification-queue.service.ts.
enum AlertStrategy { trendPullback, meanReversion, doubleBreakout }

extension AlertStrategyX on AlertStrategy {
  String get wire => switch (this) {
        AlertStrategy.trendPullback => 'trend_pullback',
        AlertStrategy.meanReversion => 'mean_reversion',
        AlertStrategy.doubleBreakout => 'double_breakout',
      };

  String get label => switch (this) {
        AlertStrategy.trendPullback => 'Trend Pullback',
        AlertStrategy.meanReversion => 'Mean Reversion',
        AlertStrategy.doubleBreakout => 'Double Breakout',
      };

  static AlertStrategy fromWire(String? s) => switch (s) {
        'mean_reversion' => AlertStrategy.meanReversion,
        'double_breakout' => AlertStrategy.doubleBreakout,
        _ => AlertStrategy.trendPullback,
      };
}

// Day and Scalp modes were removed (July 2026) when the app went
// swing+leaps focused on the old custom scanner. 'day' was reintroduced
// (August 2026) as a TradingView-sourced channel alongside swing/leaps —
// see backend/src/controllers/webhook.controller.ts. fromWire still maps
// any stale 'scalp' wire values from old Firestore docs to swing as a safe
// fallback.
enum ScannerMode { day, swing, leaps }

extension ScannerModeX on ScannerMode {
  String get wire => name;
  String get label => switch (this) {
        ScannerMode.day => 'Day',
        ScannerMode.swing => 'Swing',
        ScannerMode.leaps => 'LEAPS',
      };

  static ScannerMode fromWire(String? s) => switch (s) {
        'day' => ScannerMode.day,
        'leaps' => ScannerMode.leaps,
        _ => ScannerMode.swing,
      };
}

enum AlertChannel { buy, watchlist, scanner, recap }

extension AlertChannelX on AlertChannel {
  String get wire => name;
  static AlertChannel fromWire(String? s) => switch (s) {
        'watchlist' => AlertChannel.watchlist,
        'scanner' => AlertChannel.scanner,
        'recap' => AlertChannel.recap,
        _ => AlertChannel.buy,
      };
}
