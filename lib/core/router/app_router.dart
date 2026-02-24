import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/permissions/sync_permissions_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/add_refund/add_refund_screen.dart';
import '../../features/refund_detail/refund_detail_screen.dart';
import '../../features/splash/splash_screen.dart';

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
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
        path: '/refund/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return RefundDetailScreen(refundId: id);
        },
      ),
    ],
  );
}
