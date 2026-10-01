import '../demo/demo_mode.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../models/medication.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void> Function()? onReviewRequested;
  Future<void> initialize() async {
    if (_initialized || DemoMode.enabled) return;
    tzdata.initializeTimeZones();
    final p = await SharedPreferences.getInstance();
    // Explicitly selectable home timezone until device timezone support is wired.
    tz.setLocalLocation(tz.getLocation(p.getString('reminder_timezone') ?? 'America/New_York'));
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false));
    await _notifications.initialize(settings, onDidReceiveNotificationResponse: (response) async {
      // Never silently mark a dose taken from a notification tap.
      if (onReviewRequested != null) await onReviewRequested!();
    });
    _initialized = true;
  }
  Future<bool?> requestPermissions() async {
    if (DemoMode.enabled) return false;
    final ios = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return ios.requestPermissions(alert: true, badge: true, sound: true);
    return _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }
  Future<void> scheduleMedicationNotifications(Medication medication) => rescheduleAll();
  Future<void> rescheduleAll() async {
    if (DemoMode.enabled) return;
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    await _notifications.cancelAll();
    if (prefs.getBool('reminders_enabled') == false) return;
    final private = prefs.getBool('private_notifications') ?? true;
    tz.setLocalLocation(tz.getLocation(prefs.getString('reminder_timezone') ?? 'America/New_York'));
    final now = tz.TZDateTime.now(tz.local);
    final requests = <Map<String, dynamic>>[];
    for (final med in Hive.box<Medication>(DemoMode.boxName).values) {
      for (int day = 0; day < 60; day++) {
        final date = DateTime(now.year, now.month, now.day + day);
        if (!med.isScheduledFor(date)) continue;
        for (final time in med.timesFor(date)) {
          final wall = med.scheduledAt(date, time);
          final at = tz.TZDateTime(tz.local,wall.year,wall.month,wall.day,wall.hour,wall.minute);
          if (!at.isAfter(now) || med.wasTakenOn(date,time) || med.wasSkippedOn(date,time) || med.wasMissedOn(date,time)) continue;
          requests.add({'at':at,'med':med,'time':time});
        }
      }
    }
    requests.sort((a,b)=>(a['at'] as tz.TZDateTime).compareTo(b['at'] as tz.TZDateTime));
    // Keep below the iOS pending-notification limit, reserving IDs for snooze/test.
    final next = requests.take(60).toList();
    for (int i = 0; i < next.length; i++) {
      final r = next[i]; final med = r['med'] as Medication;
      await _scheduleNotification(id:i+1,title:private?'DoseBuddy reminder':'Scheduled medication: ${med.name}',body:private?'Open DoseBuddy to review your scheduled dose.':'${med.dosage}. Open to review the record.',scheduledTime:r['at'] as tz.TZDateTime,payload:'${med.id}|${r['time']}');
    }
    await prefs.setString('reminder_horizon',next.isEmpty?'':(next.last['at'] as tz.TZDateTime).toIso8601String());
  }
  Future<void> _scheduleNotification({required int id,required String title,required String body,required tz.TZDateTime scheduledTime,String? payload}) async {
    if (DemoMode.enabled) return;
    const details = NotificationDetails(android:AndroidNotificationDetails('medication_reminders','Medication Reminders',channelDescription:'Scheduled dose reminders',importance:Importance.high,priority:Priority.high,icon:'@mipmap/ic_launcher'),iOS:DarwinNotificationDetails(presentAlert:true,presentBadge:true,presentSound:true));
    await _notifications.zonedSchedule(id,title,body,scheduledTime,details,androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime,payload:payload);
  }
  Future<void> snooze(Medication med,String time,int minutes) async {
    if (![5,10,15,30,60].contains(minutes)) throw ArgumentError('Unsupported snooze duration');
    final p = await SharedPreferences.getInstance();
    if(p.getBool('reminders_enabled')==false) throw StateError('Reminders are switched off');
    await _scheduleNotification(id:100000,title:'DoseBuddy reminder',body:'Open DoseBuddy to review your dose.',scheduledTime:tz.TZDateTime.now(tz.local).add(Duration(minutes:minutes)),payload:'${med.id}|$time');
  }
  Future<void> cancelMedicationNotifications(Medication med) async {
    if (DemoMode.enabled) return;
    final pending = await _notifications.pendingNotificationRequests();
    for(final r in pending){if(r.payload?.startsWith('${med.id}|')==true)await _notifications.cancel(r.id);}
  }
  Future<void> cancelAllNotifications() async { if (!DemoMode.enabled) await _notifications.cancelAll(); }
  Future<void> showImmediateNotification({required String title,required String body}) async {
    if (DemoMode.enabled) return;
    const d=NotificationDetails(android:AndroidNotificationDetails('medication_reminders','Medication Reminders',importance:Importance.high),iOS:DarwinNotificationDetails(presentAlert:true,presentSound:true));
    await _notifications.show(99999,title,body,d);
  }
  Future<void> showTestNotification() async => _scheduleNotification(id:99999,title:'DoseBuddy test reminder',body:'This is a one-time reminder test.',scheduledTime:tz.TZDateTime.now(tz.local).add(const Duration(seconds:5)));
  Future<List<PendingNotificationRequest>> getPendingNotifications() async => DemoMode.enabled ? [] : await _notifications.pendingNotificationRequests();
  Future<int> getPendingNotificationsCount()async=>(await getPendingNotifications()).length;
}
