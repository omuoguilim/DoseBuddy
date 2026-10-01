import 'demo/demo_mode.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'models/medication.dart';
import 'widgets/dosebuddy_theme.dart';
import 'calendar_page.dart';
import 'homepage.dart';
import 'square.dart';
import 'dose_review_page.dart';
import 'add_medication_page.dart';
import 'reminder_health_page.dart';
import 'report_page.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});
  @override
  State<TodayPage> createState()=>_TodayPageState();
}
class _TodayPageState extends State<TodayPage> {
  String _name='';
  Timer? _clock;
  @override
  void initState(){super.initState();_loadName();_clock=Timer.periodic(const Duration(minutes:1),(_){if(mounted)setState((){});});}
  Future<void> _loadName()async{final p=await SharedPreferences.getInstance();if(mounted)setState(()=>_name=p.getString('user_name')??'');}
  Future<void> _open(Widget page)async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>page));if(mounted){await _loadName();setState((){});}}
  Future<void> _record(Map<String,dynamic> row,String state)async=>_open(DoseReviewPage(medication:row['med'] as Medication,date:row['date'] as DateTime,time:row['time'] as String,initialState:state));
  Widget _card(List<Widget> children)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:children)));
  Widget _calendarCard(DateTime now) => _card([
    Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
      Text(DateFormat('MMMM yyyy').format(now), style: const TextStyle(fontWeight: FontWeight.w600)),
      TextButton.icon(onPressed: () => _open(const CalendarPage()), icon: const Icon(Icons.calendar_today_outlined, size: 18), label: const Text('View calendar')),
    ]),
    Wrap(spacing: 8, runSpacing: 8, children: List.generate(7, (i) {
      final d = DateTime(now.year, now.month, now.day - now.weekday + 1 + i);
      final selected = d.day == now.day && d.month == now.month;
      return Semantics(label: DateFormat('EEEE, MMMM d').format(d), button: true, selected: selected,
        child: InkWell(onTap: () => _open(CalendarPage(initialDate: d)), borderRadius: BorderRadius.circular(12),
          child: Container(constraints: const BoxConstraints(minWidth: 36, minHeight: 48), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(color: selected ? DoseBuddyTheme.tint : Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(DateFormat('E').format(d), style: const TextStyle(fontSize: 11)),
              Text('${d.day}', style: TextStyle(fontWeight: FontWeight.w700, color: selected ? DoseBuddyTheme.purple : DoseBuddyTheme.ink)),
            ]),
          ),
        ),
      );
    })),
  ]);
  @override
  Widget build(BuildContext context)=>ValueListenableBuilder<Box<Medication>>(valueListenable:Hive.box<Medication>(DemoMode.boxName).listenable(),builder:(context,box,_){
    final now=DateTime.now(),today=DateTime.now();
    final rows=<Map<String,dynamic>>[],future=<Map<String,dynamic>>[];
    for(final m in box.values){
      for(int day=0;day<30;day++){
        final date=DateTime(today.year,today.month,today.day+day);
        if(!m.isScheduledFor(date))continue;
        for(final time in m.timesFor(date)){
          final at=m.scheduledAt(date,time),state=m.getStatusForDateTime(date,time);
          final row={'med':m,'date':date,'time':time,'at':at,'state':state};
          if(day==0)rows.add(row);
          if(at.isAfter(now)&&state=='upcoming')future.add(row);
        }
      }
    }
    rows.sort((a,b)=>(a['at'] as DateTime).compareTo(b['at'] as DateTime));future.sort((a,b)=>(a['at'] as DateTime).compareTo(b['at'] as DateTime));
    final due=rows.where((r)=>!(r['at'] as DateTime).isAfter(now)).toList();
    final unresolved=due.where((r)=>!['taken','skipped','missed'].contains(r['state'])).toList();
    final taken=due.where((r)=>r['state']=='taken').length;
    final greeting=now.hour<12?'Good morning':now.hour<17?'Good afternoon':'Good evening';
    final next=future.isEmpty?null:future.first;
    final refill=box.values.where((m)=>m.needsRefill()&&m.scheduleFor(now)['archived']!=true).toList();
    return Scaffold(body:CustomScrollView(slivers:[
      SliverToBoxAdapter(child:Container(padding:EdgeInsets.fromLTRB(20,MediaQuery.paddingOf(context).top+20,20,22),decoration:const BoxDecoration(gradient:LinearGradient(colors:[DoseBuddyTheme.purple,DoseBuddyTheme.lavender],begin:Alignment.topLeft,end:Alignment.bottomRight)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Expanded(child:Text('$greeting${_name.isEmpty?'':', $_name'}',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w700,color:Colors.white))),IconButton(tooltip:'Reminder health',onPressed:()=>_open(const ReminderHealthPage()),icon:const Icon(Icons.notifications_outlined,color:Colors.white)),PopupMenuButton<String>(tooltip:'More Today options',icon:const Icon(Icons.more_horiz,color:Colors.white),onSelected:(v)=>_open(v=='daily'?const HomePage():const ReportPage()),itemBuilder:(_)=>const[PopupMenuItem(value:'daily',child:Text('Detailed daily view')),PopupMenuItem(value:'report',child:Text('Doctor report'))])]),
        Text(DateFormat('EEEE, MMMM d').format(now),style:const TextStyle(color:Colors.white,fontSize:14)),const SizedBox(height:16),
        _card([const Text("Today's progress",style:TextStyle(fontWeight:FontWeight.w600)),const SizedBox(height:8),Text('$taken of ${due.length} due doses recorded taken',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:17)),const SizedBox(height:10),Semantics(label:'$taken of ${due.length} due doses recorded taken',child:LinearProgressIndicator(value:due.isEmpty?0:taken/due.length,minHeight:8,borderRadius:BorderRadius.circular(8),color:DoseBuddyTheme.purple,backgroundColor:DoseBuddyTheme.tint)),const SizedBox(height:8),Text('${unresolved.length} need review · ${rows.length-due.length} upcoming',style:const TextStyle(color:DoseBuddyTheme.muted))]),
      ]))),
      SliverPadding(padding:const EdgeInsets.all(20),sliver:SliverList(delegate:SliverChildListDelegate([
        if(box.isEmpty)_card([const Text('Start with your first medication',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),const SizedBox(height:8),const Text('Add its label details and the schedule you were given.'),const SizedBox(height:12),ElevatedButton.icon(onPressed:()=>_open(const AddMedicationPage()),icon:const Icon(Icons.add),label:const Text('Add medication'))]),
        if(next!=null)_card([const Text('Next scheduled dose',style:TextStyle(fontWeight:FontWeight.w600)),const SizedBox(height:14),Row(children:[const MedicationGlyph(),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text((next['med'] as Medication).name,style:Theme.of(context).textTheme.titleMedium),Text('Strength: ${(next['med'] as Medication).dosage}'),Text(DateFormat('EEE, h:mm a').format(next['at'] as DateTime),style:Theme.of(context).textTheme.titleLarge)]))]),const SizedBox(height:12),SizedBox(width:double.infinity,child:ElevatedButton(onPressed:()=>_record(next,'taken'),child:const Text('Record dose')))]),
        if(unresolved.isNotEmpty)_card([Text('Your ${(unresolved.first['time'])} dose',style:Theme.of(context).textTheme.titleMedium),Text((unresolved.first['med'] as Medication).name),const Text('What happened?'),const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:[for(final entry in {'taken':'Taken','skipped':'Skipped','missed':'Missed','unknown':'Not sure'}.entries)OutlinedButton(onPressed:()=>_record(unresolved.first,entry.key),child:Text(entry.value))]),TextButton(onPressed:()=>_open(const DoseReviewPage()),child:Text('Review all ${unresolved.length} unresolved doses'))]),
        _calendarCard(now),
        for(final m in refill)_card([Text('Refill record: ${m.name}',style:const TextStyle(fontWeight:FontWeight.w600)),Text('${m.pillsRemaining} pills remaining'),TextButton(onPressed:()=>_open(const HomePage()),child:const Text('Review refill'))]),
        if(rows.isNotEmpty)...[const SizedBox(height:16),Text("Today's schedule",style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),for(final r in rows)MySquare(medication:r['med'] as Medication,displayTime:r['time'] as String,onStatusChanged:(){if(mounted)setState((){});})],
        const SizedBox(height:20),
      ]))),
    ]));
  });
  @override
  void dispose(){_clock?.cancel();super.dispose();}
}
