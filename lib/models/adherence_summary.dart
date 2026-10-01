import 'medication.dart';

class AdherenceDay {
  final DateTime date;
  final List<Map<String,dynamic>> rows;
  AdherenceDay(this.date,this.rows);
  int count(String state)=>rows.where((r)=>r['state']==state).length;
  int get total=>rows.length;
}
List<AdherenceDay> adherenceDays(Iterable<Medication> medications,DateTime now,int days,{String? medicationId}) {
  return List.generate(days,(i){
    final date=DateTime(now.year,now.month,now.day-days+1+i),rows=<Map<String,dynamic>>[];
    for(final med in medications){
      if(medicationId!=null&&med.id!=medicationId)continue;
      if(!med.isScheduledFor(date))continue;
      for(final time in med.timesFor(date)){
        if(med.scheduledAt(date,time).isAfter(now))continue;
        final state=med.wasTakenOn(date,time)?'taken':med.wasMissedOn(date,time)?'missed':med.wasSkippedOn(date,time)?'skipped':'unrecorded';
        rows.add({'med':med,'time':time,'state':state});
      }
    }
    return AdherenceDay(date,rows);
  });
}
