/// Centralized route path + name registry. Keep this as the only source of
/// truth - features should import these constants rather than hard-code paths.
class RoutePaths {
  RoutePaths._();

  // Top-level
  static const String splash = '/';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  /// Push opt-in priming. Shown once after first sign-up, before the
  /// OS notification permission prompt.
  static const String enableNotifications = '/enable-notifications';

  // Customer shell
  static const String home = '/home';
  static const String hotTrades = '/hot-trades';
  static const String scanner = '/scanner';
  /// Premarket watchlist — top movers ranked at 9:25 AM ET by the backend
  /// premarket-scan job. Same card format as Hot Trades.
  static const String premarket = '/premarket';
  /// Settings — notification toggles, disclaimer, about, admin tools.
  static const String settings = '/settings';
  /// In-app changelog — version history for users discovering features
  /// they didn't know shipped.
  static const String changelog = '/changelog';
  /// Market news — full list of headlines moved off the home feed into
  /// its own route to keep the home page lean.
  static const String news = '/news';
  /// Backtest results viewer — admin-only screen showing per-detector
  /// measured edge from the backtest engine.
  static const String backtest = '/backtest';
  static const String trades = '/trades';
  static const String performance = '/performance';
  /// Scanner Track Record — auto-tracked simulated outcomes from every
  /// A/A+ scanner alert. Visible to all signed-in users. Separate from
  /// `/performance` which shows real human-taken trade history.
  static const String trackRecord = '/track-record';
  static const String lessons = '/lessons';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String chat = '/chat';

  // Learn (lesson sections/lessons live outside the shell so they have
  // their own back nav and full-screen layouts).
  static const String lessonsSectionName = 'lessons-section';
  static const String lessonsSection = '/lessons/section/:sectionId';
  static String lessonsSectionFor(String sectionId) =>
      '/lessons/section/$sectionId';

  static const String lessonsLessonName = 'lessons-lesson';
  static const String lessonsLesson =
      '/lessons/section/:sectionId/lesson/:lessonId';
  static String lessonsLessonFor(String sectionId, String lessonId) =>
      '/lessons/section/$sectionId/lesson/$lessonId';

  // Chat
  static const String chatRoomName = 'chat-room';
  static const String chatRoom = '/chat/:roomId';
  static String chatRoomFor(String roomId) => '/chat/$roomId';

  // Detail routes
  static const String alertDetailName = 'alert-detail';
  static const String alertDetail = '/alert/:alertId';
  static String alertDetailFor(String id) => '/alert/$id';

  /// In-app chart for any ticker. Path params: symbol. Query params:
  /// alertPrice, stopPrice, targetPrice (optional — drives overlay lines).
  static const String chartName = 'chart';
  static const String chart = '/chart/:symbol';
  static String chartFor(String symbol) => '/chart/$symbol';

  static const String scannerDetailName = 'scanner-detail';
  static const String scannerDetail = '/scanner/:scannerId';
  static String scannerDetailFor(String id) => '/scanner/$id';

  // Admin
  static const String adminDashboard = '/admin';
  /// Admin notifications inbox — list of every admin_event (new signups,
  /// support tickets, role/tier changes). Deep-link target for FCM pushes
  /// fired by the new-account-watcher cron and any future admin events.
  static const String adminNotifications = '/admin/notifications';

  // Support
  static const String supportTicket = '/support/ticket';
}
