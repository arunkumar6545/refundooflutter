import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/permissions/sync_permissions_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/add_refund/add_refund_screen.dart';
import '../../features/refund_detail/refund_detail_screen.dart';
import '../../features/archive/archive_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/login/login_screen.dart';
import '../../services/auth_service.dart';

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();

// Slide-from-right + fade transition used on every route push.
CustomTransitionPage<T> _slidePage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Push: slide in from right + fade in
      final slide = Tween<Offset>(
        begin: const Offset(0.08, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      // Pop: outgoing screen slides slightly left and fades
      final secondarySlide = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.04, 0),
      ).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInCubic));

      return SlideTransition(
        position: secondarySlide,
        child: SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
    },
  );
}

// Fade-only transition — used for the splash and login so the first boot
// doesn't feel like the app is sliding in from nowhere.
CustomTransitionPage<T> _fadePage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
  );
}

GoRouter createAppRouter() {
  final auth = AuthService();
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isLoginRoute = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/';
      if (isSplash || isLoginRoute) return null;
      if (!auth.isSignedIn) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _fadePage(context: context, state: state, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _fadePage(context: context, state: state, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/permissions',
        pageBuilder: (context, state) =>
            _slidePage(context: context, state: state, child: const SyncPermissionsScreen()),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) =>
            _fadePage(context: context, state: state, child: const DashboardScreen()),
      ),
      GoRoute(
        path: '/add-refund',
        pageBuilder: (context, state) =>
            _slidePage(context: context, state: state, child: const AddRefundScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            _slidePage(context: context, state: state, child: const ProfileScreen()),
      ),
      GoRoute(
        path: '/reports',
        pageBuilder: (context, state) =>
            _slidePage(context: context, state: state, child: const ReportsScreen()),
      ),
      GoRoute(
        path: '/archive',
        pageBuilder: (context, state) =>
            _slidePage(context: context, state: state, child: const ArchiveScreen()),
      ),
      GoRoute(
        path: '/refund/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slidePage(
            context: context,
            state: state,
            child: RefundDetailScreen(refundId: id),
          );
        },
      ),
    ],
  );
}
