import 'package:flutter/material.dart';
import '../core/records.dart';
import '../core/store.dart';
import 'theme.dart';

/// Visual summaries of recorded doses. No score implies a clinical outcome.
class InsightsPage extends StatefulWidget {
  final AppStore store;
  const InsightsPage({super.key, required this.store});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  int days = 7;
  static const lavender = Color(0xFFEEEFFF);

  @override
  Widget build(BuildContext context) {
    final records = widget.store.records;
    final now = DateTime.now();
    final today = dayStart(now);
    final first = DateTime(today.year, today.month, today.day - days + 1);
    final due = records.schedule(first, now).where((d) => !d.at.isAfter(now)).toList();
    final taken = due.where((d) => records.status(d, now) == 'Taken').length;
    final skipped = due.where((d) => records.status(d, now) == 'Skipped').length;
    final rate = due.isEmpty ? 0.0 : taken / due.length;
    final dates = List.generate(days, (i) => DateTime(first.year, first.month, first.day + i));
    final byMedication = <String, List<ScheduledDose>>{};
    for (final dose in due) {
      byMedication.putIfAbsent(dose.medicationId, () => []).add(dose);
    }

    return ListView(
      key: const PageStorageKey('insights'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      children: [
        const Text('Your routine, at a glance',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: deepInk)),
        const SizedBox(height: 6),
        const Text('A picture of what you logged, day by day.',
            style: TextStyle(color: muted)),
        const SizedBox(height: 22),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 days')),
            ButtonSegment(value: 30, label: Text('30 days')),
          ],
          selected: {days},
          onSelectionChanged: (choice) => setState(() => days = choice.first),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B67CA), Color(0xFF9B8CE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('RECORDED TAKEN', style: TextStyle(
                color: Colors.white70, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(due.isEmpty ? '—' : '${(rate * 100).round()}%',
                style: const TextStyle(color: Colors.white, fontSize: 54,
                    height: 1, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(due.isEmpty
                ? 'No scheduled doses due in this period yet.'
                : '$taken of ${due.length} scheduled doses due · $skipped skipped',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 9,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _metric('$taken', 'Taken', Icons.check_circle_outline)),
          const SizedBox(width: 10),
          Expanded(child: _metric('$skipped', 'Skipped', Icons.remove_circle_outline)),
          const SizedBox(width: 10),
          Expanded(child: _metric('${due.length - taken - skipped}',
              'Not recorded', Icons.schedule)),
        ]),
        const SizedBox(height: 28),
        const Text('Recent days', style: TextStyle(
            fontSize: 21, fontWeight: FontWeight.w800, color: deepInk)),
        const SizedBox(height: 5),
        const Text('Purple shows the share you recorded as taken.',
            style: TextStyle(color: muted)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(22)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end,
              children: dates.map((date) {
                final rows = due.where((d) => dayKey(d.at) == dayKey(date)).toList();
                final complete = rows.where((d) => records.status(d, now) == 'Taken').length;
                return SizedBox(
                  width: days == 7 ? 43 : 30,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(rows.isEmpty ? '–' : '$complete/${rows.length}',
                        style: const TextStyle(fontSize: 11, color: muted)),
                    const SizedBox(height: 8),
                    Container(
                      height: 94, width: 18,
                      alignment: Alignment.bottomCenter,
                      decoration: BoxDecoration(color: lavender,
                          borderRadius: BorderRadius.circular(9)),
                      child: FractionallySizedBox(
                        heightFactor: rows.isEmpty ? 0 : complete / rows.length,
                        child: Container(decoration: BoxDecoration(
                          color: ink, borderRadius: BorderRadius.circular(9))),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text('${date.month}/${date.day}', style: const TextStyle(
                        fontSize: 10, color: muted)),
                  ]),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text('By medication', style: TextStyle(
            fontSize: 21, fontWeight: FontWeight.w800, color: deepInk)),
        const SizedBox(height: 12),
        if (byMedication.isEmpty)
          _surface(const Text('Medication breakdowns will appear once doses are due.')),
        ...byMedication.entries.map((entry) {
          final rows = entry.value;
          final count = rows.where((d) => records.status(d, now) == 'Taken').length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(rows.first.details['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: deepInk))),
                Text('$count/${rows.length}', style: const TextStyle(
                    fontWeight: FontWeight.w700, color: ink)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
                value: count / rows.length, minHeight: 8,
                backgroundColor: lavender,
                valueColor: const AlwaysStoppedAnimation<Color>(ink),
              )),
            ])),
          );
        }),
        const SizedBox(height: 18),
        const Text(
          'These numbers come from your own entries, not confirmation that a dose was consumed. As-needed doses are separate from scheduled totals.',
          style: TextStyle(color: muted, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Widget _surface(Widget content) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(20)),
    child: content,
  );

  Widget _metric(String value, String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 5),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(18)),
    child: Column(children: [
      Icon(icon, color: ink, size: 21),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontSize: 20,
          fontWeight: FontWeight.w800, color: deepInk)),
      const SizedBox(height: 3),
      Text(label, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: muted)),
    ]),
  );
}
