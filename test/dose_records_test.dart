import 'package:flutter_test/flutter_test.dart';
import 'package:dosebuddy/models/medication.dart';

void main() {
  test('a skipped dose stays separate from a taken dose', () {
    final med = Medication(
      id: 'test', name: 'Example', dosage: '1 tablet', times: ['8:00 AM'],
      createdAt: DateTime(2025, 1, 1), pillsRemaining: 12,
    );
    final date = DateTime(2025, 1, 2);
    med.markAsSkippedOn(date, '8:00 AM');
    expect(med.wasSkippedOn(date, '8:00 AM'), isTrue);
    expect(med.wasTakenOn(date, '8:00 AM'), isFalse);
    expect(med.pillsRemaining, 12);

    med.markAsTakenOn(date, '8:00 AM');
    expect(med.wasSkippedOn(date, '8:00 AM'), isFalse);
    expect(med.wasTakenOn(date, '8:00 AM'), isTrue);
    expect(med.pillsRemaining, 11);
    med.markAsTakenOn(date, '8:00 AM');
    expect(med.pillsRemaining, 11);
  });

  test('older taken logs still count as taken', () {
    final med = Medication(
      id: 'legacy', name: 'Existing', dosage: '1 tablet', times: ['9:00 PM'],
      takenLog: [{'date': '2025-01-02', 'scheduledTime': '9:00 PM',
        'takenAt': '2025-01-02T21:00:00'}],
    );
    expect(med.wasTakenOn(DateTime(2025, 1, 2), '9:00 PM'), isTrue);
  });
}
