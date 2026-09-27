import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/records.dart';
import '../core/store.dart';
import 'theme.dart';

class DoctorReportPage extends StatelessWidget {
  final AppStore store;
  const DoctorReportPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final r = store.records;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 29);
    final counts = r.counts(start, now);
    final medications = r.medications.values.cast<Json>().map(r.current).toList();
    final symptoms = (r.data['symptoms'] as Json).values.cast<Json>()
        .where((s) {
          final at = DateTime.parse(s['at'] as String);
          return !at.isBefore(start) && !at.isAfter(now);
        }).toList();
    final skipped = r.outcomes.values.cast<Json>().where((o) {
      final at = ScheduledDose.fromSnapshot(o['dose'] as Json).at;
      return o['status'] == 'Skipped' && !at.isBefore(start) && !at.isAfter(now);
    }).toList();
    final text = <String>[
      'DoseBuddy medication summary',
      '${dayKey(start)} to ${dayKey(now)}',
      '',
      'RECORDED DOSES',
      '${counts['taken']} recorded taken of ${counts['scheduled']} scheduled doses due',
      '${counts['skipped']} skipped; ${counts['unrecorded']} not recorded',
      'As-needed doses are excluded from these totals.',
      '',
      'MEDICATIONS LISTED',
      if (medications.isEmpty) 'None listed',
      for (final med in medications)
        '• ${med['name']} ${med['strength']} · ${med['type'] == 'as_needed' ? 'as needed' : (med['times'] as List).cast<int>().map(clockLabel).join(', ')} · ${med['active'] == true ? 'active' : 'paused'}${(med['instructions'] as String? ?? '').isEmpty ? '' : ' · ${med['instructions']}'}',
      '',
      'SYMPTOMS LOGGED',
      if (symptoms.isEmpty) 'None logged',
      for (final symptom in symptoms)
        '• ${dayKey(DateTime.parse(symptom['at'] as String))}: ${symptom['name']} · severity ${symptom['severity']}/5',
      '',
      'SKIPPED DOSE RECORDS',
      if (skipped.isEmpty) 'None logged',
      for (final record in skipped)
        '• ${dayKey(ScheduledDose.fromSnapshot(record['dose'] as Json).at)}: ${(record['dose'] as Json)['details']['name']} · ${record['reason'] ?? ''}',
      '',
      'User-entered records; not proof a dose was consumed or a medical diagnosis.',
      if ((r.data['migrationNotes'] as List).isNotEmpty)
        'Old schedule changes may limit historical totals. Review imported records.',
    ].join('\n');

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor report')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(22)),
          child: SelectableText(text,
              style: const TextStyle(height: 1.5, color: deepInk)),
        ),
        const SizedBox(height: 18),
        Builder(builder: (buttonContext) => FilledButton.icon(
          onPressed: () async {
            try {
              final box = buttonContext.findRenderObject() as RenderBox;
              await Share.share(text,
                  subject: 'DoseBuddy medication summary',
                  sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size);
            } catch (e) {
              if (buttonContext.mounted) showError(buttonContext, e);
            }
          },
          icon: const Icon(Icons.ios_share_outlined),
          label: const Text('Share report'),
        )),
        const SizedBox(height: 12),
        const Text('Review this summary before sharing it with your care team. Shared copies are outside DoseBuddy.',
            style: TextStyle(color: muted)),
      ]),
    );
  }
}
