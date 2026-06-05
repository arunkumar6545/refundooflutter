import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'services/premium_service.dart';

/// Global theme mode notifier — updated by ProfileScreen, consumed by app.dart.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

/// Global premium status notifier — updated by ProfileScreen after purchase.
final premiumNotifier = ValueNotifier<bool>(false);

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
  premiumNotifier.value = await PremiumService.isPremium;
  await NotificationService.init();
  unawaited(NotificationService.scheduleDailyReminder());
  unawaited(AdService.instance.initialize()); // preload interstitial in background
  runApp(const RefundooApp());
}
