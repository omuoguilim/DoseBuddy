import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/records.dart';
import '../core/store.dart';
import '../core/reminders.dart';
import 'theme.dart';

class MedicationEditor extends StatefulWidget {
  final AppStore store;
  final Reminders reminders;
  final String? id;
  final Json? draft;
  const MedicationEditor({
    super.key,
    required this.store,
    required this.reminders,
    this.id,
    this.draft,
  });
  @override
  State<MedicationEditor> createState() => _MedicationEditorState();
}

class _MedicationEditorState extends State<MedicationEditor> {
  final formKey = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late Json value;
  bool supply = false, busy = false;
  bool verified = false;
  @override
  void initState() {
    super.initState();
    final r = widget.store.records;
    final med = widget.id == null ? null : r.medications[widget.id] as Json?;
    value = med == null
        ? {
            'name': '',
            'strength': '',
            'amount': 1,
            'unit': 'tablet',
            'form': 'Tablet',
            'type': 'scheduled',
            'times': <int>[],
            'start': dayKey(DateTime.now()),
            'end': null,
            'active': true,
            'instructions': '',
            'food': 'No preference',
            'notes': '',
            'reason': '',
            'prescriber': '',
            'pharmacy': '',
          }
        : r.current(med);
    value.addAll(widget.draft ?? {});
    for (final k in [
      'name',
      'strength',
      'amount',
      'instructions',
      'notes',
      'reason',
      'prescriber',
      'pharmacy',
    ]) {
      fields[k] = TextEditingController(text: '${value[k] ?? ''}');
    }
    fields['supply'] = TextEditingController(
      text: '${med?['supply'] ?? widget.draft?['quantity'] ?? ''}',
    );
    fields['threshold'] = TextEditingController(
      text: '${med?['threshold'] ?? ''}',
    );
    supply = fields['supply']!.text.isNotEmpty;
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !formKey.currentState!.validate()) return;
    if (widget.draft != null && !verified) {
      showError(
        context,
        'Confirm the details against the original label first.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      for (final k in [
        'name',
        'strength',
        'instructions',
        'notes',
        'reason',
        'prescriber',
        'pharmacy',
      ]) {
        value[k] = fields[k]!.text.trim();
      }
      value['amount'] = num.parse(fields['amount']!.text);
      if (value['type'] == 'as_needed') value['times'] = <int>[];
      final quantity = supply ? num.parse(fields['supply']!.text) : null;
      final threshold = supply && fields['threshold']!.text.isNotEmpty
          ? num.parse(fields['threshold']!.text)
          : null;
      await widget.store.update(
        (r) => r.saveMedication(
          widget.id ?? const Uuid().v4(),
          value,
          DateTime.now(),
          supply: quantity,
          threshold: threshold,
        ),
      );
      await widget.reminders.sync(widget.store.records);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget input(
    String key,
    String label, {
    bool required = false,
    bool number = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
      maxLines: lines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (text) {
        final s = text?.trim() ?? '';
        if (required && s.isEmpty) return 'Required';
        if (number && s.isNotEmpty) {
          final n = num.tryParse(s);
          if (n == null || !n.isFinite || n < 0 || (key == 'amount' && n == 0))
            return 'Enter a valid ${key == 'amount' ? 'positive ' : 'nonnegative '}number';
        }
        return null;
      },
    ),
  );
  Widget choice(String key, String label, List<String> options) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: options.contains(value[key])
          ? value[key] as String
          : options.last,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((x) => DropdownMenuItem(value: x, child: Text(x)))
          .toList(),
      onChanged: busy ? null : (x) => setState(() => value[key] = x),
    ),
  );
  Future<void> date(String key) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.parse((value[key] ?? value['start']) as String),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => value[key] = dayKey(d));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.id == null ? 'Add medication' : 'Edit medication'),
    ),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.id != null)
            const Notice(
              'Changes apply from the time you save. Earlier dose records keep their original medication details.',
            ),
          if (widget.draft != null)
            const Notice(
              'This is an unverified label transcription. Confirm the complete strength, amount, units, and schedule against your prescription.',
            ),
          Section(
            'Medication',
            Column(
              children: [
                input('name', 'Medication name', required: true),
                input(
                  'strength',
                  'Complete strength, including concentration',
                  required: true,
                ),
                choice('form', 'Form', [
                  'Tablet',
                  'Capsule',
                  'Liquid',
                  'Injection',
                  'Inhaler',
                  'Patch',
                  'Cream',
                  'Drops',
                  'Other',
                ]),
                input('reason', 'Reason (optional)'),
              ],
            ),
          ),
          Section(
            'Amount and schedule',
            Column(
              children: [
                input(
                  'amount',
                  'Amount per dose',
                  required: true,
                  number: true,
                ),
                choice('unit', 'Amount unit', [
                  'tablet',
                  'capsule',
                  'mL',
                  'puff',
                  'drop',
                  'patch',
                  'gram',
                  'unit (verify)',
                ]),
                choice('type', 'Routine', ['scheduled', 'as_needed']),
                if (value['type'] == 'scheduled') ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Daily at these times. For other frequencies, do not approximate your prescription.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...(value['times'] as List).cast<int>().map(
                        (m) => InputChip(
                          label: Text(clockLabel(m)),
                          onDeleted: busy
                              ? null
                              : () => setState(
                                  () => (value['times'] as List).remove(m),
                                ),
                        ),
                      ),
                      ActionChip(
                        label: const Text('Add time'),
                        avatar: const Icon(Icons.add),
                        onPressed: busy
                            ? null
                            : () async {
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (t != null) {
                                  final m = t.hour * 60 + t.minute;
                                  setState(() {
                                    if (!(value['times'] as List).contains(m))
                                      (value['times'] as List).add(m);
                                    (value['times'] as List).sort();
                                  });
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start date'),
                  subtitle: Text(value['start'] as String),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => date('start'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Last day of course (inclusive)'),
                  subtitle: Text(value['end'] as String? ?? 'No end date'),
                  trailing: value['end'] == null
                      ? const Icon(Icons.calendar_today)
                      : IconButton(
                          tooltip: 'Remove end date',
                          onPressed: () => setState(() => value['end'] = null),
                          icon: const Icon(Icons.clear),
                        ),
                  onTap: () => date('end'),
                ),
              ],
            ),
          ),
          Section(
            'Prescription directions',
            Column(
              children: [
                choice('food', 'Food instructions', [
                  'No preference',
                  'With food',
                  'Without food',
                  'Before food',
                  'After food',
                ]),
                input(
                  'instructions',
                  'Directions from your prescription',
                  lines: 3,
                ),
                input('notes', 'Personal notes', lines: 2),
              ],
            ),
          ),
          Section(
            'Supply',
            Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Track remaining supply'),
                  subtitle: Text(
                    'Measured in ${value['unit']}. Logged doses reduce this estimate.',
                  ),
                  value: supply,
                  onChanged: busy ? null : (v) => setState(() => supply = v),
                ),
                if (supply) ...[
                  input(
                    'supply',
                    'Current remaining amount',
                    required: true,
                    number: true,
                  ),
                  input('threshold', 'Show low-supply notice at', number: true),
                ],
              ],
            ),
          ),
          Section(
            'Care details',
            Column(
              children: [
                input('prescriber', 'Prescriber (optional)'),
                input('pharmacy', 'Pharmacy (optional)'),
              ],
            ),
          ),
          if (widget.draft != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: verified,
              onChanged: (v) => setState(() => verified = v ?? false),
              title: const Text(
                'I checked every field against the original prescription label.',
              ),
            ),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'Saving…' : 'Save medication'),
          ),
        ],
      ),
    ),
  );
}
