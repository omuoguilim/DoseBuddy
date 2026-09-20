import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'core/store.dart';
import 'core/reminders.dart';
import 'ui/home.dart';
import 'ui/record_editor.dart';
import 'ui/theme.dart';

class DoseBuddyApp extends StatefulWidget {
  final AppStore store;final Reminders reminders;
  const DoseBuddyApp({super.key,required this.store,required this.reminders});
  @override State<DoseBuddyApp> createState()=>_DoseBuddyAppState();
}
class _DoseBuddyAppState extends State<DoseBuddyApp> with WidgetsBindingObserver{
  final navigator=GlobalKey<NavigatorState>();final auth=LocalAuthentication();
  bool locked=false,obscured=false,authenticating=false,handling=false;String? lockError;
  Timer? ticker;
  @override void initState(){super.initState();locked=widget.store.records.settings['appLock']==true;WidgetsBinding.instance.addObserver(this);widget.reminders.addListener(changed);widget.store.addListener(changed);ticker=Timer.periodic(const Duration(seconds:30),(_){if(mounted)setState((){});});WidgetsBinding.instance.addPostFrameCallback((_)async{await widget.reminders.sync(widget.store.records);handleNotification();});}
  void changed(){if(!mounted)return;setState((){});WidgetsBinding.instance.addPostFrameCallback((_)=>handleNotification());}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);widget.reminders.removeListener(changed);widget.store.removeListener(changed);ticker?.cancel();super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.inactive||state==AppLifecycleState.hidden||state==AppLifecycleState.paused){setState(()=>obscured=true);if(state==AppLifecycleState.paused&&!authenticating&&widget.store.records.settings['appLock']==true)locked=true;}
    if(state==AppLifecycleState.resumed){setState(()=>obscured=false);if(!authenticating)widget.reminders.sync(widget.store.records).then((_)=>handleNotification());}
  }
  Future<bool> authenticate()async{
    if(authenticating)return false;setState((){authenticating=true;lockError=null;});
    try{if(!await auth.isDeviceSupported())throw StateError('Set up a device passcode or biometric authentication first.');final ok=await auth.authenticate(localizedReason:'Unlock your DoseBuddy records',options:const AuthenticationOptions(biometricOnly:false,stickyAuth:true));if(ok&&mounted)setState(()=>locked=false);return ok;}
    catch(_){if(mounted)setState(()=>lockError='Could not authenticate. Check your device passcode or biometric settings and retry.');return false;}
    finally{if(mounted)setState(()=>authenticating=false);}
  }
  Future<void> handleNotification()async{
    if(locked||obscured||authenticating||handling||!mounted||navigator.currentState==null)return;
    final response=widget.reminders.pendingAction;if(response==null)return;
    widget.reminders.pendingAction=null;final key=response.payload;if(key==null)return;
    handling=true;
    try{final now=DateTime.now();final r=widget.store.records;final doses=r.schedule(DateTime(now.year,now.month,now.day-31),DateTime(now.year,now.month,now.day+31));final matches=doses.where((d)=>d.key==key);if(matches.isEmpty)return;final dose=matches.first;
      if(response.actionId=='snooze'&&!r.outcomes.containsKey(key)){await widget.reminders.snooze(key);}else{await navigator.currentState!.push(MaterialPageRoute<void>(builder:(_)=>RecordEditor(store:widget.store,reminders:widget.reminders,dose:dose)));}
    }catch(_){widget.reminders.error='The reminder action could not be completed. Open the dose from Today or History.';if(mounted)setState((){});}finally{handling=false;}
  }
  @override Widget build(BuildContext context)=>MaterialApp(
    navigatorKey:navigator,title:'DoseBuddy',debugShowCheckedModeBanner:false,theme:doseTheme(),
    home:Home(store:widget.store,reminders:widget.reminders,authenticate:authenticate),
    builder:(context,child)=>Stack(children:[if(child!=null)ExcludeSemantics(excluding:locked||obscured,child:IgnorePointer(ignoring:locked||obscured,child:child)),if(locked||obscured)Positioned.fill(child:Material(color:paper,child:SafeArea(child:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.lock_outline,size:44,color:ink),const SizedBox(height:20),Text('DoseBuddy',style:Theme.of(context).textTheme.headlineLarge),if(locked&&!obscured)...[const SizedBox(height:20),if(lockError!=null)Notice(lockError!),FilledButton(onPressed:authenticating?null:()async{await authenticate();handleNotification();},child:Text(authenticating?'Authenticating…':'Unlock records'))]]))))))]),
  );
}

class StartApp extends StatefulWidget{const StartApp({super.key});@override State<StartApp> createState()=>_StartAppState();}
class _StartAppState extends State<StartApp>{late Future<AppStore> opening;final reminders=Reminders();@override void initState(){super.initState();opening=AppStore.open();}@override Widget build(BuildContext context)=>FutureBuilder<AppStore>(future:opening,builder:(context,s){if(s.hasData)return DoseBuddyApp(store:s.data!,reminders:reminders);return MaterialApp(theme:doseTheme(),home:Scaffold(body:SafeArea(child:Center(child:Padding(padding:const EdgeInsets.all(24),child:s.hasError?Column(mainAxisSize:MainAxisSize.min,children:[const Text('DoseBuddy could not open your local records.'),const SizedBox(height:12),const Text('Your existing records have not been replaced. Keep this installation and contact support before deleting anything.'),const SizedBox(height:12),SelectableText('${s.error}',style:const TextStyle(fontSize:14))]):const CircularProgressIndicator())))));});}
