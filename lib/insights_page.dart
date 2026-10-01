import 'demo/demo_mode.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'models/medication.dart';
import 'models/adherence_summary.dart';
import 'widgets/dosebuddy_theme.dart';
import 'detailed_insights_page.dart';
import 'dose_review_page.dart';
import 'report_page.dart';
import 'health_journal_page.dart';
import 'reminder_health_page.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});
  @override
  State<InsightsPage> createState()=>_InsightsPageState();
}
class _InsightsPageState extends State<InsightsPage> {
  int _days=7,_selected=-1;
  String? _medicationId;
  Future<void> _open(Widget page)async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>page));if(mounted)setState((){});}
  Widget _legend(String label,Color color)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.circle,size:10,color:color),const SizedBox(width:5),Text(label,style:const TextStyle(fontSize:12))]);
  @override
  Widget build(BuildContext context)=>ValueListenableBuilder<Box<Medication>>(valueListenable:Hive.box<Medication>(DemoMode.boxName).listenable(),builder:(context,box,_){
    final selectedId=box.values.any((m)=>m.id==_medicationId)?_medicationId:null;
    final days=adherenceDays(box.values,DateTime.now(),_days,medicationId:selectedId);
    final total=days.fold<int>(0,(n,d)=>n+d.total),taken=days.fold<int>(0,(n,d)=>n+d.count('taken'));
    final selected=days[_selected<0||_selected>=days.length?days.length-1:_selected];
    return Scaffold(appBar:AppBar(title:const Text('Insights'),actions:[PopupMenuButton<String>(tooltip:'More insights tools',onSelected:(v)=>_open(v=='legacy'?const DetailedInsightsPage():v=='reminders'?const ReminderHealthPage():const DoseReviewPage()),itemBuilder:(_)=>const[PopupMenuItem(value:'legacy',child:Text('Detailed week / month analytics')),PopupMenuItem(value:'review',child:Text('Dose review / corrections')),PopupMenuItem(value:'reminders',child:Text('Reminder health'))])]),body:ListView(padding:const EdgeInsets.all(20),children:[
      Wrap(spacing:12,runSpacing:12,children:[SizedBox(width:155,child:DropdownButtonFormField<int>(value:_days,isExpanded:true,decoration:const InputDecoration(labelText:'Period'),items:const[DropdownMenuItem(value:7,child:Text('Last 7 days',maxLines:1,overflow:TextOverflow.ellipsis)),DropdownMenuItem(value:30,child:Text('Last 30 days',maxLines:1,overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState((){_days=v!;_selected=-1;}))),SizedBox(width:190,child:DropdownButtonFormField<String>(value:selectedId??'all',isExpanded:true,decoration:const InputDecoration(labelText:'Medication'),items:[const DropdownMenuItem(value:'all',child:Text('All medications')),for(final m in box.values)DropdownMenuItem(value:m.id,child:Text(m.name,overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState(()=>_medicationId=v=='all'?null:v)))]),const SizedBox(height:18),
      Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(total==0?'No due doses in this period':'Recorded taken: ${(taken/total*100).round()}%',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:6),Text('$taken of $total due doses recorded taken. Missing records are shown separately.',style:Theme.of(context).textTheme.bodySmall),const SizedBox(height:24),
        Semantics(label:'Recorded dose counts by day. Select a day below for its records.',child:SizedBox(height:200,child:BarChart(BarChartData(minY:0,maxY:days.fold<int>(1,(n,d)=>d.total>n?d.total:n).toDouble()+1,barGroups:List.generate(days.length,(i){final d=days[i];double at=0;final stacks=<BarChartRodStackItem>[];for(final e in {'taken':DoseBuddyTheme.purple,'missed':const Color(0xFFDA8B25),'skipped':DoseBuddyTheme.lavender,'unrecorded':const Color(0xFFC5C7D5)}.entries){final next=at+d.count(e.key);stacks.add(BarChartRodStackItem(at,next,e.value));at=next;}return BarChartGroupData(x:i,barRods:[BarChartRodData(toY:d.total.toDouble(),rodStackItems:stacks,width:_days==7?18:6,borderRadius:const BorderRadius.vertical(top:Radius.circular(4)))]);}),barTouchData:BarTouchData(enabled:true,touchCallback:(event,response){if(event is FlTapUpEvent&&response?.spot!=null)setState(()=>_selected=response!.spot!.touchedBarGroupIndex);}),gridData:const FlGridData(show:true,drawVerticalLine:false),borderData:FlBorderData(show:false),titlesData:FlTitlesData(topTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),rightTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),leftTitles:const AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:24,interval:1)),bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:30,getTitlesWidget:(value,meta){final i=value.toInt();if(i<0||i>=days.length||(_days==30&&i%5!=0))return const SizedBox.shrink();return Padding(padding:const EdgeInsets.only(top:8),child:Text(DateFormat(_days==7?'E':'d').format(days[i].date),style:const TextStyle(fontSize:10)));}))))))),
        const SizedBox(height:14),Wrap(spacing:12,runSpacing:8,children:[_legend('Taken',DoseBuddyTheme.purple),_legend('Missed',const Color(0xFFDA8B25)),_legend('Skipped',DoseBuddyTheme.lavender),_legend('Not recorded',const Color(0xFFC5C7D5))]),
      ]))),const SizedBox(height:12),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[for(int i=0;i<days.length;i++)Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text(DateFormat('MMM d').format(days[i].date)),selected:days[i]==selected,onSelected:(_)=>setState(()=>_selected=i)))])),
      Card(child:Column(children:[ListTile(leading:const Icon(Icons.calendar_today_outlined),title:Text(DateFormat('EEEE, MMMM d').format(selected.date)),subtitle:Text('${selected.count('taken')} taken · ${selected.count('missed')} missed · ${selected.count('skipped')} skipped · ${selected.count('unrecorded')} not recorded')),if(selected.rows.isEmpty)const ListTile(title:Text('No due scheduled doses. As-needed records are in your report.')),for(final r in selected.rows)ListTile(title:Text((r['med'] as Medication).name),subtitle:Text('${r['time']} · ${r['state']=='unrecorded'?'Not recorded':r['state']}'),trailing:const Icon(Icons.chevron_right),onTap:()=>_open(DoseReviewPage(medication:r['med'] as Medication,date:selected.date,time:r['time'] as String)))])),
      Card(child:Column(children:[ListTile(leading:const Icon(Icons.monitor_heart_outlined),title:const Text('Symptom timeline'),subtitle:const Text('Measurements and appointment notes'),trailing:const Icon(Icons.chevron_right),onTap:()=>_open(const HealthJournalPage())),const Divider(height:1),ListTile(leading:const Icon(Icons.description_outlined),title:const Text('Doctor report'),subtitle:const Text('Choose dates and records before sharing'),trailing:const Icon(Icons.chevron_right),onTap:()=>_open(const ReportPage()))])),const SizedBox(height:12),OutlinedButton(onPressed:()=>_open(const ReportPage()),child:const Text('Preview report')),const SizedBox(height:20),
    ]));
  });
}
