import 'package:flutter_test/flutter_test.dart';
import 'package:dosebuddy/models/medication.dart';
import 'package:dosebuddy/models/adherence_summary.dart';
void main(){
  test('chart keeps missing, missed and skipped distinct and excludes future doses',(){
    final now=DateTime(2026,9,30,12);
    final m=Medication(id:'a',name:'Test',dosage:'1 mg',times:['8:00 AM','9:00 AM','10:00 AM','11:00 AM','8:00 PM'],createdAt:DateTime(2026,9,1));
    m.recordDose(now,'8:00 AM','taken');m.recordDose(now,'9:00 AM','missed');m.recordDose(now,'10:00 AM','skipped');
    final day=adherenceDays([m],now,1).single;
    expect(day.total,4);expect(day.count('taken'),1);expect(day.count('missed'),1);expect(day.count('skipped'),1);expect(day.count('unrecorded'),1);
  });
  test('medication filter uses identity even when names match',(){
    final a=Medication(id:'a',name:'Same',dosage:'1 mg',times:['8:00 AM'],createdAt:DateTime(2026,9,1));
    final b=Medication(id:'b',name:'Same',dosage:'2 mg',times:['9:00 AM'],createdAt:DateTime(2026,9,1));
    final day=adherenceDays([a,b],DateTime(2026,9,30,12),1,medicationId:'b').single;
    expect(day.total,1);expect((day.rows.single['med'] as Medication).id,'b');
  });
}
