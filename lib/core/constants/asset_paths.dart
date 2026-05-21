/// Single source of truth for asset paths. Every reference to an asset path
/// should flow through here so renames are mechanical.
class AssetPaths {
  AssetPaths._();

  // --- Brand / logos ---
  /// Full Boyce Armory wordmark/logo (used on splash, login, large headers).
  static const String brandLogo = 'assets/logo.png';
  static const String splashLogo = 'assets/branding/splash_logo.png';
  static const String appIcon = 'assets/branding/app_icon.png';
  static const String appIconForeground =
      'assets/branding/app_icon_foreground.png';

  // --- Card backgrounds ---
  static const String bgBullCall = 'assets/backgrounds/bull_call_bg.png';
  static const String bgBearPut = 'assets/backgrounds/bear_put_bg.png';
  static const String bgClosedWin = 'assets/backgrounds/closed_win_bg.png';
  static const String bgClosedLoss = 'assets/backgrounds/closed_loss_bg.png';
  static const String bgSmartMoneyBull =
      'assets/backgrounds/smart_money_bull.png';
  static const String bgSmartMoneyBear =
      'assets/backgrounds/smart_money_bear.png';

  // --- Lesson hero images ---
  static const String learnDir = 'assets/learn/';
  static const String learnBreakdown = '${learnDir}breakdown.png';
  static const String learnBreakout = '${learnDir}breakout.png';
  static const String learnBullFlag = '${learnDir}bull_flag.png';
  static const String learnCallsVsPuts = '${learnDir}calls_vs_puts.png';
  static const String learnDiscipline = '${learnDir}discipline.png';
  static const String learnEma = '${learnDir}ema.png';
  static const String learnFakeBreakout = '${learnDir}fake_breakout.png';
  static const String learnFomo = '${learnDir}fomo.png';
  static const String learnHowToReadAlerts =
      '${learnDir}how_to_read_alerts.png';
  static const String learnOvertrading = '${learnDir}overtrading.png';
  static const String learnPullbackEntry = '${learnDir}pullback_entry.png';
  static const String learnRangeBreak = '${learnDir}range_break.png';
  static const String learnResistanceRejection =
      '${learnDir}resistance_rejection.png';
  static const String learnReversal = '${learnDir}reversal.png';
  static const String learnSupportBounce = '${learnDir}support_bounce.png';
  static const String learnSupportResistance =
      '${learnDir}support_resistance.png';
  static const String learnTrendContinuation =
      '${learnDir}trend_continuation.png';
  static const String learnVolume = '${learnDir}volume.png';
  static const String learnVwap = '${learnDir}vwap.png';

  // --- Quick-action button artwork ---
  static const String btnHotTrades = 'assets/buttons/hot_trades_button.png';
  static const String btnScanner = 'assets/buttons/scanner_button.png';
  static const String btnChat = 'assets/buttons/chat_button.png';
  static const String btnLearn = 'assets/buttons/learn_button.png';

  // --- Chat room icons ---
  static const String chatRoomGeneral = 'assets/buttons/general_chat.png';
  static const String chatRoomGains = 'assets/buttons/show_gains.png';
  static const String chatRoomQuestions = 'assets/buttons/questions.png';
  static const String chatRoomWatchlist = 'assets/buttons/watchlist_talk.png';

  // --- Screen banner headers ---
  static const String headerHome = 'assets/headers/home_banner.png';
  static const String headerProfile = 'assets/headers/profile_header.png';
  static const String headerChatRoom = 'assets/headers/chat_room_header.png';

  // --- Ticker logos ---
  /// Build the ticker logo asset path for a symbol.
  /// e.g. tickerLogo('AAPL') -> 'assets/ticker_logos/AAPL.png'
  static String tickerLogo(String symbol) =>
      'assets/ticker_logos/${symbol.toUpperCase()}.png';
}
