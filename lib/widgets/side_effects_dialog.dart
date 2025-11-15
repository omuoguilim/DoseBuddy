import 'package:flutter/material.dart';
import '../models/medication.dart';

class SideEffectsDialog extends StatefulWidget {
  final Medication medication;

  const SideEffectsDialog({super.key, required this.medication});

  @override
  State<SideEffectsDialog> createState() => _SideEffectsDialogState();
}

class _SideEffectsDialogState extends State<SideEffectsDialog> {
  final List<String> _commonSideEffects = [
    'None',
    'Nausea',
    'Headache',
    'Dizziness',
    'Drowsiness',
    'Stomach Pain',
    'Dry Mouth',
    'Fatigue',
  ];

  final Set<String> _selectedEffects = {};
  final TextEditingController _notesController = TextEditingController();

  void _submit() {
    // Create side effect log
    final log = {
      'timestamp': DateTime.now().toIso8601String(),
      'effects': _selectedEffects.toList(),
      'notes': _notesController.text,
    };

    // Add to medication's side effects list
    widget.medication.sideEffects ??= [];
    widget.medication.sideEffects!.add(log);
    widget.medication.save();

    Navigator.pop(context, true);
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
                      color: const Color(0xFF5B67CA).withOpacity(0.1),
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
                'After taking ${widget.medication.name}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Any side effects?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1D2E),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonSideEffects.map((effect) {
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
                    selectedColor: const Color(0xFF5B67CA).withOpacity(0.2),
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
                      onPressed: _submit,
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
    super.dispose();
  }
}