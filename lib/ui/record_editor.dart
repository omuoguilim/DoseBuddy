import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/records.dart';
import '../core/store.dart';
import '../core/reminders.dart';
import 'theme.dart';

Future<DateTime?> pickRecordTime(BuildContext context, DateTime initial) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial.isAfter(now) ? now : initial,
    firstDate: DateTime(2000),
    lastDate: now,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  return time == null
      ? null
      : DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class RecordEditor extends StatefulWidget {
  final AppStore store;
  final Reminders reminders;
  final ScheduledDose dose;
  final bool prn;
  const RecordEditor({
    super.key,
    required this.store,
    required this.reminders,
    required this.dose,
    this.prn = false,
  });
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  late TextEditingController amount, reason;
  late DateTime actual;
  String status = 'Taken';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final r = widget.store.records.outcomes[widget.dose.key] as Json?;
    amount = TextEditingController(
      text: '${r?['amount'] ?? widget.dose.details['amount']}',
    );
    reason = TextEditingController(text: r?['reason'] as String? ?? '');
    actual = r?['takenAt'] == null
        ? DateTime.now()
        : DateTime.parse(r!['takenAt'] as String);
    status = r?['status'] as String? ?? 'Taken';
  }

  @override
  void dispose() {
    amount.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> save({bool undo = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.store.update((r) {
        if (undo) {
          r.undo(widget.dose.key, DateTime.now());
        } else {
          r.record(
            widget.dose,
            status: status,
            now: DateTime.now(),
            takenAt: actual,
            amount: num.parse(amount.text),
            reason: reason.text.trim(),
            prn: widget.prn,
          );
        }
      });
      await widget.reminders.sync(widget.store.records);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dose;
    final existing = widget.store.records.outcomes.containsKey(d.key);
    return Scaffold(
      appBar: AppBar(
        title: Text(existing ? 'Correct dose record' : 'Record dose'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            d.details['name'] as String,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            '${d.details['strength']} • ${d.details['amount']} ${d.details['unit']}',
          ),
          if (!widget.prn)
            Text(
              'Scheduled ${dayKey(d.at)} at ${clockLabel(d.at.hour * 60 + d.at.minute)}',
            ),
          if (d.at.isAfter(DateTime.now()) && !widget.prn)
            const Notice(
              'This dose is scheduled for later. Record only what you already took; this screen is not advice to take it early.',
            ),
          const SizedBox(height: 20),
          if (!widget.prn)
            SegmentedButton<String>(
              segments: [
                const ButtonSegment(value: 'Taken', label: Text('Taken')),
                if (!widget.prn)
                  const ButtonSegment(value: 'Skipped', label: Text('Skipped')),
              ],
              selected: {status},
              onSelectionChanged: busy
                  ? null
                  : (s) => setState(() => status = s.first),
            ),
          const SizedBox(height: 20),
          if (status == 'Taken') ...[
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount taken (${d.details['unit']})',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Actually taken at'),
              subtitle: Text(
                '${dayKey(actual)} ${clockLabel(actual.hour * 60 + actual.minute)}',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final t = await pickRecordTime(context, actual);
                if (t != null) setState(() => actual = t);
              },
            ),
          ],
          TextField(
            controller: reason,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: status == 'Skipped'
                  ? 'Reason for skipping'
                  : 'Notes (optional)',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : () => save(),
            child: Text(busy ? 'Saving…' : 'Save record'),
          ),
          if (existing) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: busy ? null : () => save(undo: true),
              child: const Text('Remove this record'),
            ),
          ],
          const Notice(
            'Follow your prescription. Ask your pharmacist or clinician about missed doses or timing changes. A record correction changes your log, not what you should take.',
          ),
        ],
      ),
    );
  }
}

class SymptomEditor extends StatefulWidget {
  final AppStore store;
  final String? id;
  const SymptomEditor({super.key, required this.store, this.id});
  @override
  State<SymptomEditor> createState() => _SymptomEditorState();
}

class _SymptomEditorState extends State<SymptomEditor> {
  final name = TextEditingController(), notes = TextEditingController();
  late DateTime at;
  String duration = 'Unknown';
  int severity = 3;
  String? medicationId;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final s = (widget.store.data['symptoms'] as Json)[widget.id] as Json?;
    name.text = s?['name'] as String? ?? '';
    notes.text = s?['notes'] as String? ?? '';
    at = s == null ? DateTime.now() : DateTime.parse(s['at'] as String);
    duration = s?['duration'] as String? ?? 'Unknown';
    severity = s?['severity'] as int? ?? 3;
    medicationId = s?['medicationId'] as String?;
  }

  @override
  void dispose() {
    name.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save({bool remove = false}) async {
    if (busy) return;
    if (!remove && (name.text.trim().isEmpty || at.isAfter(DateTime.now()))) {
      showError(context, 'Enter a symptom and a past or present time.');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.store.update((r) {
        final all = r.data['symptoms'] as Json;
        final id = widget.id ?? const Uuid().v4();
        if (remove) {
          all.remove(id);
        } else {
          all[id] = {
            'id': id,
            'name': name.text.trim(),
            'at': at.toIso8601String(),
            'severity': severity,
            'duration': duration,
            'medicationId': medicationId,
            'notes': notes.text.trim(),
          };
        }
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meds = widget.store.records.medications;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'Log symptom' : 'Edit symptom'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Symptom'),
          ),
          const SizedBox(height: 16),
          Text('Severity: $severity of 5'),
          Slider(
            value: severity.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$severity of 5',
            onChanged: (v) => setState(() => severity = v.round()),
          ),
          const Text('1: mild · 3: moderate · 5: severe'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('When it happened'),
            subtitle: Text(
              '${dayKey(at)} ${clockLabel(at.hour * 60 + at.minute)}',
            ),
            onTap: () async {
              final t = await pickRecordTime(context, at);
              if (t != null) setState(() => at = t);
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: duration,
            decoration: const InputDecoration(labelText: 'Duration'),
            items: {
              'Unknown',
              'Ongoing',
              '15 minutes',
              '30 minutes',
              '60 minutes',
              '120 minutes',
              duration,
            }.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (s) => setState(() => duration = s!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: meds.containsKey(medicationId) ? medicationId : '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Medication context (optional)',
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Not linked')),
              ...meds.entries.map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    widget.store.records.current(e.value as Json)['name']
                        as String,
                  ),
                ),
              ),
            ],
            onChanged: (s) => setState(() => medicationId = s == '' ? null : s),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : () => save(),
            child: const Text('Save symptom'),
          ),
          if (widget.id != null)
            TextButton(
              onPressed: busy ? null : () => save(remove: true),
              child: const Text('Delete symptom'),
            ),
          const Notice(
            'Linking a medication records your observation; it does not establish a cause. This app does not monitor emergencies. Seek urgent help if you think you are having a medical emergency.',
          ),
        ],
      ),
    );
  }
}
