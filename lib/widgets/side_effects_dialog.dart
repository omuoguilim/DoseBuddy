import 'package:flutter/material.dart';
import '../models/medication.dart';

class SideEffectsDialog extends StatefulWidget {
  final Medication medication;
  final DateTime? takenDate;
  final String? takenTime;

  const SideEffectsDialog({
    super.key, 
    required this.medication,
    this.takenDate,
    this.takenTime,
  });

  @override
  State<SideEffectsDialog> createState() => _SideEffectsDialogState();
}

class _SideEffectsDialogState extends State<SideEffectsDialog> {
  final List<String> _commonSideEffects = [
    'Anxiety', 'Appetite changes', 'Bloating', 'Blurred vision',
    'Constipation', 'Diarrhea', 'Dizziness', 'Drowsiness', 'Dry mouth',
    'Fatigue', 'Headache', 'Heartburn', 'Insomnia', 'Itching',
    'Joint pain', 'Mood changes', 'Muscle pain', 'Nausea', 'None',
    'Other', 'Rash', 'Stomach pain', 'Sweating', 'Vomiting',
  ];

  String _query = '';
  bool _saving = false;
  String _severity = 'Mild';
  DateTime? _onset;
  final _duration = TextEditingController();
  final Set<String> _selectedEffects = {};
  final TextEditingController _notesController = TextEditingController();

  Future<void> _submit() async {
    if (_selectedEffects.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a symptom or None.'))); return; }
    if (_duration.text.isNotEmpty && (int.tryParse(_duration.text) == null || int.parse(_duration.text) < 0)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duration must be a nonnegative number of minutes.'))); return; }
    if (_saving) return;
    setState(() => _saving = true);
    //Creates side effect log
    final log = {
      'timestamp': DateTime.now().toIso8601String(),
      'takenDate': widget.takenDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'takenTime': widget.takenTime ?? 'Unknown',
      'effects': _selectedEffects.toList(),
      'notes': _notesController.text,
      'severity': _severity,
      'source': 'patient-reported',
      'onset': _onset?.toIso8601String(),
      'durationMinutes': int.tryParse(_duration.text),
    };

    //Adds to medication's side effects list
    widget.medication.sideEffects ??= [];
    widget.medication.sideEffects!.add(log);
    try { await widget.medication.save(); if (mounted) Navigator.pop(context, true); }
    catch (_) { widget.medication.sideEffects!.remove(log); if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save symptom record. Please retry.'))); } }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B67CA).withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      color: Color(0xFF5B67CA),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'How do you feel?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Reported alongside ${widget.medication.name}${widget.takenTime != null ? ' at ${widget.takenTime}' : ''}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Symptoms you noticed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1D2E),
                ),
              ),
              const SizedBox(height: 12),
              TextField(decoration: const InputDecoration(labelText: 'Search symptoms'), onChanged: (v) => setState(() => _query = v.toLowerCase())),
              DropdownButtonFormField<String>(value: _severity, decoration: const InputDecoration(labelText: 'Severity'), items: ['Mild', 'Moderate', 'Severe'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _severity = v!)),
              TextButton(onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(context: context, initialDate: _onset ?? now, firstDate: DateTime(2000), lastDate: now);
                if (d == null || !mounted) return;
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_onset ?? now));
                if (t == null || !mounted) return;
                final stamp = DateTime(d.year,d.month,d.day,t.hour,t.minute);
                if (stamp.isAfter(DateTime.now())) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onset cannot be in the future.'))); return; }
                setState(() => _onset = stamp);
              }, child: Text(_onset == null ? 'Add symptom onset (optional)' : 'Onset: $_onset')),
              TextField(controller: _duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration in minutes (optional)')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonSideEffects.where((e) => e.toLowerCase().contains(_query)).map((effect) {
                  final isSelected = _selectedEffects.contains(effect);
                  final isNone = effect == 'None';
                  
                  return FilterChip(
                    label: Text(effect),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (isNone && selected) {
                          _selectedEffects.clear();
                          _selectedEffects.add('None');
                        } else if (selected) {
                          _selectedEffects.remove('None');
                          _selectedEffects.add(effect);
                        } else {
                          _selectedEffects.remove(effect);
                        }
                      });
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: const Color(0xFF5B67CA).withAlpha(51),
                    checkmarkColor: const Color(0xFF5B67CA),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF5B67CA) : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Additional notes (optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1D2E),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'How are you feeling overall?',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _duration.dispose();
    super.dispose();
  }
}
