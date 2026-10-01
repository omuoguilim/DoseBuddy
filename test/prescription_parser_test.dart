import 'package:flutter_test/flutter_test.dart';
import 'package:dosebuddy/services/prescription_parser.dart';
import 'package:dosebuddy/models/medication.dart';

void main() {
  test('label strength extraction never generates a schedule', () {
    final f = PrescriptionFields.parse('CVS Pharmacy\nAmoxicillin 250 mg\nTake one tablet twice daily');
    expect(f.name, 'Amoxicillin'); expect(f.strength, '250'); expect(f.unit, 'mg');
    expect(f.directions, 'Take one tablet twice daily');
  });
  test('unclear label stays empty instead of inventing medication', () {
    final f = PrescriptionFields.parse('Unreadable label');
    expect(f.name, ''); expect(f.strength, '');
  });
  test('missed and unknown records are not taken; corrections reconcile supply', () {
    final m = Medication(id: '1', name: 'Test', dosage: '1 mg', times: ['8:00 AM'], pillsRemaining: 10, pillsPerDose: 2);
    final d = DateTime(2026, 9, 30);
    m.recordDose(d, '8:00 AM', 'missed', reason: 'Forgot');
    expect(m.wasTakenOn(d, '8:00 AM'), false); expect(m.pillsRemaining, 10);
    m.recordDose(d, '8:00 AM', 'taken'); expect(m.pillsRemaining, 8);
    m.recordDose(d, '8:00 AM', 'taken'); expect(m.pillsRemaining, 8);
    m.recordDose(d, '8:00 AM', 'unknown'); expect(m.pillsRemaining, 10);
    expect((m.takenLog!.first['corrections'] as List).length, 3);
  });
}
