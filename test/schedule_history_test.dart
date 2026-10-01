import 'package:flutter_test/flutter_test.dart';
import 'package:dosebuddy/models/medication.dart';

void main() {
  test('weekday and pause changes preserve earlier schedules', () {
    final m = Medication(id:'s',name:'Test',dosage:'1 mg',times:['8:00 AM'],createdAt:DateTime(2026,9,1),details:{'scheduleHistory':[
      {'effectiveAt':'2026-09-01T00:00:00.000','times':['8:00 AM']},
      {'effectiveAt':'2026-10-01T00:00:00.000','times':['9:00 AM'],'weekdays':[1,3,5]},
      {'effectiveAt':'2026-10-03T00:00:00.000','times':['9:00 AM'],'paused':true},
    ]});
    expect(m.timesFor(DateTime(2026,9,30)),['8:00 AM']);
    expect(m.isScheduledFor(DateTime(2026,10,1)),false);
    expect(m.isScheduledFor(DateTime(2026,10,2)),true);
    expect(m.isScheduledFor(DateTime(2026,10,3)),false);
  });
  test('as-needed schedule creates no expected doses', () {
    final m=Medication(id:'p',name:'Test',dosage:'1 mg',times:[],createdAt:DateTime(2026,1,1),details:{'scheduleHistory':[{'effectiveAt':'2026-01-01T00:00:00.000','asNeeded':true}]});
    expect(m.isScheduledFor(DateTime(2026,10,1)),false);
  });
  test('correcting a pre-refill dose does not inflate the new bottle', () {
    final m=Medication(id:'b',name:'Test',dosage:'1 mg',times:[],pillsRemaining:5);
    m.recordDose(DateTime.now(),'8:00 AM','taken');
    m.refill(30);
    m.recordDose(DateTime.now(),'8:00 AM','unknown');
    expect(m.pillsRemaining,30);
  });
  test('a partial stock decrement refunds only the amount removed', () {
    final m=Medication(id:'i',name:'Test',dosage:'1 mg',times:[],pillsRemaining:1,pillsPerDose:2);
    m.recordDose(DateTime.now(),'8:00 AM','taken');
    m.recordDose(DateTime.now(),'8:00 AM','unknown');
    expect(m.pillsRemaining,1);
  });
  test('refill logs before and after inventory', () {
    final m=Medication(id:'r',name:'Test',dosage:'1 mg',times:[],pillsRemaining:3);
    m.refill(30); expect(m.pillsRemaining,30);
    expect((m.details!['refills'] as List).first['previousCount'],3);
    expect(()=>m.refill(-1),throwsArgumentError);
  });
}
