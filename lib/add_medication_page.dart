import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'models/medication.dart';
import 'services/notification_services.dart';

class AddMedicationPage extends StatefulWidget {
  final Map<String, String>? initialValues;
  const AddMedicationPage({super.key, this.initialValues});
  @override State<AddMedicationPage> createState()=>_AddMedicationPageState();
}
class _AddMedicationPageState extends State<AddMedicationPage> {
  final name=TextEditingController(), strength=TextEditingController(), reason=TextEditingController(), instructions=TextEditingController(), notes=TextEditingController(), supply=TextEditingController(), threshold=TextEditingController(), prescriber=TextEditingController(), pharmacy=TextEditingController();
  final times=<String>[]; String form='Tablet', type='scheduled', food='No preference'; int units=1; bool trackSupply=false, temporary=false; DateTime start=DateTime.now(); DateTime? end;
  static const purple=Color(0xFF5B67CA);
  @override
  void initState(){
    super.initState();
    final v=widget.initialValues;
    if(v==null)return;
    name.text=v['name']??'';
    strength.text=v['strength']??'';
    instructions.text=v['instructions']??'';
    supply.text=v['quantity']??'';
    prescriber.text=v['prescriber']??'';
    pharmacy.text=v['pharmacy']??'';
    notes.text=v['scanNotes']??'';
    if(supply.text.isNotEmpty) trackSupply=true;
  }
  @override void dispose(){ for(final c in [name,strength,reason,instructions,notes,supply,threshold,prescriber,pharmacy]){c.dispose();} super.dispose(); }
  String fmt(TimeOfDay t){final h=t.hourOfPeriod==0?12:t.hourOfPeriod; return '$h:${t.minute.toString().padLeft(2,'0')} ${t.period==DayPeriod.am?'AM':'PM'}';}
  Future<void> addTime() async {final t=await showTimePicker(context:context,initialTime:TimeOfDay.now()); if(t!=null){final v=fmt(t); if(!times.contains(v))setState(()=>times.add(v));}}
  Future<void> pickDate(bool isEnd) async {final d=await showDatePicker(context:context,firstDate:DateTime.now().subtract(const Duration(days:365)),lastDate:DateTime.now().add(const Duration(days:3650)),initialDate:isEnd?(end??DateTime.now().add(const Duration(days:7))):start); if(d!=null)setState((){if(isEnd)end=d;else start=d;});}
  String date(DateTime? d)=>d==null?'Not set':'${d.month}/${d.day}/${d.year}';
  Future<void> save() async {
    if(name.text.trim().isEmpty||strength.text.trim().isEmpty||(type=='scheduled'&&times.isEmpty)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Add a name, strength, and at least one time for scheduled medication.')));return;}
    final count=trackSupply?int.tryParse(supply.text):null; final med=Medication(id:DateTime.now().millisecondsSinceEpoch.toString(),name:name.text.trim(),dosage:strength.text.trim(),times:type=='scheduled'?times:[],notes:notes.text.trim(),totalPills:count,pillsRemaining:count,refillThreshold:trackSupply?(int.tryParse(threshold.text)??((count??0)*.25).round()):null,lastRefillDate:count!=null?DateTime.now():null,pillsPerDose:units,dosageForm:form,medicationType:type,reason:reason.text.trim(),instructions:instructions.text.trim(),foodInstruction:food,startDate:start,endDate:temporary?end:null,prescriber:prescriber.text.trim(),pharmacy:pharmacy.text.trim());
    await Hive.box<Medication>('medications').put(med.id,med); if(type=='scheduled')await NotificationService().scheduleMedicationNotifications(med); if(mounted)Navigator.pop(context,true);
  }
  Widget section(String title,List<Widget> children)=>Padding(padding:const EdgeInsets.only(bottom:26),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:14),...children]));
  InputDecoration deco(String hint,{IconData? icon})=>InputDecoration(hintText:hint,prefixIcon:icon==null?null:Icon(icon),filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide(color:Colors.grey.shade200)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide(color:Colors.grey.shade200)),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:purple,width:2)));
  Widget field(TextEditingController c,String hint,{IconData? icon,TextInputType? keyboard,int lines=1})=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:c,keyboardType:keyboard,maxLines:lines,decoration:deco(hint,icon:icon)));
  Widget choiceField({required String label,required String value,required List<String> options,required ValueChanged<String> onChanged})=>InkWell(borderRadius:BorderRadius.circular(16),onTap:() async {final selected=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[Padding(padding:const EdgeInsets.fromLTRB(20,4,20,12),child:Align(alignment:Alignment.centerLeft,child:Text(label,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)))),...options.map((option)=>ListTile(title:Text(option),trailing:option==value?const Icon(Icons.check,color:purple):null,onTap:()=>Navigator.pop(ctx,option))),const SizedBox(height:8)])));if(selected!=null)onChanged(selected);},child:InputDecorator(decoration:deco(label),child:Row(children:[Expanded(child:Text(value)),const Icon(Icons.keyboard_arrow_down_rounded)])));
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F8FC),appBar:AppBar(backgroundColor:const Color(0xFFF7F8FC),surfaceTintColor:Colors.transparent,title:const Text('Add medication',style:TextStyle(fontWeight:FontWeight.w800)),actions:[TextButton(onPressed:save,child:const Text('Save',style:TextStyle(fontWeight:FontWeight.w800))) ]),body:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(20,12,20,40),child:Column(children:[
    section('Medication',[field(name,'Medication name',icon:Icons.medication_outlined),field(strength,'Strength, e.g. 500 mg'),choiceField(label:'Dosage form',value:form,options:const ['Tablet','Capsule','Liquid','Injection','Inhaler','Patch','Cream','Drops','Other'],onChanged:(v)=>setState(()=>form=v)),const SizedBox(height:12),field(reason,'What do you take it for? (optional)')]),
    section('How do you take it?',[SegmentedButton<String>(segments:const [ButtonSegment(value:'scheduled',label:Text('Scheduled'),icon:Icon(Icons.schedule)),ButtonSegment(value:'as_needed',label:Text('As needed'),icon:Icon(Icons.bolt_outlined))],selected:{type},onSelectionChanged:(s)=>setState(()=>type=s.first)),const SizedBox(height:14),if(type=='scheduled')...[Wrap(spacing:8,runSpacing:8,children:[...times.map((t)=>InputChip(label:Text(t),onDeleted:()=>setState(()=>times.remove(t)))),ActionChip(avatar:const Icon(Icons.add,size:18),label:const Text('Add time'),onPressed:addTime)]),const SizedBox(height:12)],Row(children:[const Text('Units per dose',style:TextStyle(fontWeight:FontWeight.w600)),const Spacer(),IconButton(onPressed:units>1?()=>setState(()=>units--):null,icon:const Icon(Icons.remove_circle_outline)),Text('$units',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),IconButton(onPressed:()=>setState(()=>units++),icon:const Icon(Icons.add_circle_outline))]),const SizedBox(height:8),choiceField(label:'Food instructions',value:food,options:const ['No preference','With food','Without food','Before food','After food'],onChanged:(v)=>setState(()=>food=v)),const SizedBox(height:12),field(instructions,'Additional directions, e.g. take with a full glass of water',lines:2)]),
    section('Course',[ListTile(contentPadding:EdgeInsets.zero,title:const Text('Start date'),subtitle:Text(date(start)),trailing:const Icon(Icons.chevron_right),onTap:()=>pickDate(false)),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Temporary course'),subtitle:const Text('Set an end date for antibiotics or short-term medications'),value:temporary,onChanged:(v)=>setState(()=>temporary=v)),if(temporary)ListTile(contentPadding:EdgeInsets.zero,title:const Text('End date'),subtitle:Text(date(end)),trailing:const Icon(Icons.chevron_right),onTap:()=>pickDate(true))]),
    section('Supply & refills',[SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Track supply'),subtitle:const Text('Forecast when you may run low'),value:trackSupply,onChanged:(v)=>setState(()=>trackSupply=v)),if(trackSupply)...[field(supply,'Current quantity',keyboard:TextInputType.number),field(threshold,'Remind me when this many remain',keyboard:TextInputType.number)]]),
    section('Care details',[field(prescriber,'Prescriber (optional)',icon:Icons.medical_services_outlined),field(pharmacy,'Pharmacy (optional)',icon:Icons.local_pharmacy_outlined),field(notes,'Private notes (optional)',lines:3)]),
    SizedBox(width:double.infinity,height:56,child:FilledButton(style:FilledButton.styleFrom(backgroundColor:purple,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),onPressed:save,child:const Text('Add to DoseBuddy',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800))))
  ])));
}
