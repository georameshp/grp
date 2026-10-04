import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local reminders for todo due dates. FCM covers remote pushes;
/// this service fires on-device at the due time even offline.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings);
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('[GRP] reminders unavailable: $e');
    }
  }

  /// Schedules a reminder at 9:00 on the due date (or 30 min from now when
  /// the due date is today/past, so it still fires).
  Future<void> scheduleTodo({
    required int id,
    required String title,
    required DateTime dueAt,
  }) async {
    if (!_ready) return;
    try {
      var when = tz.TZDateTime(
        tz.local,
        dueAt.year,
        dueAt.month,
        dueAt.day,
        9,
      );
      final soon = tz.TZDateTime.now(tz.local).add(
        const Duration(minutes: 30),
      );
      if (when.isBefore(soon)) when = soon;
      await _plugin.zonedSchedule(
        id,
        'Todo due today',
        title,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'grp_todos',
            'Todo reminders',
            channelDescription: 'Reminders for due todos',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[GRP] could not schedule reminder: $e');
    }
  }

  Future<void> cancelTodo(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id);
  }
}

/// Stable notification id derived from the Firestore doc id.
int reminderIdFor(String docId) => docId.hashCode & 0x7fffffff;
