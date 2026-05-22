import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_state_provider.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/support/presentation/screens/support_ticket_screen.dart';
import '../../features/alerts/presentation/screens/alert_detail_screen.dart';
import '../../features/alerts/presentation/screens/hot_trades_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/chat/presentation/screens/chat_home_screen.dart';
import '../../features/chat/presentation/screens/chat_room_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/lessons/presentation/screens/lesson_detail_screen.dart';
import '../../features/lessons/presentation/screens/lesson_section_screen.dart';
import '../../features/lessons/presentation/screens/lessons_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/performance/presentation/screens/performance_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/scanner/presentation/screens/scanner_detail_screen.dart';
import '../../features/scanner/presentation/screens/scanner_screen.dart';
import '../../features/trades/presentation/screens/trades_screen.dart';
import '../../shared/layouts/app_shell.dart';
import 'route_paths.dart';

/// Single source of truth for navigation. Listens to auth state so the router
/// reroutes automatically when the user signs in/out or their role changes.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final _RouterRefreshNotifier notifier = _RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: (BuildContext context, GoRouterState state) {
      final bool bootstrapping = ref.read(authBootstrappingProvider);
      final bool signedIn =
          ref.read(currentFirebaseUserProvider) != null;
      final bool isAdmin = ref.read(isAdminProvider);
      final String location = state.matchedLocation;

      // While auth is still resolving, stay on splash.
      if (bootstrapping) {
        return location == RoutePaths.splash ? null : RoutePaths.splash;
      }

      final bool inAuthFlow = location == RoutePaths.signIn ||
          location == RoutePaths.signUp ||
          location == RoutePaths.forgotPassword;

      if (!signedIn) {
        if (inAuthFlow) return null;
        return RoutePaths.signIn;
      }

      // Signed in - bounce off splash + auth screens to home.
      if (location == RoutePaths.splash || inAuthFlow) {
        return RoutePaths.home;
      }

      // Guard admin routes.
      if (location.startsWith(RoutePaths.adminDashboard) && !isAdmin) {
        return RoutePaths.home;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.splash,
        builder: (BuildContext c, GoRouterState s) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.signIn,
        builder: (BuildContext c, GoRouterState s) => const SignInScreen(),
      ),
      GoRoute(
        path: RoutePaths.signUp,
        builder: (BuildContext c, GoRouterState s) => const SignUpScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (BuildContext c, GoRouterState s) =>
            const ForgotPasswordScreen(),
      ),

      // Detail routes live outside the shell so they can use full-screen layouts.
      GoRoute(
        path: RoutePaths.alertDetail,
        name: RoutePaths.alertDetailName,
        builder: (BuildContext c, GoRouterState s) =>
            AlertDetailScreen(alertId: s.pathParameters['alertId']!),
      ),
      GoRoute(
        path: RoutePaths.scannerDetail,
        name: RoutePaths.scannerDetailName,
        builder: (BuildContext c, GoRouterState s) =>
            ScannerDetailScreen(scannerId: s.pathParameters['scannerId']!),
      ),

      // Lesson section + lesson detail (full-screen).
      GoRoute(
        path: RoutePaths.lessonsSection,
        name: RoutePaths.lessonsSectionName,
        builder: (BuildContext c, GoRouterState s) => LessonSectionScreen(
          sectionId: s.pathParameters['sectionId']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.lessonsLesson,
        name: RoutePaths.lessonsLessonName,
        builder: (BuildContext c, GoRouterState s) => LessonDetailScreen(
          sectionId: s.pathParameters['sectionId']!,
          lessonId: s.pathParameters['lessonId']!,
        ),
      ),

      // Chat room (full-screen).
      GoRoute(
        path: RoutePaths.chatRoom,
        name: RoutePaths.chatRoomName,
        builder: (BuildContext c, GoRouterState s) =>
            ChatRoomScreen(roomId: s.pathParameters['roomId']!),
      ),

      // Admin route lives outside the customer shell.
      GoRoute(
        path: RoutePaths.adminDashboard,
        builder: (BuildContext c, GoRouterState s) =>
            const AdminDashboardScreen(),
      ),

      // Support ticket (full-screen) — opened from Profile.
      GoRoute(
        path: RoutePaths.supportTicket,
        builder: (BuildContext c, GoRouterState s) =>
            const SupportTicketScreen(),
      ),

      // Customer shell with bottom navigation.
      ShellRoute(
        builder: (BuildContext c, GoRouterState s, Widget child) =>
            AppShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.home,
            builder: (BuildContext c, GoRouterState s) => const HomeScreen(),
          ),
          GoRoute(
            path: RoutePaths.hotTrades,
            builder: (BuildContext c, GoRouterState s) =>
                const HotTradesScreen(),
          ),
          GoRoute(
            path: RoutePaths.scanner,
            builder: (BuildContext c, GoRouterState s) =>
                const ScannerScreen(),
          ),
          GoRoute(
            path: RoutePaths.trades,
            builder: (BuildContext c, GoRouterState s) => const TradesScreen(),
          ),
          GoRoute(
            path: RoutePaths.chat,
            builder: (BuildContext c, GoRouterState s) =>
                const ChatHomeScreen(),
          ),
          GoRoute(
            path: RoutePaths.performance,
            builder: (BuildContext c, GoRouterState s) =>
                const PerformanceScreen(),
          ),
          GoRoute(
            path: RoutePaths.lessons,
            builder: (BuildContext c, GoRouterState s) =>
                const LessonsScreen(),
          ),
          GoRoute(
            path: RoutePaths.notifications,
            builder: (BuildContext c, GoRouterState s) =>
                const NotificationsScreen(),
          ),
          GoRoute(
            path: RoutePaths.profile,
            builder: (BuildContext c, GoRouterState s) =>
                const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod auth/role + bootstrap state changes -> GoRouter.refreshListenable.
///
/// Each listener uses the provider's *actual* value type so Riverpod attaches
/// the subscription correctly, and `fireImmediately: true` covers the race
/// where the provider transitions before we subscribe.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    _authSub = ref.listen<AsyncValue<User?>>(
      authStateProvider,
      (_, __) => notifyListeners(),
      fireImmediately: true,
    );
    _bootstrapSub = ref.listen<bool>(
      authBootstrappingProvider,
      (_, __) => notifyListeners(),
      fireImmediately: true,
    );
    _adminSub = ref.listen<bool>(
      isAdminProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<User?>> _authSub;
  late final ProviderSubscription<bool> _bootstrapSub;
  late final ProviderSubscription<bool> _adminSub;

  @override
  void dispose() {
    _authSub.close();
    _bootstrapSub.close();
    _adminSub.close();
    super.dispose();
  }
}
