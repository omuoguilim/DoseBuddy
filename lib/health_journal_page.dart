import 'demo/demo_mode.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/medication.dart';

class HealthJournalPage extends StatefulWidget {
  const HealthJournalPage({super.key});
  @override
  State<HealthJournalPage> createState()=>_HealthJournalPageState();
}
class _HealthJournalPageState extends State<HealthJournalPage> {
  List<Map<String,dynamic>> _measurements=[];
  List<String> _exports=[];
  final _notes=TextEditingController();
  @override
  void initState(){super.initState();_load();}
  Future<void> _load()async{
    final p=await SharedPreferences.getInstance();
    if(!mounted)return;
    setState((){_measurements=(p.getStringList('health_measurements')??[]).map((v)=>Map<String,dynamic>.from(jsonDecode(v) as Map)).toList();_exports=p.getStringList('report_exports')??[];_notes.text=p.getString('appointment_notes')??'';});
  }
  Future<void> _add()async{
    final value=TextEditingController(),note=TextEditingController();
    String type='Weight (kg)';
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,update)=>AlertDialog(title:const Text('Record a measurement'),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:type,items:['Weight (kg)','Temperature (°C)','Pulse (bpm)','Blood pressure (mmHg)','Blood glucose (mg/dL)'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>update(()=>type=v!)),TextField(controller:value,decoration:const InputDecoration(labelText:'Value (e.g. 120/80 for blood pressure)')),TextField(controller:note,decoration:const InputDecoration(labelText:'Context / note'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save'))])));
    if(ok==true){
      final text=value.text.trim();
      final valid=type.startsWith('Blood pressure')?RegExp(r'^\d{2,3}/\d{2,3}$').hasMatch(text):(double.tryParse(text)!=null&&double.parse(text)>0&&double.parse(text).isFinite);
      if(!valid){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a positive number, or systolic/diastolic for blood pressure.')));}
      else{_measurements.add({'type':type,'value':text,'note':note.text.trim(),'at':DateTime.now().toIso8601String()});final p=await SharedPreferences.getInstance();await p.setStringList('health_measurements',_measurements.map(jsonEncode).toList());if(mounted)setState((){});}
    }
    value.dispose();note.dispose();
  }
  @override
  Widget build(BuildContext context){
    final symptoms=<Map<String,dynamic>>[],barriers=<String,int>{};
    for(final m in Hive.box<Medication>(DemoMode.boxName).values){for(final s in m.sideEffects??<Map<String,dynamic>>[]){symptoms.add({...s,'medication':m.name});}for(final l in m.takenLog??<Map<String,dynamic>>[]){if(['missed','skipped'].contains(l['state'])){final reason=(l['reason'] as String? ?? '').trim();final label=reason.isEmpty?'No reason recorded':reason;barriers[label]=(barriers[label]??0)+1;}}}
    symptoms.sort((a,b)=>(b['timestamp'] as String? ?? '').compareTo(a['timestamp'] as String? ?? ''));
    return Scaffold(appBar:AppBar(title:const Text('Health journal')),body:ListView(padding:const EdgeInsets.all(20),children:[
      const Text('Your entries are personal records. DoseBuddy does not interpret measurements or diagnose symptoms.'),
      const SizedBox(height:16),TextField(controller:_notes,maxLines:4,decoration:const InputDecoration(labelText:'Questions for your next appointment')),
      TextButton(onPressed:()async{final p=await SharedPreferences.getInstance();await p.setString('appointment_notes',_notes.text.trim());if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Appointment notes saved.')));},child:const Text('Save appointment notes')),
      const Divider(),const Text('Measurements',style:TextStyle(fontWeight:FontWeight.bold)),TextButton(onPressed:_add,child:const Text('Add measurement')),
      for(final v in _measurements.reversed)ListTile(title:Text('${v['type']}: ${v['value']}'),subtitle:Text('${v['at']} · ${v['note']}')),
      const Divider(),const Text('Symptom timeline',style:TextStyle(fontWeight:FontWeight.bold)),
      for(final s in symptoms)ListTile(title:Text((s['effects'] as List? ?? []).join(', ')),subtitle:Text('${s['timestamp']} · ${s['medication']} · ${s['severity']??''}\n${s['notes']??''}\nOnset: ${s['onset']??'Not recorded'} · duration: ${s['durationMinutes']??'Not recorded'} minutes')),
      const Divider(),const Text('Reasons recorded for missed / skipped doses',style:TextStyle(fontWeight:FontWeight.bold)),
      for(final e in barriers.entries)ListTile(title:Text(e.key),trailing:Text('${e.value}')),
      const Divider(),const Text('Report share history',style:TextStyle(fontWeight:FontWeight.bold)),const Text('A share action does not confirm that a doctor received the report.'),for(final stamp in _exports.reversed)ListTile(title:Text(stamp)),
    ]));
  }
  @override
  void dispose(){_notes.dispose();super.dispose();}
}
