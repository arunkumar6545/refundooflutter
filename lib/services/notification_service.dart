import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/refund_item.dart';

/// Notification IDs
/// 1000–1999: one per overdue refund (id = 1000 + index, max 10)
/// 9000      : daily 9 AM reminder
const _kDailyId = 9000;
const _kOverdueBase = 1000;
const _kMaxOverdue = 10; // cap so we don't spam

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialised = false;

  // ── Init ─────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialised) return;
    tz.initializeTimeZones();

    // Set tz.local to the device's actual timezone so zonedSchedule fires
    // at the right local time on both Android and iOS (defaults to UTC otherwise).
    try {
      final deviceTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTz));
    } catch (_) {
      // Fall back to UTC if timezone lookup fails — better than crashing.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: false, // we request manually below
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Request permission on iOS
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Request permission on Android 13+
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialised = true;
  }

  // ── Overdue refund notifications ──────────────────────────────────────────

  /// Fires one notification per overdue refund (max 10).
  /// Only fires if the user has not disabled notifications.
  static Future<void> scheduleOverdueReminder(
      List<RefundItem> refunds) async {
    if (!await _enabled()) return;
    await _ensureInit();

    final overdue = refunds
        .where((r) => r.isOverdue && r.status != RefundStatus.completed)
        .take(_kMaxOverdue)
        .toList();

    // Cancel previous overdue notifications
    for (var i = 0; i < _kMaxOverdue; i++) {
      await _plugin.cancel(_kOverdueBase + i);
    }

    for (var i = 0; i < overdue.length; i++) {
      final r = overdue[i];
      await _plugin.show(
        _kOverdueBase + i,
        'Refund overdue',
        'Your ${r.formattedAmount} ${r.merchantName} refund is '
            '${r.overdueDays} day${r.overdueDays == 1 ? '' : 's'} overdue.',
        _details(),
      );
    }
  }

  // ── Daily 9 AM reminder ───────────────────────────────────────────────────

  /// Schedules (or re-schedules) a daily notification at 09:00.
  static Future<void> scheduleDailyReminder() async {
    if (!await _enabled()) return;
    await _ensureInit();
    await _plugin.cancel(_kDailyId);

    final now  = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, 9);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _kDailyId,
      'Refundoo',
      'Check your pending refunds — some may be overdue.',
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Cancel all ────────────────────────────────────────────────────────────

  static Future<void> cancelAll() async {
    await _ensureInit();
    await _plugin.cancelAll();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<void> _ensureInit() async {
    if (!_initialised) await init();
  }

  static Future<bool> _enabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  static NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'refundoo_overdue',
      'Overdue Refunds',
      channelDescription: 'Alerts when a refund exceeds its expected arrival date.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(android: android, iOS: ios);
  }
}
