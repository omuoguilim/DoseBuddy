import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/medication.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    _initialized = true;
    print('✅ Notifications initialized');
  }

  Future<void> scheduleMedicationNotifications(Medication medication) async {
    // Cancel existing notifications for this medication
    await cancelMedicationNotifications(medication);

    // Schedule notifications for each time
    for (int i = 0; i < medication.times.length; i++) {
      final time = medication.times[i];
      final notificationId = _getNotificationId(medication.id, i);
      
      await _scheduleNotification(
        id: notificationId,
        title: '💊 Time to take ${medication.name}',
        body: '${medication.dosage} - ${medication.notes.isNotEmpty ? medication.notes : "Don't forget!"}',
        scheduledTime: _parseTimeString(time),
      );
    }

    print('📅 Scheduled ${medication.times.length} notifications for ${medication.name}');
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'medication_reminders',
      'Medication Reminders',
      channelDescription: 'Notifications for medication schedules',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );
  }

  tz.TZDateTime _parseTimeString(String timeStr) {
    final now = tz.TZDateTime.now(tz.local);
    final parts = timeStr.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final isPM = parts[1].toUpperCase() == 'PM';

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  int _getNotificationId(String medicationId, int timeIndex) {
    // Create unique ID from medication ID and time index
    return medicationId.hashCode + timeIndex;
  }

  Future<void> cancelMedicationNotifications(Medication medication) async {
    for (int i = 0; i < medication.times.length; i++) {
      final notificationId = _getNotificationId(medication.id, i);
      await _notifications.cancel(notificationId);
    }
    print('🔕 Cancelled notifications for ${medication.name}');
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('🔕 Cancelled all notifications');
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'medication_reminders',
      'Medication Reminders',
      channelDescription: 'Notifications for medication schedules',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
    );
  }
}