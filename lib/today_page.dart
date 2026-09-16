import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'models/medication.dart';
import 'models/dose_event.dart';
import 'add_medication_page.dart';
import 'symptom_logger_page.dart';
import 'health_timeline_page.dart';
import 'routine_tools_page.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});
  @override State<TodayPage> createState() => _TodayPageState();
}

class _DoseItem {
  final Medication medication;
  final String time;
  final DateTime scheduledAt;
  _DoseItem(this.medication, this.time, this.scheduledAt);
}

class _TodayPageState extends State<TodayPage> {
  List<Medication> get medications => Hive.box<Medication>('medications').values.toList();

  DateTime _atTime(String value) {
    final parsed = DateFormat('h:mm a').parse(value);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
  }

  List<_DoseItem> get doses {
    final items = <_DoseItem>[];
    for (final med in medications) {
      for (final time in med.times) {
        items.add(_DoseItem(med, time, _atTime(time)));
      }
    }
    items.sort((a,b) => a.scheduledAt.compareTo(b.scheduledAt));
    return items;
  }

  _DoseItem? get nextDose {
    final now = DateTime.now();
    for (final d in doses) {
      final id = '${d.medication.id}_${d.scheduledAt.millisecondsSinceEpoch}';
      final event = Hive.box<DoseEvent>('dose_events').get(id);
      final resolved = event != null && ['taken','late','skipped'].contains(event.status);
      if (!resolved && !d.medication.wasTakenOn(now, d.time) && d.scheduledAt.add(Duration(minutes: d.medication.gracePeriodMinutes)).isAfter(now)) return d;
    }
    return null;
  }

  Future<void> _take(_DoseItem d) async {
    final now = DateTime.now();
    d.medication.markAsTakenOn(now, d.time);
    await d.medication.save();
    final event = DoseEvent(
      id: '${d.medication.id}_${d.scheduledAt.millisecondsSinceEpoch}',
      medicationId: d.medication.id,
      scheduledAt: d.scheduledAt,
      takenAt: now,
      status: now.isAfter(d.scheduledAt.add(Duration(minutes: d.medication.gracePeriodMinutes))) ? 'late' : 'taken',
      amount: d.medication.pillsPerDose,
    );
    await Hive.box<DoseEvent>('dose_events').put(event.id, event);
    if (mounted) setState(() {});
  }

  Future<void> _skip(_DoseItem d) async {
    final reason = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (context) => SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Why are you skipping this dose?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 12),
        ...['Forgot / too late','Don’t have it with me','Side effects','Schedule conflict','Clinician told me to','Other'].map((r) => ListTile(contentPadding: EdgeInsets.zero, title: Text(r), trailing: const Icon(Icons.chevron_right), onTap: ()=>Navigator.pop(context,r)))
      ]),
    )));
    if (reason == null) return;
    final event = DoseEvent(id: '${d.medication.id}_${d.scheduledAt.millisecondsSinceEpoch}', medicationId: d.medication.id, scheduledAt: d.scheduledAt, status: 'skipped', amount: d.medication.pillsPerDose, reason: reason);
    await Hive.box<DoseEvent>('dose_events').put(event.id, event);
    if (mounted) setState(() {});
  }

  String _status(_DoseItem d) {
    final id = '${d.medication.id}_${d.scheduledAt.millisecondsSinceEpoch}';
    final event = Hive.box<DoseEvent>('dose_events').get(id);
    if (event != null) return event.status;
    if (d.medication.wasTakenOn(DateTime.now(), d.time)) return 'taken';
    final now = DateTime.now();
    if (now.isAfter(d.scheduledAt.add(Duration(minutes: d.medication.gracePeriodMinutes)))) return 'missed';
    if (now.isAfter(d.scheduledAt)) return 'due';
    return 'upcoming';
  }

  @override Widget build(BuildContext context) {
    final all = doses;
    final completed = all.where((d) => ['taken','late'].contains(_status(d))).length;
    final next = nextDose;
    return Scaffold(backgroundColor: const Color(0xFFF6F7FB), body: SafeArea(child: RefreshIndicator(onRefresh: () async => setState((){}), child: ListView(padding: const EdgeInsets.fromLTRB(20,18,20,110), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(DateFormat('EEEE, MMMM d').format(DateTime.now()), style: const TextStyle(color: Color(0xFF7B8194), fontWeight: FontWeight.w600)), const SizedBox(height:4), const Text('Today', style: TextStyle(fontSize:32,fontWeight:FontWeight.w800,color:Color(0xFF191C2B))) ]), Row(children:[IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const RoutineToolsPage())),icon:const Icon(Icons.tune_rounded,color:Color(0xFF5965D8)),tooltip:'Routine tools'),CircleAvatar(backgroundColor: const Color(0xFFE8EAFE), child: IconButton(icon: const Icon(Icons.add_rounded,color:Color(0xFF5965D8)), onPressed: () async {await Navigator.push(context, MaterialPageRoute(builder:(_)=>const AddMedicationPage())); setState((){});} ))])]),
      const SizedBox(height:24),
      if (all.isEmpty) _empty() else ...[
        _progress(completed, all.length), const SizedBox(height:16),
        if (next != null) _hero(next) else _doneHero(),
        const SizedBox(height:18), _quickActions(),
        if (_lowSupply.isNotEmpty) ...[const SizedBox(height:14), _refillBanner()],
        if (_prnMeds.isNotEmpty) ...[const SizedBox(height:22), _prnSection()],
        const SizedBox(height:28), const Text('Today’s doses', style: TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:Color(0xFF191C2B))), const SizedBox(height:12),
        ...all.map(_doseCard),
      ]
    ]))));
  }


  List<Medication> get _lowSupply => medications.where((m)=>!m.isCompleted && m.needsRefill()).toList();
  List<Medication> get _prnMeds => medications.where((m)=>m.isAsNeeded && !m.isCompleted).toList();
  Widget _refillBanner()=>Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:const Color(0xFFFFF4DE),borderRadius:BorderRadius.circular(18)),child:Row(children:[const Icon(Icons.inventory_2_outlined,color:Color(0xFFB7791F)),const SizedBox(width:10),Expanded(child:Text(_lowSupply.length==1?'${_lowSupply.first.name} is running low':'${_lowSupply.length} medications are running low',style:const TextStyle(fontWeight:FontWeight.w700,color:Color(0xFF7A581B)))),TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const RoutineToolsPage())),child:const Text('Review'))]));
  Widget _prnSection()=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('As needed',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),const SizedBox(height:4),const Text('PRN medications are logged when you actually take them.',style:TextStyle(fontSize:12.5,color:Color(0xFF8B93AA))),const SizedBox(height:10),..._prnMeds.map((m)=>Row(children:[const Icon(Icons.bolt_rounded,size:18,color:Color(0xFF5965D8)),const SizedBox(width:8),Expanded(child:Text(m.name,style:const TextStyle(fontWeight:FontWeight.w700))),Text('${m.dosage}',style:const TextStyle(color:Color(0xFF8B93AA)))]))]));

  Widget _quickActions()=>Row(children:[
    Expanded(child:OutlinedButton.icon(style:OutlinedButton.styleFrom(backgroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:14),side:BorderSide.none,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),onPressed:() async {await Navigator.push(context,MaterialPageRoute(builder:(_)=>const SymptomLoggerPage()));setState((){});},icon:const Icon(Icons.add_reaction_outlined,color:Color(0xFF5965D8)),label:const Text('Log symptom'))),
    const SizedBox(width:10),
    Expanded(child:OutlinedButton.icon(style:OutlinedButton.styleFrom(backgroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:14),side:BorderSide.none,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const HealthTimelinePage())),icon:const Icon(Icons.timeline_rounded,color:Color(0xFF5965D8)),label:const Text('Timeline'))),
  ]);

  Widget _progress(int done, int total) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22)), child: Row(children:[SizedBox(width:52,height:52,child:Stack(alignment:Alignment.center,children:[CircularProgressIndicator(value: total==0?0:done/total,strokeWidth:6,backgroundColor:const Color(0xFFEEF0F7)),Text('$done/$total',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12))])),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Daily progress',style:TextStyle(fontWeight:FontWeight.w700,fontSize:16)),const SizedBox(height:3),Text(done==total?'All scheduled doses complete':'${total-done} dose${total-done==1?'':'s'} left today',style:const TextStyle(color:Color(0xFF7B8194))) ]))]));

  Widget _hero(_DoseItem d) => Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF5965D8),Color(0xFF7B68D9)],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(28)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('NEXT DOSE',style:TextStyle(color:Colors.white70,fontSize:12,fontWeight:FontWeight.w800,letterSpacing:1.2)),const SizedBox(height:18),Row(children:[Container(width:54,height:54,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.16),borderRadius:BorderRadius.circular(17)),child:const Icon(Icons.medication_rounded,color:Colors.white,size:30)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(d.medication.name,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w800)),Text('${d.medication.dosage} • ${d.medication.pillsPerDose} pill${d.medication.pillsPerDose==1?'':'s'}',style:const TextStyle(color:Colors.white70,fontSize:14))])),Text(d.time,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:18))]),if(d.medication.notes.trim().isNotEmpty)...[const SizedBox(height:16),Text(d.medication.notes,style:const TextStyle(color:Colors.white70))],const SizedBox(height:20),Row(children:[Expanded(child:FilledButton(style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:const Color(0xFF5965D8),padding:const EdgeInsets.symmetric(vertical:14)),onPressed:()=>_take(d),child:const Text('Take now'))),const SizedBox(width:10),OutlinedButton(style:OutlinedButton.styleFrom(foregroundColor:Colors.white,side:const BorderSide(color:Colors.white54),padding:const EdgeInsets.symmetric(vertical:14,horizontal:16)),onPressed:()=>_skip(d),child:const Text('Skip'))]) ]));

  Widget _doneHero()=>Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:const Color(0xFFEAF7EF),borderRadius:BorderRadius.circular(28)),child:const Row(children:[CircleAvatar(backgroundColor:Color(0xFFD4F0DE),child:Icon(Icons.check_rounded,color:Color(0xFF2E8B57))),SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('You’re all set',style:TextStyle(fontWeight:FontWeight.w800,fontSize:20)),Text('No more scheduled doses for today.',style:TextStyle(color:Color(0xFF65736B))) ]))]));

  Widget _doseCard(_DoseItem d) { final status=_status(d); final good=['taken','late'].contains(status); return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:Row(children:[Container(width:46,height:46,decoration:BoxDecoration(color:good?const Color(0xFFEAF7EF):const Color(0xFFF0F1FC),borderRadius:BorderRadius.circular(14)),child:Icon(good?Icons.check_rounded:Icons.medication_rounded,color:good?const Color(0xFF2E8B57):const Color(0xFF5965D8))),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(d.medication.name,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:16)),Text('${d.time} • ${d.medication.dosage}',style:const TextStyle(color:Color(0xFF7B8194),fontSize:13))])),Text(status.replaceAll('_',' ').toUpperCase(),style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:good?const Color(0xFF2E8B57):status=='missed'?const Color(0xFFC65353):const Color(0xFF7B8194))) ])); }

  Widget _empty()=>Container(margin:const EdgeInsets.only(top:70),padding:const EdgeInsets.all(28),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(28)),child:Column(children:[const Icon(Icons.medication_liquid_rounded,size:54,color:Color(0xFF5965D8)),const SizedBox(height:16),const Text('Build your medication routine',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:8),const Text('Add your first medication and DoseBuddy will organize today around what you need to take next.',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFF7B8194),height:1.4)),const SizedBox(height:20),FilledButton(onPressed:() async {await Navigator.push(context,MaterialPageRoute(builder:(_)=>const AddMedicationPage()));setState((){});},child:const Text('Add medication'))]));
}
