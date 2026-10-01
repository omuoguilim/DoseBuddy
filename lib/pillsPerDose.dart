import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'models/medication.dart';
import 'services/notification_services.dart';

class AddMedicationPage extends StatefulWidget {
  const AddMedicationPage({super.key});

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  final _totalPillsController = TextEditingController();
  final _refillThresholdController = TextEditingController();
  final _pillsPerDoseController = TextEditingController(text: '1'); // NEW
  final List<String> _selectedTimes = [];
  bool _trackRefills = false;

  Future<void> _scanPrescription() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Scanning prescription...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) Navigator.pop(context);

    setState(() {
      _nameController.text = 'Amoxicillin';
      _dosageController.text = '500mg';
      _notesController.text = 'Take with food. Complete full course.';
      _selectedTimes.clear();
      _selectedTimes.addAll(['8:00 AM', '2:00 PM', '8:00 PM']);
      _trackRefills = true;
      _totalPillsController.text = '30';
      _refillThresholdController.text = '10';
      _pillsPerDoseController.text = '2'; // Demo: 2 pills per dose
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Prescription scanned successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
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

  Future<void> _saveMedication() async {
    if (_nameController.text.isEmpty || _dosageController.text.isEmpty || _selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    //Parse pills per dose
    int pillsPerDose = int.tryParse(_pillsPerDoseController.text) ?? 1;
    if (pillsPerDose < 1) pillsPerDose = 1;

    //Parse refill tracking
    int? totalPills;
    int? refillThreshold;
    
    if (_trackRefills && _totalPillsController.text.isNotEmpty) {
      totalPills = int.tryParse(_totalPillsController.text);
      if (_refillThresholdController.text.isNotEmpty) {
        refillThreshold = int.tryParse(_refillThresholdController.text);
      } else {
        refillThreshold = (totalPills! * 0.25).round();
      }
    }

    final medication = Medication(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      dosage: _dosageController.text,
      times: _selectedTimes,
      notes: _notesController.text,
      totalPills: totalPills,
      pillsRemaining: totalPills,
      refillThreshold: refillThreshold,
      lastRefillDate: totalPills != null ? DateTime.now() : null,
      pillsPerDose: pillsPerDose, //Set pills per dose
    );

    final box = Hive.box<Medication>('medications');
    await box.put(medication.id, medication);

    await NotificationService().scheduleMedicationNotifications(medication);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medication added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Medication'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Scanner Button
            GestureDetector(
              onTap: _scanPrescription,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF5B67CA),
                      const Color(0xFF9B8CE8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF5B67CA).withAlpha(77),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.camera_alt, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Scan Prescription',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR ENTER MANUALLY',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),
            
            const SizedBox(height: 24),
            
            //Medication Name
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

            //Dosage
            const Text(
              'Dosage *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dosageController,
              decoration: InputDecoration(
                hintText: 'e.g., 200mg',
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

            // NEW: Pills Per Dose
            const Text(
              'Pills Per Dose *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pillsPerDoseController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'How many pills to take each time (e.g., 2)',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.medication_liquid, color: Color(0xFF5B67CA)),
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

            //Times
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

            //Notes
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
                          children: const [
                            Text(
                              'Track Refills',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1D2E),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
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
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            //Save button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveMedication,
                child: const Text(
                  'Save Medication',
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
    _pillsPerDoseController.dispose();
    super.dispose();
  }
}