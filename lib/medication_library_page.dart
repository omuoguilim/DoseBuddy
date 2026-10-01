import 'package:flutter/foundation.dart';
import 'widgets/platform_photo.dart';
import 'demo/demo_mode.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/medication.dart';
import 'detailpage.dart';
import 'medication_options_page.dart';
import 'add_medication_page.dart';
import 'widgets/dosebuddy_theme.dart';

class MedicationLibraryPage extends StatefulWidget {
  const MedicationLibraryPage({super.key});
  @override
  State<MedicationLibraryPage> createState()=>_MedicationLibraryPageState();
}
class _MedicationLibraryPageState extends State<MedicationLibraryPage> {
  String _query='',_filter='Active';
  bool _draft=false,_busy=false;
  @override
  void initState(){super.initState();_loadDraft();}
  Future<void> _loadDraft()async{final p=await SharedPreferences.getInstance();if(mounted)setState(()=>_draft=p.containsKey('medication_draft'));}
  Future<void> _open(Widget page)async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>page));if(mounted){await _loadDraft();setState((){});}}
  void _message(String value){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(value)));}
  Future<void> _photo(Medication med)async{
    if(_busy)return;setState(()=>_busy=true);
    try{final image=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1600);if(image==null)return;
      if(kIsWeb){med.details??={};med.details!['photoPath']=await durablePhotoPath(image);await med.save();_message('Packaging photo saved in this browser');return;}
      final dir=await getApplicationDocumentsDirectory();final folder=Directory('${dir.path}/medication_photos');await folder.create(recursive:true);
      final path='${folder.path}/${med.id}-${DateTime.now().millisecondsSinceEpoch}.jpg';await File(image.path).copy(path);
      med.details??={};final previous=med.details!['photoPath'] as String?;med.details!['photoPath']=path;await med.save();
      if(previous!=null&&previous.startsWith('${folder.path}/')&&await File(previous).exists())await File(previous).delete();
      _message('Packaging photo saved');
    }catch(_){_message('Could not save this photo. Your medication is unchanged.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _call(String number)async{try{final clean=number.replaceAll(RegExp(r'[^0-9+]'),'');if(clean.isEmpty)return;final ok=await launchUrl(Uri(scheme:'tel',path:clean));if(!ok)_message('Calling is unavailable on this device.');}catch(_){_message('Could not open the phone app.');}}
  Future<void> _prn(Medication med)async{
    if(_busy)return;
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Record an as-needed dose?'),content:Text('Record ${med.name} as taken now. This records what happened; it does not recommend a dose.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Record taken'))]));
    if(ok!=true||!mounted)return;setState(()=>_busy=true);
    try{final now=DateTime.now(),key='PRN ${DateTime.now().toIso8601String()}';med.recordDose(now,key,'taken');await med.save();if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:const Text('As-needed dose recorded'),action:SnackBarAction(label:'Undo',onPressed:()async{med.recordDose(now,key,'unknown',reason:'Undid as-needed entry');await med.save();})));}catch(_){_message('Could not save this dose.');}finally{if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Medications'),actions:[IconButton(tooltip:'Add medication',onPressed:()=>_open(const AddMedicationPage()),icon:const Icon(Icons.add_circle_outline))]),body:Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(20,8,20,12),child:TextField(decoration:const InputDecoration(hintText:'Search medications or pharmacy',prefixIcon:Icon(Icons.search)),onChanged:(v)=>setState(()=>_query=v.toLowerCase()))),
    SingleChildScrollView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:20),child:Row(children:['Active','As needed','Archived','Paused','All','Prescription','Over the counter','Supplement'].map((v)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(v),selected:_filter==v,onSelected:(_)=>setState(()=>_filter=v)))).toList())),
    Expanded(child:ValueListenableBuilder<Box<Medication>>(valueListenable:Hive.box<Medication>(DemoMode.boxName).listenable(),builder:(context,box,_) {
      final meds=box.values.where((m){final d=m.details??{},s=m.scheduleFor(DateTime.now());final text='${m.name} ${d['pharmacy']??''}'.toLowerCase();if(!text.contains(_query))return false;return _filter=='All'||(_filter=='Active'&&s['archived']!=true&&s['paused']!=true)||(_filter=='Paused'&&s['paused']==true)||(_filter=='Archived'&&s['archived']==true)||(_filter=='As needed'&&s['asNeeded']==true)||d['kind']==_filter;}).toList();
      return ListView(padding:const EdgeInsets.all(20),children:[
        if(meds.isEmpty)Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(box.isEmpty?'Your medications will appear here':'No matching medications',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:8),Text(box.isEmpty?'Scan a label or enter the details manually.':'Try another search or filter. Upcoming schedule changes start tomorrow.')]))),
        for(final m in meds)Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          InkWell(borderRadius:BorderRadius.circular(12),onTap:()=>_open(DetailPage(medication:m)),child:Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[const MedicationGlyph(),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(m.name,style:Theme.of(context).textTheme.titleMedium),Text('Strength: ${m.dosage}',style:Theme.of(context).textTheme.bodyMedium),Text(m.scheduleFor(DateTime.now())['asNeeded']==true?'As needed':m.timesFor(DateTime.now()).join(', '),style:Theme.of(context).textTheme.bodySmall),if(m.pillsRemaining!=null)Text('Pills per dose: ${m.pillsPerDose}',style:Theme.of(context).textTheme.bodySmall)])),const Icon(Icons.chevron_right,color:DoseBuddyTheme.muted)]))),
          if(m.details?['photoPath']!=null&&(kIsWeb||File(m.details!['photoPath'] as String).existsSync()))...[const SizedBox(height:8),Center(child:platformPhoto(m.details!['photoPath'] as String,height:120,fit:BoxFit.contain)),const Text('Reference photo; not verified pill identification.',style:TextStyle(fontSize:12,color:DoseBuddyTheme.muted))],
          const Divider(height:24),
          ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.storefront_outlined,size:22),title:Text((m.details?['pharmacy'] as String? ?? '').isEmpty?'Pharmacy / prescriber contacts':m.details!['pharmacy'] as String),trailing:const Icon(Icons.chevron_right),onTap:()=>_open(MedicationOptionsPage(medication:m))),
          if(m.pillsRemaining!=null)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.inventory_2_outlined,size:22),title:Text('Refill record · ${m.pillsRemaining} remaining'),trailing:const Icon(Icons.chevron_right),onTap:()=>_open(DetailPage(medication:m))),
          Wrap(spacing:8,children:[TextButton(onPressed:_busy?null:()=>_photo(m),child:const Text('Packaging photo')),TextButton(onPressed:()=>_open(MedicationOptionsPage(medication:m)),child:const Text('Schedule / archive')),if((m.details?['pharmacyPhone'] as String? ?? '').isNotEmpty)TextButton(onPressed:()=>_call(m.details!['pharmacyPhone'] as String),child:const Text('Call pharmacy')),if((m.details?['prescriberPhone'] as String? ?? '').isNotEmpty)TextButton(onPressed:()=>_call(m.details!['prescriberPhone'] as String),child:const Text('Call prescriber')),if(m.scheduleFor(DateTime.now())['asNeeded']==true)OutlinedButton(onPressed:_busy?null:()=>_prn(m),child:const Text('Record as-needed dose'))]),
        ]))),
        if(_draft)Card(color:DoseBuddyTheme.tint,child:ListTile(leading:const Icon(Icons.description_outlined,color:DoseBuddyTheme.purple),title:const Text('Draft saved'),subtitle:const Text('Continue adding medication'),onTap:()=>_open(const AddMedicationPage()),trailing:IconButton(tooltip:'Discard draft',icon:const Icon(Icons.close),onPressed:()async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Discard this draft?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Keep draft')),TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Discard'))]));if(ok==true){final p=await SharedPreferences.getInstance();await p.remove('medication_draft');await _loadDraft();}}))),
        const SizedBox(height:14),ElevatedButton.icon(onPressed:()=>_open(const AddMedicationPage()),icon:const Icon(Icons.add),label:Text(_draft?'Continue / add medication':'Add medication')),const SizedBox(height:10),Wrap(spacing:10,runSpacing:8,children:[OutlinedButton.icon(onPressed:()=>_open(const AddMedicationPage(scanOnOpen:true)),icon:const Icon(Icons.document_scanner_outlined),label:const Text('Scan label')),OutlinedButton.icon(onPressed:()=>_open(const AddMedicationPage()),icon:const Icon(Icons.edit_outlined),label:const Text('Enter manually'))]),const SizedBox(height:20),
      ]);
    })),
  ]));
}
