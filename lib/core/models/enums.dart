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

enum SetupGrade { aPlus, a, b, watch }

extension SetupGradeX on SetupGrade {
  String get wire => switch (this) {
        SetupGrade.aPlus => 'A+',
        SetupGrade.a => 'A',
        SetupGrade.b => 'B',
        SetupGrade.watch => 'WATCH',
      };

  String get label => wire;

  static SetupGrade fromWire(String? s) {
    return switch (s) {
      'A+' => SetupGrade.aPlus,
      'A' => SetupGrade.a,
      'B' => SetupGrade.b,
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
