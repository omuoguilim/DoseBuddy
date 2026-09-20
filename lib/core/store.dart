import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication.dart';
import '../models/dose_event.dart';
import '../models/symptom_event.dart';
import 'records.dart';

class AppStore extends ChangeNotifier {
  final Future<void> Function(Json) persist;
  Json _data;
  bool busy=false;
  AppStore(this._data,this.persist);
  Json get data => copyJson(_data);
  Records get records => Records(data);
  Future<void> update(void Function(Records) change) async {
    if(busy)throw StateError('A save is already in progress. Please wait.');
    busy=true;notifyListeners();
    try {final next=copyJson(_data);change(Records(next));await persist(next);_data=next;}
    finally {busy=false;notifyListeners();}
  }
  Future<void> erase() => update((r){r.data.clear();r.data.addAll(Records.empty());});

  static Future<AppStore> open() async {
    await Hive.initFlutter();
    const secure=FlutterSecureStorage(iOptions:IOSOptions(accessibility:KeychainAccessibility.unlocked_this_device),aOptions:AndroidOptions(encryptedSharedPreferences:true));
    var key=await secure.read(key:'dosebuddy.v2.key');
    if(key==null){
      if(await Hive.boxExists('dosebuddy_v2'))throw StateError('The local encryption key is missing. Existing data was not overwritten.');
      key=base64Encode(Hive.generateSecureKey());await secure.write(key:'dosebuddy.v2.key',value:key);
    }
    final box=await Hive.openBox<String>('dosebuddy_v2',encryptionCipher:HiveAesCipher(base64Decode(key)));
    if(!box.containsKey('state')){
      final initial=await importLegacy();
      await box.put('state',jsonEncode(initial));await box.flush();
      if(jsonEncode(jsonDecode(box.get('state')!))!=jsonEncode(initial))throw StateError('Import verification failed. Original data was retained.');
    }
    final decoded=jsonDecode(box.get('state')!) as Json;
    if(decoded['schema']!=2)throw StateError('Unsupported data version. No records were changed.');
    // Retry cleanup after interrupted migration, only after verified commit.
    for(final name in ['medications','dose_events','symptom_events']){
      if(await Hive.boxExists(name))await Hive.deleteBoxFromDisk(name);
    }
    final prefs=await SharedPreferences.getInstance();
    final oldImage=prefs.getString('profile_image');
    if(oldImage!=null){
      final roots=[await getTemporaryDirectory(),await getApplicationDocumentsDirectory(),await getApplicationSupportDirectory()];
      if(roots.any((d)=>oldImage.startsWith('${d.path}/'))){final file=File(oldImage);if(await file.exists())await file.delete();}
    }
    for(final k in prefs.getKeys().toList()){await prefs.remove(k);}
    return AppStore(decoded,(next)async{await box.put('state',jsonEncode(next));await box.flush();await box.compact();});
  }

  @visibleForTesting
  static Future<Json> importLegacy() async {
    final data=Records.empty();final r=Records(data);final now=DateTime.now();
    if(!Hive.isAdapterRegistered(0))Hive.registerAdapter(MedicationAdapter());
    if(!Hive.isAdapterRegistered(1))Hive.registerAdapter(DoseEventAdapter());
    if(!Hive.isAdapterRegistered(2))Hive.registerAdapter(SymptomEventAdapter());
    if(await Hive.boxExists('medications')){
      final box=await Hive.openBox<Medication>('medications');
      for(final m in box.values){
        final fields=<String,dynamic>{'name':m.name,'strength':m.dosage,'amount':m.pillsPerDose,'unit':m.dosageForm.toLowerCase()=='tablet'?'tablet':m.dosageForm.toLowerCase()=='capsule'?'capsule':'unit (verify)','form':m.dosageForm,'type':m.medicationType,'times':m.times.map(parseClock).toList(),'start':dayKey(m.startDate??m.createdAt),'end':m.endDate==null?null:dayKey(m.endDate!),'active':m.lifecycleStatus=='active','instructions':m.instructions,'food':m.foodInstruction,'notes':m.notes,'reason':m.reason,'prescriber':m.prescriber,'pharmacy':m.pharmacy,'effectiveFrom':now.toIso8601String(),'effectiveUntil':null};
        r.medications[m.id]={'id':m.id,'versions':[fields],'supply':m.pillsRemaining,'threshold':m.refillThreshold};
        for(final log in m.takenLog??<Map<String,dynamic>>[]){
          final date=DateTime.parse(log['date'] as String);final minute=parseClock(log['scheduledTime'] as String);
          final d=ScheduledDose(doseKey(m.id,date,minute),m.id,DateTime(date.year,date.month,date.day,minute~/60,minute%60),fields);
          r.outcomes[d.key]={'dose':d.snapshot(),'status':'Taken','takenAt':log['takenAt'],'recordedAt':log['takenAt']??date.toIso8601String(),'amount':m.pillsPerDose,'reason':'Imported record; original schedule version unavailable.','prn':false,'inventoryDeduction':0};
        }
        if(m.sideEffects?.isNotEmpty??false)(data['audit'] as List).add({'action':'legacy side effects imported','medicationId':m.id,'records':m.sideEffects});
      }
      await box.close();
      (data['migrationNotes'] as List).add('Old schedule versions were not stored. Recorded doses are preserved, but unrecorded scheduled totals before ${dayKey(now)} cannot be reconstructed reliably. Imported supply counts were preserved.');
    }
    if(await Hive.boxExists('dose_events')){
      final box=await Hive.openBox<DoseEvent>('dose_events');
      for(final e in box.values){
        final med=r.medications[e.medicationId] as Json?;
        final f=med==null?<String,dynamic>{'name':'Medication no longer listed','strength':'Unknown','amount':e.amount,'unit':'unit (verify)'}:r.current(med);
        final prn=e.id.startsWith('prn_');final key=prn?e.id:doseKey(e.medicationId,e.scheduledAt,e.scheduledAt.hour*60+e.scheduledAt.minute);
        final d=ScheduledDose(key,e.medicationId,e.scheduledAt,f);
        if(['taken','late','skipped'].contains(e.status))r.outcomes[key]={'dose':d.snapshot(),'status':e.status=='skipped'?'Skipped':'Taken','takenAt':e.takenAt?.toIso8601String(),'recordedAt':(e.takenAt??e.scheduledAt).toIso8601String(),'amount':e.amount,'reason':e.reason??e.notes??'Imported record','prn':prn,'inventoryDeduction':0};
      }
      await box.close();
    }
    if(await Hive.boxExists('symptom_events')){
      final box=await Hive.openBox<SymptomEvent>('symptom_events');
      for(final s in box.values){(data['symptoms'] as Json)[s.id]={'id':s.id,'name':s.name,'severity':s.severity,'at':s.occurredAt.toIso8601String(),'duration':s.durationMinutes==null?'Unknown':'${s.durationMinutes} minutes','medicationId':s.medicationId,'notes':s.notes??''};}
      await box.close();
    }
    final prefs=await SharedPreferences.getInstance();
    data['emergency']={'allergies':prefs.getString('emergency_allergies')??'','contact':prefs.getString('emergency_contact')??'','notes':prefs.getString('emergency_notes')??''};
    final people=prefs.getString('care_circle');
    if(people!=null)(data['audit'] as List).add({'action':'legacy local care contacts preserved; no sharing active','contacts':jsonDecode(people)});
    return data;
  }
}
