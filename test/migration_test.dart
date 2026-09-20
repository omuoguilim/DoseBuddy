import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dosebuddy/core/store.dart';
import 'package:dosebuddy/core/records.dart';
import 'package:dosebuddy/models/medication.dart';
import 'package:dosebuddy/models/dose_event.dart';
import 'package:dosebuddy/models/symptom_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('migration merges dose stores, preserves notes and retains source boxes', () async {
    final directory = await Directory.systemTemp.createTemp('dosebuddy-migration-');
    Hive.init(directory.path);
    Hive.registerAdapter(MedicationAdapter());
    Hive.registerAdapter(DoseEventAdapter());
    Hive.registerAdapter(SymptomEventAdapter());
    addTearDown(() async { await Hive.close(); await directory.delete(recursive:true); });
    SharedPreferences.setMockInitialValues({'emergency_allergies':'Example allergy'});
    final date=DateTime(2026,9,1,8);
    final meds=await Hive.openBox<Medication>('medications');
    await meds.put('m',Medication(id:'m',name:'Example',dosage:'10 mg',times:['8:00 AM'],pillsRemaining:12,takenLog:[{'date':'2026-09-01','scheduledTime':'8:00 AM','takenAt':date.toIso8601String()}],sideEffects:[{'name':'Legacy note','date':date}]));
    await meds.close();
    final doses=await Hive.openBox<DoseEvent>('dose_events');
    await doses.put('d',DoseEvent(id:'d',medicationId:'m',scheduledAt:date,takenAt:date,status:'late',notes:'Original note'));
    await doses.put('u',DoseEvent(id:'u',medicationId:'m',scheduledAt:date.add(const Duration(days:1)),status:'missed',notes:'Preserve this too'));
    await doses.close();
    final symptoms=await Hive.openBox<SymptomEvent>('symptom_events');
    await symptoms.put('s',SymptomEvent(id:'s',name:'Headache',severity:2,occurredAt:date));
    await symptoms.close();
    final data=await AppStore.importLegacy();
    final r=Records(data);
    expect(r.outcomes.length,1);
    expect(r.outcomes.values.single['reason'],'Original note');
    expect(r.medications['m']['supply'],12);
    expect(data['symptoms']['s']['name'],'Headache');
    expect(data['emergency']['allergies'],'Example allergy');
    expect((data['audit'] as List).any((a)=>a['notes']=='Preserve this too'),true);
    expect(await Hive.boxExists('medications'),true);
    expect(await Hive.boxExists('dose_events'),true);
    final again=await AppStore.importLegacy();
    expect((again['outcomes'] as Map).length,1);
  });
}
