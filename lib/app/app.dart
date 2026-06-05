import 'package:flutter/material.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../main.dart' show themeModeNotifier;

class RefundooApp extends StatelessWidget {
  const RefundooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) => MaterialApp.router(
        title: 'Refundoo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        routerConfig: createAppRouter(),
      ),
    );
  }
}
