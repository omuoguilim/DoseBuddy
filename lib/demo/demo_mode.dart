import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication.dart';

/// Compile-time isolated portfolio build. Never authenticates with Firebase.
class DemoMode {
  static const enabled = kIsWeb && bool.fromEnvironment('PORTFOLIO_DEMO');
  static const boxName = enabled ? 'dosebuddy_portfolio_medications_v1' : 'medications';
  static Future<void> seed({bool reset = false}) async {
    if (!enabled) return;
    final box = Hive.box<Medication>(boxName);
    final prefs = await SharedPreferences.getInstance();
    if (!reset && prefs.getBool('dosebuddy_demo_seeded_v1') == true) return;
    await box.clear();
    for (final key in ['profile_image','medication_draft','health_measurements','appointment_notes','report_exports']) {
      await prefs.remove(key);
    }
    await prefs.setString('user_name', 'Alex');
    await prefs.setString('user_first_name', 'Alex');
    await prefs.setString('user_last_name', 'Sample');
    await prefs.setString('user_email', 'alex@example.test');
    await prefs.setBool('reminders_enabled', false);
    await prefs.setString('reminder_timezone', 'America/New_York');
    final now = DateTime.now();
    final start = DateTime(now.year,now.month,now.day - 21);
    final meds = [
      Medication(id:'sample-morning',name:'Sample prescription',dosage:'10 mg',times:['8:00 AM'],createdAt:start,notes:'Fictional label for trying DoseBuddy. This is not medication advice.',totalPills:30,pillsRemaining:12,refillThreshold:7,details:{'kind':'Prescription','pharmacy':'Sample pharmacy','startDate':start.toIso8601String()}),
      Medication(id:'sample-evening',name:'Sample supplement',dosage:'500 mg',times:['8:00 PM'],createdAt:start,notes:'Fictional sample record.',totalPills:60,pillsRemaining:6,refillThreshold:7,details:{'kind':'Supplement','startDate':start.toIso8601String()}),
      Medication(id:'sample-prn',name:'Sample as-needed medication',dosage:'5 mL',times:[],createdAt:start,details:{'kind':'Over the counter','scheduleHistory':[{'effectiveAt':start.toIso8601String(),'asNeeded':true,'times':<String>[]}]}),
    ];
    for (final med in meds) {
      if (med.times.isNotEmpty) {
        for (int day=20;day>=1;day--) {
          final date=DateTime(now.year,now.month,now.day-day);
          if (day%7==0) continue; // Unrecorded remains distinct from missed.
          med.recordDose(date,med.times.first,day%9==0?'missed':day%11==0?'skipped':'taken',reason:day%9==0?'Forgot while out (sample)':day%11==0?'Sample explanation':'',actualTime:DateTime(date.year,date.month,date.day,med.id=='sample-morning'?8:20));
        }
      }
      if(med.id=='sample-morning')med.pillsRemaining=12;
      if(med.id=='sample-evening')med.pillsRemaining=6;
      await box.put(med.id,med);
    }
    meds.first.sideEffects=[{'timestamp':DateTime(now.year,now.month,now.day-2,10).toIso8601String(),'effects':['Headache'],'severity':'Mild','notes':'Fictional symptom note. Cause unknown.'}];
    await meds.first.save();
    await prefs.setBool('dosebuddy_demo_seeded_v1',true);
  }
}
