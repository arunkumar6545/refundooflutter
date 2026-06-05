import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'services/notification_service.dart';

/// Global theme mode notifier — updated by ProfileScreen, consumed by app.dart.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

ThemeMode _parseThemeMode(String? value) {
  switch (value) {
    case 'light':  return ThemeMode.light;
    case 'dark':   return ThemeMode.dark;
    default:       return ThemeMode.system;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  themeModeNotifier.value = _parseThemeMode(prefs.getString('theme_mode'));
  await NotificationService.init();
  unawaited(NotificationService.scheduleDailyReminder());
  runApp(const RefundooApp());
}
