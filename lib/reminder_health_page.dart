import 'demo/demo_mode.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_services.dart';

class ReminderHealthPage extends StatefulWidget {
  const ReminderHealthPage({super.key});
  @override
  State<ReminderHealthPage> createState()=>_ReminderHealthPageState();
}
class _ReminderHealthPageState extends State<ReminderHealthPage> {
  bool _enabled=true,_private=true,_busy=false;
  String _timezone='America/New_York',_horizon='',_permission='Not checked';
  int _count=0;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load()async{final p=await SharedPreferences.getInstance();final count=await NotificationService().getPendingNotificationsCount();if(mounted)setState((){_enabled=p.getBool('reminders_enabled')??true;_private=p.getBool('private_notifications')??true;_timezone=p.getString('reminder_timezone')??'America/New_York';_horizon=p.getString('reminder_horizon')??'';_count=count;});}
  Future<void> _save()async{
    setState(()=>_busy=true);
    try{final p=await SharedPreferences.getInstance();await p.setBool('reminders_enabled',_enabled);await p.setBool('private_notifications',_private);await p.setString('reminder_timezone',_timezone);await NotificationService().rescheduleAll();await _load();}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not rebuild reminders. Please try again.')));}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Reminder health & privacy')),body:ListView(padding:const EdgeInsets.all(20),children:[
    if(DemoMode.enabled) const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Phone reminder settings preview. This browser demo does not deliver scheduled notifications.'))),
    SwitchListTile(title:const Text('Medication reminders'),value:_enabled,onChanged:_busy?null:(v){setState(()=>_enabled=v);_save();}),
    SwitchListTile(title:const Text('Hide medication names on notifications'),subtitle:const Text('Private text is the default.'),value:_private,onChanged:_busy?null:(v){setState(()=>_private=v);_save();}),
    const Text('Reminders follow this home timezone. Changing it does not change previous dose records. Automatic travel detection is not enabled.'),
    DropdownButtonFormField<String>(value:_timezone,items:['America/New_York','America/Chicago','America/Denver','America/Los_Angeles','Europe/London','Africa/Lagos','Asia/Kolkata','Asia/Tokyo','Australia/Sydney','UTC'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:_busy?null:(v){setState(()=>_timezone=v!);_save();}),
    ListTile(title:Text('Permission: $_permission'),subtitle:const Text('Device settings may suppress notifications even when scheduling succeeds.')),
    ElevatedButton(onPressed:DemoMode.enabled?null:()async{final ok=await NotificationService().requestPermissions();if(mounted)setState(()=>_permission=ok==true?'Granted':ok==false?'Denied':'Check device settings');},child:const Text('Request notification permission')),
    TextButton(onPressed:DemoMode.enabled?null:()async{await NotificationService().showTestNotification();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('One-time test scheduled for five seconds. Watch for it on your device.')));},child:const Text('Test a reminder')),
    Text('$_count pending reminders. Scheduled through: ${_horizon.isEmpty?'None':_horizon}'),
    const Text('The app schedules the next 60 doses across all medications. Reopen it to extend coverage. Scheduling does not prove delivery or that a reminder was seen.'),
    TextButton(onPressed:_busy?null:_save,child:const Text('Rebuild reminders')),
  ]));
}
