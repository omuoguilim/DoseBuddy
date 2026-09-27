import 'package:flutter/material.dart';
import '../core/records.dart';
import '../core/store.dart';
import 'record_editor.dart';
import 'theme.dart';

class TimelinePage extends StatelessWidget {
  final AppStore store;
  const TimelinePage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final records = store.records;
    final entries = <({DateTime at, Widget card})>[];
    for (final raw in records.outcomes.values) {
      final outcome = raw as Json;
      final dose = ScheduledDose.fromSnapshot(outcome['dose'] as Json);
      final at = DateTime.parse(
        outcome['takenAt'] as String? ?? outcome['recordedAt'] as String,
      );
      entries.add((
        at: at,
        card: _card(
          Icons.medication_outlined,
          dose.details['name'] as String,
          '${clockLabel(dose.at.hour * 60 + dose.at.minute)} · ${dose.details['strength']} · ${outcome['status']}',
          outcome['reason'] as String? ?? '',
        ),
      ));
    }
    for (final raw in (records.data['symptoms'] as Json).values) {
      final symptom = raw as Json;
      entries.add((
        at: DateTime.parse(symptom['at'] as String),
        card: _card(
          Icons.monitor_heart_outlined,
          symptom['name'] as String,
          'Severity ${symptom['severity']}/5 · ${symptom['duration']}',
          symptom['notes'] as String? ?? '',
        ),
      ));
    }
    for (final raw in records.data['audit'] as List) {
      final audit = raw as Json;
      if (audit['action'] != 'legacy side effects imported') continue;
      for (final value in audit['records'] as List) {
        final note = value as Json;
        final at = DateTime.tryParse(note['date']?.toString() ?? '');
        if (at == null) continue;
        entries.add((
          at: at,
          card: _card(
            Icons.monitor_heart_outlined,
            note['name']?.toString() ?? 'Imported side effect',
            'Imported from the previous DoseBuddy version',
            note['notes']?.toString() ?? '',
          ),
        ));
      }
    }
    entries.sort((a, b) => b.at.compareTo(a.at));
    return Scaffold(
      appBar: AppBar(title: const Text('Health timeline')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => SymptomEditor(store: store),
        )),
        icon: const Icon(Icons.add),
        label: const Text('Log symptom'),
      ),
      body: entries.isEmpty
          ? const Center(child: Padding(
              padding: EdgeInsets.all(30),
              child: Text('Your recorded doses and symptoms will appear here.',
                  textAlign: TextAlign.center),
            ))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final showDate = index == 0 ||
                    dayKey(entries[index - 1].at) != dayKey(entry.at);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (showDate) Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(dayKey(entry.at), style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: deepInk)),
                  ),
                  entry.card,
                ]);
              },
            ),
    );
  }

  Widget _card(IconData icon, String title, String subtitle, String detail) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: ink),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
                fontWeight: FontWeight.w700, color: deepInk)),
            Text(subtitle, style: const TextStyle(color: muted)),
            if (detail.trim().isNotEmpty)
              Text(detail, style: const TextStyle(color: muted, fontSize: 13)),
          ])),
        ]),
      );
}
