/// Centralized route path + name registry. Keep this as the only source of
/// truth - features should import these constants rather than hard-code paths.
class RoutePaths {
  RoutePaths._();

  // Top-level
  static const String splash = '/';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';

  // Customer shell
  static const String home = '/home';
  static const String hotTrades = '/hot-trades';
  static const String scanner = '/scanner';
  /// Premarket watchlist — top movers ranked at 9:25 AM ET by the backend
  /// premarket-scan job. Same card format as Hot Trades.
  static const String premarket = '/premarket';
  static const String trades = '/trades';
  static const String performance = '/performance';
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

  static const String scannerDetailName = 'scanner-detail';
  static const String scannerDetail = '/scanner/:scannerId';
  static String scannerDetailFor(String id) => '/scanner/$id';

  // Admin
  static const String adminDashboard = '/admin';

  // Support
  static const String supportTicket = '/support/ticket';
}
