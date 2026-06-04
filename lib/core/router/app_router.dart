import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/permissions/sync_permissions_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/add_refund/add_refund_screen.dart';
import '../../features/refund_detail/refund_detail_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/login/login_screen.dart';
import '../../services/auth_service.dart';

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter() {
  final auth = AuthService();
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isLoginRoute = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/';
      // Let splash and login through unconditionally
      if (isSplash || isLoginRoute) return null;
      // Guard everything else
      if (!auth.isSignedIn) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/permissions',
        builder: (_, __) => const SyncPermissionsScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/add-refund',
        builder: (_, __) => const AddRefundScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (_, __) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/refund/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return RefundDetailScreen(refundId: id);
        },
      ),
    ],
  );
}
