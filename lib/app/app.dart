import 'package:flutter/material.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';

class RefundooApp extends StatelessWidget {
  const RefundooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Refundoo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: createAppRouter(),
    );
  }
}
