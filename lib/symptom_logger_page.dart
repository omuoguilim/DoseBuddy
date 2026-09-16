import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'models/medication.dart';
import 'models/symptom_event.dart';

class SymptomLoggerPage extends StatefulWidget {
  const SymptomLoggerPage({super.key});
  @override State<SymptomLoggerPage> createState()=>_SymptomLoggerPageState();
}
class _SymptomLoggerPageState extends State<SymptomLoggerPage>{
  final notes=TextEditingController();
  String symptom='Nausea'; int severity=3; int? duration=30; String? medicationId;
  final symptoms=['Nausea','Headache','Dizziness','Fatigue','Stomach pain','Insomnia','Rash','Other'];
  @override void dispose(){notes.dispose();super.dispose();}
  Future<void> save() async {
    final event=SymptomEvent(id:const Uuid().v4(),name:symptom,severity:severity,occurredAt:DateTime.now(),medicationId:medicationId,durationMinutes:duration,notes:notes.text.trim().isEmpty?null:notes.text.trim());
    await Hive.box<SymptomEvent>('symptom_events').put(event.id,event);
    if(mounted) Navigator.pop(context,true);
  }
  @override Widget build(BuildContext context){
    final meds=Hive.box<Medication>('medications').values.where((m)=>!m.isCompleted).toList();
    return Scaffold(backgroundColor:const Color(0xFFF6F7FB),appBar:AppBar(backgroundColor:const Color(0xFFF6F7FB),foregroundColor:const Color(0xFF191C2B),elevation:0,title:const Text('Log a symptom',style:TextStyle(fontWeight:FontWeight.w800))),body:ListView(padding:const EdgeInsets.all(20),children:[
      const Text('What are you feeling?',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:symptoms.map((s)=>ChoiceChip(label:Text(s),selected:symptom==s,onSelected:(_)=>setState(()=>symptom=s))).toList()),
      const SizedBox(height:28),Row(children:[const Expanded(child:Text('Severity',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800))),Text('$severity/5',style:const TextStyle(color:Color(0xFF5965D8),fontWeight:FontWeight.w800))]),
      Slider(value:severity.toDouble(),min:1,max:5,divisions:4,label:'$severity',onChanged:(v)=>setState(()=>severity=v.round())),
      const SizedBox(height:18),const Text('How long did it last?',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:10),
      Wrap(spacing:8,children:[15,30,60,120].map((m)=>ChoiceChip(label:Text(m<60?'$m min':'${m~/60} hr'),selected:duration==m,onSelected:(_)=>setState(()=>duration=m))).toList()),
      const SizedBox(height:28),const Text('Medication context',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:6),const Text('Optional. Choose a medication only if you think it may be relevant.',style:TextStyle(color:Color(0xFF7B8194))),const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:[ChoiceChip(label:const Text('Not sure'),selected:medicationId==null,onSelected:(_)=>setState(()=>medicationId=null)),...meds.map((m)=>ChoiceChip(label:Text(m.name),selected:medicationId==m.id,onSelected:(_)=>setState(()=>medicationId=m.id)))]),
      const SizedBox(height:24),TextField(controller:notes,maxLines:3,decoration:InputDecoration(labelText:'Notes (optional)',hintText:'Anything else you noticed?',filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none))),
      const SizedBox(height:28),FilledButton(onPressed:save,child:const Text('Save symptom')),
      const SizedBox(height:12),const Text('DoseBuddy records what you report and may highlight timing patterns. It does not determine whether a medication caused a symptom.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:Color(0xFF8D93A6),height:1.4)),
    ]));
  }
}
