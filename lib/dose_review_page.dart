import 'demo/demo_mode.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/medication.dart';
import 'services/notification_services.dart';

class DoseReviewPage extends StatefulWidget {
  final Medication? medication;
  final DateTime? date;
  final String? time;
  final String initialState;
  const DoseReviewPage({super.key, this.medication, this.date, this.time, this.initialState = 'taken'});
  @override
  State<DoseReviewPage> createState() => _DoseReviewPageState();
}
class _DoseReviewPageState extends State<DoseReviewPage> {
  bool _history = false;
  @override
  void initState() { super.initState(); if(widget.medication != null && widget.date != null && widget.time != null) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _record(widget.medication!,widget.date!,widget.time!,initialState:widget.initialState); }); }

  Future<void> _record(Medication med, DateTime date, String time, {String initialState = 'taken'}) async {
    final reason = TextEditingController();
    String state = initialState;
    DateTime actual = DateTime.now();
    final result = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, update) => AlertDialog(
      title: Text('${med.name}: $time'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Record what happened. This does not advise whether to take a missed dose.'),
        DropdownButtonFormField<String>(value: state, items: const [DropdownMenuItem(value: 'taken', child: Text('Taken')), DropdownMenuItem(value: 'missed', child: Text('Missed')), DropdownMenuItem(value: 'skipped', child: Text('Intentionally skipped')), DropdownMenuItem(value: 'unknown', child: Text('Not sure'))], onChanged: (v) => update(() => state = v!)),
        if (state == 'taken') TextButton(onPressed: () async {
          final d = await showDatePicker(context: c, initialDate: actual, firstDate: med.createdAt, lastDate: DateTime.now());
          if (d == null || !c.mounted) return;
          final t = await showTimePicker(context: c, initialTime: TimeOfDay.fromDateTime(actual));
          if (t != null) update(() => actual = DateTime(d.year, d.month, d.day, t.hour, t.minute));
        }, child: Text('Actual time: ${actual.toLocal().toString().substring(0, 16)}')),
        TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason / correction note (optional)')),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save record'))],
    )));
    if (result == true) {
      if (actual.isAfter(DateTime.now()) && state == 'taken') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actual taken time cannot be in the future.')));
      } else { med.recordDose(date, time, state, reason: reason.text.trim(), actualTime: actual); await med.save(); try { await NotificationService().rescheduleAll(); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record saved. Reminder refresh failed; check reminder health.'))); } }
    }
    reason.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Medication>(DemoMode.boxName);
    return Scaffold(appBar: AppBar(title: const Text('Dose review'), actions: [TextButton(onPressed: () => setState(() => _history = !_history), child: Text(_history ? 'Unresolved' : 'History'))]),
      body: ValueListenableBuilder(valueListenable: box.listenable(), builder: (context, box, _) {
        final rows = <Widget>[];
        final now = DateTime.now();
        for (int i = 0; i < 30; i++) {
          final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
          for (final med in box.values) {
            if (!med.isScheduledFor(date)) continue;
            for (final time in med.timesFor(date)) {
              if (med.scheduledAt(date, time).isAfter(now)) continue;
              final records = med.takenLog?.where((l) => l['date'] == date.toIso8601String().substring(0, 10) && l['scheduledTime'] == time).toList() ?? [];
              final state = records.isEmpty ? 'Not recorded' : records.first['state'] ?? 'taken';
              if (!_history && state != 'Not recorded' && state != 'unknown') continue;
              rows.add(Card(child: ListTile(title: Text('${med.name} · $time'), subtitle: Text('${date.toIso8601String().substring(0, 10)} · $state'), trailing: IconButton(tooltip: 'Snooze 10 minutes', icon: const Icon(Icons.snooze), onPressed: () async { if(DemoMode.enabled){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Snooze is a phone feature. This practice demo does not deliver notifications.')));return;} try { await NotificationService().snooze(med, time, 10); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder snoozed for ten minutes.'))); } catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not snooze. Check reminder settings.'))); } }), onTap: () => _record(med, date, time))));
              if (_history && records.isNotEmpty) {
                for (final change in (records.first['corrections'] as List? ?? [])) {
                  rows.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text('Previous: ${change['state']} · corrected ${change['changedAt']}')));
                }
              }
            }
          }
        }
        return ListView(padding: const EdgeInsets.all(16), children: [const Text('Review the last 30 days. A missing record does not mean a dose was missed.'), const SizedBox(height: 12), if (rows.isEmpty) const Text('No doses to review.'), ...rows]);
      }));
  }
}
