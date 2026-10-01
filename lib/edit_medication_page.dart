import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'models/medication.dart';
import 'widgets/strength_field.dart';
import 'services/notification_services.dart';

class EditMedicationPage extends StatefulWidget {
  final Medication medication;

  const EditMedicationPage({super.key, required this.medication});

  @override
  State<EditMedicationPage> createState() => _EditMedicationPageState();
}

class _EditMedicationPageState extends State<EditMedicationPage> {
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _notesController;
  late TextEditingController _totalPillsController;
  late TextEditingController _refillThresholdController;
  late List<String> _selectedTimes;
  late bool _trackRefills;
  String _unit = 'mg';
  bool _legacyStrength = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing data
    _nameController = TextEditingController(text: widget.medication.name);
    final strength = RegExp(r'^(\d+(?:\.\d+)?)\s*(mg/mL|mcg/mL|mcg|mg|g|mL|units|IU|%|mEq|mmol)$').firstMatch(widget.medication.dosage.trim());
    _legacyStrength = strength == null;
    _unit = strength?.group(2) ?? 'mg';
    _dosageController = TextEditingController(text: strength?.group(1) ?? widget.medication.dosage);
    _notesController = TextEditingController(text: widget.medication.notes);
    _selectedTimes = List.from(widget.medication.times);
    
    // Refill tracking
    _trackRefills = widget.medication.totalPills != null;
    _totalPillsController = TextEditingController(
      text: widget.medication.totalPills?.toString() ?? '',
    );
    _refillThresholdController = TextEditingController(
      text: widget.medication.refillThreshold?.toString() ?? '',
    );
  }

  Future<void> _addTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      final String formattedTime = _formatTimeOfDay(picked);
      if (!_selectedTimes.contains(formattedTime)) {
        setState(() {
          _selectedTimes.add(formattedTime);
          _selectedTimes.sort((a, b) => _compareTime(a, b));
        });
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  int _compareTime(String a, String b) {
    final aTime = _parseTimeString(a);
    final bTime = _parseTimeString(b);
    return aTime.compareTo(bTime);
  }

  DateTime _parseTimeString(String timeStr) {
    final parts = timeStr.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final isPM = parts[1] == 'PM';

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    return DateTime(2000, 1, 1, hour, minute);
  }

  void _removeTime(String time) {
    setState(() {
      _selectedTimes.remove(time);
    });
  }

  Future<void> _showRefillDialog() async {
    final controller = TextEditingController(
      text: widget.medication.totalPills?.toString() ?? '',
    );

    final newCount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refill Medication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How many pills are in the new bottle?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g., 30',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.inventory_2),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final count = int.tryParse(controller.text);
              Navigator.pop(context, count);
            },
            child: const Text('Refill'),
          ),
        ],
      ),
    );

    if (newCount != null && newCount > 0) {
      setState(() {
        widget.medication.refill(newCount);
        _totalPillsController.text = newCount.toString();
      });
      await widget.medication.save();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Refilled with $newCount pills'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _updateMedication() async {
    if (_nameController.text.isEmpty || _dosageController.text.isEmpty || _selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_legacyStrength && (double.tryParse(_dosageController.text) == null || double.parse(_dosageController.text) <= 0 || !double.parse(_dosageController.text).isFinite)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a positive numeric strength.'))); return;
    }
    // Parse refill tracking
    int? totalPills;
    int? pillsRemaining;
    int? refillThreshold;
    
    if (_trackRefills && _totalPillsController.text.isNotEmpty) {
      totalPills = int.tryParse(_totalPillsController.text);
      if (totalPills == null || totalPills <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid positive pill count.')),
        );
        return;
      }
      
      // Keep existing pills remaining if already tracking, otherwise set to total
      if (widget.medication.pillsRemaining != null) {
        pillsRemaining = widget.medication.pillsRemaining;
      } else {
        pillsRemaining = totalPills;
      }
      
      if (_refillThresholdController.text.isNotEmpty) {
        refillThreshold = int.tryParse(_refillThresholdController.text);
      } else {
        refillThreshold = (totalPills * 0.25).round();
      }
      if (refillThreshold == null || refillThreshold < 0 || refillThreshold > totalPills) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refill alert must be between zero and the pill count.')),
        );
        return;
      }
    }

    // Update the medication object
    await NotificationService().cancelMedicationNotifications(widget.medication);
    widget.medication.name = _nameController.text;
    widget.medication.dosage = _legacyStrength ? _dosageController.text.trim() : '${_dosageController.text.trim()} $_unit';
    widget.medication.details ??= {};
    final history = (widget.medication.details!['scheduleHistory'] as List? ?? []).toList();
    if (history.isEmpty) history.add({'effectiveAt': DateTime(widget.medication.createdAt.year, widget.medication.createdAt.month, widget.medication.createdAt.day).toIso8601String(), 'times': widget.medication.times.toList()});
    final now = DateTime.now();
    final effective = DateTime(now.year, now.month, now.day + 1);
    final snapshot = Map<String, dynamic>.from(widget.medication.scheduleFor(effective));
    snapshot.addAll({'effectiveAt': effective.toIso8601String(), 'times': _selectedTimes.toList()});
    history.removeWhere((s) => s['effectiveAt'] == effective.toIso8601String());
    history.add(snapshot);
    widget.medication.details!['scheduleHistory'] = history;
    widget.medication.times = _selectedTimes;
    widget.medication.notes = _notesController.text;
    widget.medication.totalPills = totalPills;
    widget.medication.pillsRemaining = pillsRemaining;
    widget.medication.refillThreshold = refillThreshold;
    
    // Save to Hive
    await widget.medication.save();

    await NotificationService().scheduleMedicationNotifications(widget.medication);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medication updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsRefill = widget.medication.needsRefill();
    final daysLeft = widget.medication.daysUntilOut();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Medication'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Refill Alert Banner (if needed)
            if (needsRefill)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Running Low!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.medication.pillsRemaining} pills left (~$daysLeft days)',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showRefillDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Refill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            
            const Text(
              'Medication Name *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g., Ibuprofen',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF5B67CA), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Dosage *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 8),
            if (_legacyStrength) ...[
              TextField(controller: _dosageController, decoration: const InputDecoration(labelText: 'Existing strength / instructions')),
              TextButton(onPressed: () => setState(() { _legacyStrength = false; _dosageController.clear(); }), child: const Text('Use numeric strength and unit')),
            ] else StrengthField(controller: _dosageController, unit: _unit, onUnitChanged: (v) => setState(() => _unit = v)),
            const Text('Strength is separate from how many tablets or mL you take. Schedule changes apply tomorrow.'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scheduled Times *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D2E),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addTime,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Time'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5B67CA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedTimes.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Center(
                  child: Text(
                    'No times added yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedTimes.map((time) {
                  return Chip(
                    label: Text(time),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeTime(time),
                    backgroundColor: Color(0xFF5B67CA).withAlpha(26),
                    labelStyle: const TextStyle(
                      color: Color(0xFF5B67CA),
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
            const Text(
              'Notes (Optional)',
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
                hintText: 'e.g., Take with food',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF5B67CA), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Refill Tracking Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(13),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _trackRefills ? Colors.orange : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: _trackRefills ? Colors.orange : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Track Refills',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1D2E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_trackRefills && widget.medication.pillsRemaining != null)
                              Text(
                                '${widget.medication.pillsRemaining} pills remaining',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF718096),
                                ),
                              )
                            else
                              const Text(
                                'Get alerts when running low',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF718096),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _trackRefills,
                        onChanged: (value) {
                          setState(() {
                            _trackRefills = value;
                          });
                        },
                        activeThumbColor: Colors.orange,
                      ),
                    ],
                  ),
                  
                  if (_trackRefills) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Total Pills in Bottle',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _totalPillsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g., 30',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.orange, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Alert When Below (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _refillThresholdController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g., 10 (leave empty for 25% of total)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.orange, width: 2),
                        ),
                      ),
                    ),
                    
                    if (widget.medication.pillsRemaining != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showRefillDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Mark as Refilled'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _updateMedication,
                child: const Text(
                  'Update Medication',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _totalPillsController.dispose();
    _refillThresholdController.dispose();
    super.dispose();
  }
}
