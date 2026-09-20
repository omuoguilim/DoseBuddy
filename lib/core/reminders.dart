import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'records.dart';

class ReminderPlan {
  final List<ScheduledDose> doses;
  final DateTime through;
  ReminderPlan(this.doses,this.through);
  factory ReminderPlan.create(Records r, DateTime now) {
    final end=DateTime(now.year,now.month,now.day+30);
    final future=r.schedule(now,end).where((d)=>d.at.isAfter(now)&&!r.outcomes.containsKey(d.key)).toList();
    final selected=future.take(60).toList();
    return ReminderPlan(selected,future.length>60 ? selected.last.at : end);
  }
}

class Reminders extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin plugin=FlutterLocalNotificationsPlugin();
  NotificationResponse? pendingAction;
  String? error, zone;
  DateTime? through;
  int count=0;
  bool initialized=false, syncing=false;
  Future<void> initialize() async {
    if(initialized)return;
    tzdata.initializeTimeZones();
    await plugin.initialize(const InitializationSettings(
      android:AndroidInitializationSettings('@drawable/ic_notification'),
      iOS:DarwinInitializationSettings(requestAlertPermission:false,requestBadgePermission:false,requestSoundPermission:false),
    ),onDidReceiveNotificationResponse:(r){pendingAction=r;notifyListeners();});
    final launch=await plugin.getNotificationAppLaunchDetails();
    if(launch?.didNotificationLaunchApp??false)pendingAction=launch?.notificationResponse;
    initialized=true;
  }
  Future<bool> requestPermission() async {
    await initialize();
    if(Platform.isIOS)return await plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert:true,badge:false,sound:true)??false;
    final android=plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final allowed=await android?.requestNotificationsPermission()??false;
    final exact=await android?.requestExactAlarmsPermission()??false;
    return allowed&&exact;
  }
  Future<void> cancel() async {await _queue;await initialize();await plugin.cancelAll();through=null;count=0;notifyListeners();}
  NotificationDetails details({bool actions=true}) => NotificationDetails(
    android:AndroidNotificationDetails('dosebuddy_private_v2','Medication reminders',channelDescription:'Reminders you scheduled in DoseBuddy',importance:Importance.high,priority:Priority.high,icon:'@drawable/ic_notification',visibility:NotificationVisibility.private,actions:actions?const [AndroidNotificationAction('record','Record dose',showsUserInterface:true),AndroidNotificationAction('snooze','Remind in 10 min',showsUserInterface:true)]:null),
    iOS:const DarwinNotificationDetails(presentAlert:true,presentSound:true),
  );
  Future<void> _queue=Future<void>.value();
  Future<void> sync(Records r) {
    final next=_queue.then((_)=>_sync(r));
    _queue=next.catchError((Object _){});
    return next;
  }
  Future<void> _sync(Records r) async {
    syncing=true;error=null;
    try {
      await initialize();
      await plugin.cancelAll();count=0;through=null;
      if(r.settings['reminders']!=true)return;
      zone=await FlutterTimezone.getLocalTimezone();tz.setLocalLocation(tz.getLocation(zone!));
      final now=DateTime.now();final plan=ReminderPlan.create(r,now);
      var id=1000;
      for(final dose in plan.doses){
        final minute=int.parse(dose.key.split('/').last);
        final local=tz.TZDateTime(tz.local,dose.at.year,dose.at.month,dose.at.day,minute~/60,minute%60);
        // A DST gap must not silently shift a prescribed clock time.
        if(local.hour!=minute~/60 || local.minute!=minute%60)throw StateError('A time does not exist after a daylight-saving change. Review your schedule.');
        final private=r.settings['privateNotifications']!=false;
        await plugin.zonedSchedule(id++,private?'DoseBuddy reminder':dose.details['name'] as String,'Open DoseBuddy to review your scheduled record.',local,details(),androidScheduleMode:AndroidScheduleMode.exactAllowWhileIdle,uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime,payload:dose.key);
        count++;
      }
      through=plan.through;
      final renew=plan.through.subtract(const Duration(hours:1));
      if(renew.isAfter(now))await plugin.zonedSchedule(900001,'Refresh DoseBuddy reminders','Open the app to schedule the next set of reminders.',tz.TZDateTime.from(renew,tz.local),details(actions:false),androidScheduleMode:AndroidScheduleMode.exactAllowWhileIdle,uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime);
    } catch(e) {error='Records are saved, but reminders could not be fully scheduled. Check notification and exact-alarm permissions, then retry.';through=null;}
    finally {syncing=false;notifyListeners();}
  }
  Future<void> snooze(String key) async {
    await initialize();zone=await FlutterTimezone.getLocalTimezone();tz.setLocalLocation(tz.getLocation(zone!));
    await plugin.zonedSchedule(900002,'DoseBuddy reminder','Open DoseBuddy to review your dose record.',tz.TZDateTime.now(tz.local).add(const Duration(minutes:10)),details(),androidScheduleMode:AndroidScheduleMode.exactAllowWhileIdle,uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime,payload:key);
  }
  Future<void> test() async {
    await initialize();
    await plugin.show(900003,'DoseBuddy test','This is a one-time test notification.',details(actions:false));
  }
}
