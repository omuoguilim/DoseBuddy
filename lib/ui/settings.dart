import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/records.dart';
import '../core/store.dart';
import '../core/reminders.dart';
import 'theme.dart';

const privacyText='''DoseBuddy privacy notice

DoseBuddy stores medication schedules, dose records, symptoms, emergency-card details, and preferences on this device. No account is required. This version has no analytics, advertising, caregiver-sharing, or cloud-sync service.

Records are stored in an encrypted local database. Its key is held by the platform secure-storage service. Optional app lock uses your device’s authentication. These measures do not protect information you choose to export or show on a notification.

Prescription images are processed on-device by the text-recognition SDK. The scan screen deletes its selected temporary image when closed where possible. Scans are drafts and must be checked against the original prescription.

Notification previews are private by default. If you turn private previews off, medication names may appear on the lock screen. Your operating system controls notification delivery and presentation.

Export requires an explicit action and shows a preview first. The complete JSON export includes correction history and imported legacy records. Exported files are not encrypted. Apps or people you share with receive a copy that DoseBuddy cannot revoke. The OS or receiving apps may retain shared files.

Delete all local data removes records, correction history, emergency details, local preferences, and scheduled DoseBuddy reminders. It cannot remove copies you previously exported. Android backup is disabled for this app; iOS excludes the app’s document storage from backup. Do not rely on device backup as a recovery mechanism. Keep a deliberate export if you need a copy.

You can review, correct, export, or delete your records in the app. Support: github.com/omuoguilim/DoseBuddy/issues. Do not post medication details or other private health information in a public issue.
''';
const termsText='''Using DoseBuddy

DoseBuddy is a personal record and reminder tool. Follow directions from your prescription and care team. DoseBuddy does not prescribe, calculate a safe dose, check drug interactions, diagnose symptoms, or monitor emergencies.

An unrecorded dose does not establish that you missed it. Logging a dose confirms only what you entered. Reports are user-entered records for discussion, not independently verified clinical records.

The scheduler queues up to 60 upcoming doses over at most 30 days. Open the app regularly to renew reminders and check the displayed coverage date. Permissions, device settings, operating-system behavior and timezone changes can affect delivery. Do not depend on DoseBuddy as your only reminder for critical medication.

Schedules use the device’s local clock. When traveling, open DoseBuddy to refresh reminders and review timing with a pharmacist or clinician when relevant. This version supports daily clock-time schedules and as-needed records; do not approximate other prescribed frequencies.

If you think you are experiencing a medical emergency, seek urgent assistance rather than relying on this app.
''';

class SettingsPage extends StatelessWidget {
  final AppStore store;final Reminders reminders;final Future<bool> Function() authenticate;
  const SettingsPage({super.key,required this.store,required this.reminders,required this.authenticate});
  Future<void> change(BuildContext context,String key,bool value)async{try{
    if(key=='reminders'&&value&&!await reminders.requestPermission())throw StateError('Notification or exact-alarm permission was not granted. Enable it in device settings and retry.');
    if(key=='appLock'&&!await authenticate())return;
    await store.update((r)=>r.settings[key]=value);if(key!='appLock')await reminders.sync(store.records);
  }catch(e){if(context.mounted)showError(context,e);}}
  void textPage(BuildContext context,String title,String text)=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>Scaffold(appBar:AppBar(title:Text(title)),body:SingleChildScrollView(padding:const EdgeInsets.all(20),child:SelectableText(text)))));
  @override Widget build(BuildContext context){final settings=store.records.settings;return ListView(padding:const EdgeInsets.all(20),children:[
    const Section('On this device',Text('Your records stay here. No account or subscription is needed.')),
    Section('Reminders',Column(children:[
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Medication reminders'),value:settings['reminders']==true,onChanged:store.busy||reminders.syncing?null:(v)=>change(context,'reminders',v)),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Private notification previews'),subtitle:const Text('Keep medication names off reminder messages.'),value:settings['privateNotifications']!=false,onChanged:store.busy||reminders.syncing?null:(v)=>change(context,'privateNotifications',v)),
      if(reminders.error!=null)Notice(reminders.error!),
      if(settings['reminders']==true)Text(reminders.through==null?'Scheduling has not been confirmed.':'${reminders.count} doses queued through ${dayKey(reminders.through!)} at ${clockLabel(reminders.through!.hour*60+reminders.through!.minute)}. Timezone: ${reminders.zone}.'),
      const Notice('Open DoseBuddy regularly to refresh reminders. Up to 60 doses are queued, at most 30 days ahead. Device permissions and settings can affect delivery.'),
      Wrap(spacing:12,runSpacing:12,children:[OutlinedButton(onPressed:reminders.syncing?null:()=>reminders.sync(store.records),child:Text(reminders.syncing?'Refreshing…':'Refresh reminders')),OutlinedButton(onPressed:settings['reminders']!=true?null:()async{try{await reminders.test();}catch(e){if(context.mounted)showError(context,e);}},child:const Text('Send one-time test'))]),
    ])),
    Section('Privacy',Column(children:[SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Lock with device authentication'),subtitle:const Text('Require Face ID, fingerprint or device passcode when returning to the app.'),value:settings['appLock']==true,onChanged:store.busy?null:(v)=>change(context,'appLock',v)),ListTile(contentPadding:EdgeInsets.zero,title:const Text('Privacy notice'),trailing:const Icon(Icons.chevron_right),onTap:()=>textPage(context,'Privacy notice',privacyText)),ListTile(contentPadding:EdgeInsets.zero,title:const Text('Using DoseBuddy'),trailing:const Icon(Icons.chevron_right),onTap:()=>textPage(context,'Using DoseBuddy',termsText))])),
    Section('Your records',Column(children:[ListTile(contentPadding:EdgeInsets.zero,title:const Text('Emergency information'),subtitle:const Text('Review or share a personal medication card.'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>EmergencyPage(store:store)))),ListTile(contentPadding:EdgeInsets.zero,title:const Text('Review and export records'),trailing:const Icon(Icons.ios_share),onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ExportPage(store:store)))),ListTile(contentPadding:EdgeInsets.zero,title:const Text('Delete all local data',style:TextStyle(color:Color(0xFFA22C29))),subtitle:const Text('Includes history, preferences and reminders.'),onTap:store.busy?null:()async{final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Delete all local data?'),content:const Text('This cannot be undone. All medication records, symptoms, emergency information and correction history will be removed. Previously exported copies remain outside the app.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete all'))]));if(yes!=true)return;try{await reminders.cancel();reminders.pendingAction=null;await store.erase();if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('All local records and reminders removed.')));}catch(e){if(context.mounted)showError(context,e);}})])),
    OutlinedButton.icon(onPressed:()async{final ok=await launchUrl(Uri.parse('https://github.com/omuoguilim/DoseBuddy/issues'),mode:LaunchMode.externalApplication);if(!ok&&context.mounted)showError(context,'Could not open support. Visit github.com/omuoguilim/DoseBuddy/issues.');},icon:const Icon(Icons.help_outline),label:const Text('Support and feedback')),
    const Padding(padding:EdgeInsets.only(top:12),child:Text('Do not include private health information in public feedback.',style:TextStyle(fontSize:14,color:muted))),
  ]);}
}

String csvCell(Object? value){var s='${value??''}';if(RegExp(r'^[\s]*[=+@\-]').hasMatch(s))s="'$s";return '"${s.replaceAll('"','""')}"';}
String exportCsv(Records r){final lines=<String>[['record_type','medication_or_symptom','strength','scheduled_time','actual_time','status','amount','unit','notes'].map(csvCell).join(',')];for(final value in r.outcomes.values){final e=value as Json;final d=ScheduledDose.fromSnapshot(e['dose'] as Json);lines.add([e['prn']==true?'as_needed':'scheduled',d.details['name'],d.details['strength'],d.at.toIso8601String(),e['takenAt'],e['status'],e['amount'],d.details['unit'],e['reason']].map(csvCell).join(','));}for(final value in (r.data['symptoms'] as Json).values){final s=value as Json;lines.add(['symptom',s['name'],'','',s['at'],'reported',s['severity'],'severity / 5',s['notes']].map(csvCell).join(','));}return lines.join('\r\n');}

class ExportPage extends StatefulWidget{
  final AppStore store;const ExportPage({super.key,required this.store});
  @override State<ExportPage> createState()=>_ExportPageState();
}
class _ExportPageState extends State<ExportPage>{String type='Summary';bool busy=false;
  @override Widget build(BuildContext context){final r=widget.store.records;final now=DateTime.now();final text=type=='JSON'?const JsonEncoder.withIndent('  ').convert(r.data):type=='CSV'?exportCsv(r):r.report(DateTime(now.year,now.month,now.day-29),now);return Scaffold(appBar:AppBar(title:const Text('Review export')),body:ListView(padding:const EdgeInsets.all(20),children:[DropdownButtonFormField<String>(initialValue:type,decoration:const InputDecoration(labelText:'Format'),items:const [DropdownMenuItem(value:'Summary',child:Text('30-day summary')),DropdownMenuItem(value:'CSV',child:Text('Recorded doses and symptoms (CSV)')),DropdownMenuItem(value:'JSON',child:Text('Complete records and corrections (JSON)'))],onChanged:(s)=>setState(()=>type=s!)),const Notice('This file contains health information and is not encrypted. Review it before choosing a recipient. Shared copies cannot be revoked.'),SelectableText(text,style:const TextStyle(fontSize:14)),const SizedBox(height:24),Builder(builder:(buttonContext)=>FilledButton.icon(onPressed:busy?null:()async{setState(()=>busy=true);try{final box=buttonContext.findRenderObject() as RenderBox;final dir=await getTemporaryDirectory();final file=File('${dir.path}/dosebuddy-${dayKey(now)}.${type=='JSON'?'json':type=='CSV'?'csv':'txt'}');await file.writeAsString(text);try{await Share.shareXFiles([XFile(file.path)],sharePositionOrigin:box.localToGlobal(Offset.zero)&box.size);}finally{if(await file.exists())await file.delete();}}catch(e){if(context.mounted)showError(context,e);}finally{if(mounted)setState(()=>busy=false);}},icon:const Icon(Icons.ios_share),label:const Text('Choose where to share')))]));}
}

class EmergencyPage extends StatefulWidget{final AppStore store;const EmergencyPage({super.key,required this.store});@override State<EmergencyPage> createState()=>_EmergencyPageState();}
class _EmergencyPageState extends State<EmergencyPage>{final allergies=TextEditingController(),contact=TextEditingController(),notes=TextEditingController();bool busy=false;
  @override void initState(){super.initState();final e=widget.store.data['emergency'] as Json;allergies.text=e['allergies'] as String;contact.text=e['contact'] as String;notes.text=e['notes'] as String;}
  @override void dispose(){allergies.dispose();contact.dispose();notes.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Emergency information')),body:ListView(padding:const EdgeInsets.all(20),children:[const Notice('This is a personal information card inside DoseBuddy. It does not appear on your phone’s emergency lock screen and does not contact emergency services.'),TextField(controller:allergies,maxLines:2,decoration:const InputDecoration(labelText:'Known allergies or explicit “none known”')),const SizedBox(height:16),TextField(controller:contact,decoration:const InputDecoration(labelText:'Emergency contact and phone')),const SizedBox(height:16),TextField(controller:notes,maxLines:3,decoration:const InputDecoration(labelText:'Other information')),const SizedBox(height:20),FilledButton(onPressed:busy?null:()async{setState(()=>busy=true);try{await widget.store.update((r)=>r.data['emergency']={'allergies':allergies.text.trim(),'contact':contact.text.trim(),'notes':notes.text.trim()});if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Emergency information saved.')));}catch(e){if(context.mounted)showError(context,e);}finally{if(mounted)setState(()=>busy=false);}},child:const Text('Save information')),const SizedBox(height:12),OutlinedButton(onPressed:() {final r=widget.store.records;final medications=r.medications.values.cast<Json>().map(r.current).where((f)=>f['active']==true&&(f['end']==null||(f['end'] as String).compareTo(dayKey(DateTime.now()))>=0)).map((f)=>'${f['name']} · ${f['strength']} · ${f['amount']} ${f['unit']}').join('\n');final text='DoseBuddy personal medication card\nPrepared ${dayKey(DateTime.now())}\nUser-entered; verify before relying on it.\n\nMEDICATIONS\n$medications\n\nALLERGIES\n${allergies.text.trim().isEmpty?'Not provided; absence of allergies is not confirmed.':allergies.text}\n\nCONTACT\n${contact.text}\n\nNOTES\n${notes.text}';Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>Scaffold(appBar:AppBar(title:const Text('Review card')),body:ListView(padding:const EdgeInsets.all(20),children:[SelectableText(text),const Notice('Sharing sends a copy of all information shown above.'),Builder(builder:(ctx)=>FilledButton(onPressed:()async{try{final box=ctx.findRenderObject() as RenderBox;await Share.share(text,sharePositionOrigin:box.localToGlobal(Offset.zero)&box.size);}catch(e){if(ctx.mounted)showError(ctx,e);}},child:const Text('Share card')))]))));},child:const Text('Review card before sharing'))]));
}
