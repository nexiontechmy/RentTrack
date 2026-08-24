import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules a recurring monthly rent reminder notification, firing on a
/// user-chosen day of month at 9:00 AM local time — a genuine recurring
/// alarm (via zonedSchedule + dayOfMonthAndTime), not a one-off toast.
class NotificationService {
  static const _reminderNotificationId = 1001;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      // Fall back to UTC if the platform timezone can't be resolved.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    _initialized = true;
  }

  Future<void> requestPermission() async {
    await _ensureInitialized();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedules (or reschedules) the recurring monthly reminder for [day]
  /// of every month at 9:00 AM local time.
  Future<void> scheduleMonthlyReminder(int day) async {
    await _ensureInitialized();
    await _plugin.cancel(_reminderNotificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, day, 9, 0);
    if (scheduled.isBefore(now)) {
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      scheduled = tz.TZDateTime(tz.local, nextYear, nextMonth, day, 9, 0);
    }

    await _plugin.zonedSchedule(
      _reminderNotificationId,
      'Rent Payment Reminder',
      "It's rent day — open RentTrack to record this month's payments.",
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rent_reminder',
          'Rent Reminders',
          channelDescription: 'Monthly recurring rent payment reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  Future<void> cancelReminder() async {
    await _plugin.cancel(_reminderNotificationId);
  }

  /// Fires an immediate notification — used only to let the user verify
  /// permissions/appearance; the real reminder is the scheduled one above.
  Future<void> showTestNotification() async {
    await _ensureInitialized();
    await _plugin.show(
      9999,
      'RentTrack Test Notification',
      'Notifications are working. Your monthly reminder is scheduled.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rent_reminder',
          'Rent Reminders',
          channelDescription: 'Monthly recurring rent payment reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
