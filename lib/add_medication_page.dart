import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'models/medication.dart';
import 'services/notification_services.dart';
import 'widgets/prescription_review.dart';
import 'widgets/strength_field.dart';
import 'reminder_health_page.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AddMedicationPage extends StatefulWidget {
  final bool scanOnOpen;
  const AddMedicationPage({super.key, this.scanOnOpen = false});

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  final _totalPillsController = TextEditingController();
  final _refillThresholdController = TextEditingController();
  final List<String> _selectedTimes = [];
  bool _trackRefills = false;
  String _strengthUnit = 'mg';
  bool _saving = false, _draftFinished = false, _restoring = true;
  String? _nameError, _strengthError;
  Timer? _draftTimer;
  int _step = 0;
  String? _scheduleError, _countError;
  @override
  void initState() {
    super.initState();
    for (final c in [_nameController,_dosageController,_notesController,_totalPillsController,_refillThresholdController]) { c.addListener(_queueDraft); }
    _restoreDraft();
  }
  void _queueDraft(){ if(_restoring || _draftFinished)return; _draftTimer?.cancel(); _draftTimer=Timer(const Duration(milliseconds:500),_saveDraft); }
  Future<void> _saveDraft() async {
    if(_draftFinished || _restoring)return;
    final data={'name':_nameController.text,'strength':_dosageController.text,'unit':_strengthUnit,'notes':_notesController.text,'times':_selectedTimes.toList(),'track':_trackRefills,'total':_totalPillsController.text,'threshold':_refillThresholdController.text};
    final p=await SharedPreferences.getInstance();
    if(_draftFinished)return;
    if(data['name']==''&&data['strength']==''&&data['notes']==''&&_selectedTimes.isEmpty){await p.remove('medication_draft');return;}
    await p.setString('medication_draft',jsonEncode(data));
  }
  Future<void> _restoreDraft()async{
    final p=await SharedPreferences.getInstance();final raw=p.getString('medication_draft');
    if(!mounted)return;
    if(raw!=null){try{final d=jsonDecode(raw) as Map;_nameController.text=d['name'] as String? ?? '';_dosageController.text=d['strength'] as String? ?? '';_strengthUnit=d['unit'] as String? ?? 'mg';_notesController.text=d['notes'] as String? ?? '';_selectedTimes.addAll((d['times'] as List? ?? []).cast<String>());_trackRefills=d['track']==true;_totalPillsController.text=d['total'] as String? ?? '';_refillThresholdController.text=d['threshold'] as String? ?? '';}catch(_){await p.remove('medication_draft');}}
    if(!mounted)return;setState(()=>_restoring=false);
    if(widget.scanOnOpen)await _scanPrescription();
  }


  Future<void> _scanPrescription() async {
    final result = await Navigator.push<Map<String, String>>(context, MaterialPageRoute(builder: (_) => const PrescriptionReviewPage()));
    if (result == null || !mounted) return;
    setState(() {
      _nameController.text = result['name'] ?? '';
      _dosageController.text = result['strength'] ?? '';
      _strengthUnit = result['unit'] ?? 'mg';
      _notesController.text = result['directions'] ?? '';
    });
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
    if(_saving || _restoring)return;
    setState(()=>_saving=true);
    try { await _performSave(); }
    catch (_) { if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not save this medication. Your draft is retained.'))); }
    finally { if(mounted)setState(()=>_saving=false); }
  }
  Future<void> _performSave() async {




    setState(() { _nameError = _nameController.text.trim().isEmpty ? 'Enter the medication name' : null; _strengthError = _dosageController.text.trim().isEmpty ? 'Enter its strength' : null; });
    if (_nameError != null || _strengthError != null || _selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    //Parse refill tracking
    int? totalPills;
    int? refillThreshold;
    
    if (_trackRefills && _totalPillsController.text.isNotEmpty) {
      totalPills = int.tryParse(_totalPillsController.text);
      if (totalPills == null || totalPills <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid positive pill count.')),
        );
        return;
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

    if (double.tryParse(_dosageController.text.trim()) == null || double.parse(_dosageController.text.trim()) <= 0 || !double.parse(_dosageController.text.trim()).isFinite) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a positive numeric strength.')));
      return;
    }
    final existing = Hive.box<Medication>('medications').values.any((m) => m.name.trim().toLowerCase() == _nameController.text.trim().toLowerCase());
    if (existing) {
      final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Medication already listed'), content: const Text('Check that this is a separate prescription before adding another entry.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Go back')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add separate entry'))]));
      if (confirmed != true || !mounted) return;
    }
    final medication = Medication(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      dosage: '${_dosageController.text.trim()} $_strengthUnit',
      times: _selectedTimes,
      notes: _notesController.text,
      totalPills: totalPills,
      pillsRemaining: totalPills, // Start with full bottle
      refillThreshold: refillThreshold,
      lastRefillDate: totalPills != null ? DateTime.now() : null,
    );

    final box = Hive.box<Medication>('medications');
    await box.put(medication.id, medication);
    _draftFinished=true;_draftTimer?.cancel();
    final prefs=await SharedPreferences.getInstance();await prefs.remove('medication_draft');
    bool reminderSaved=true;
    try { await NotificationService().scheduleMedicationNotifications(medication); } catch (_) { reminderSaved=false; }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(reminderSaved ? 'Medication saved' : 'Medication saved. Check Reminder Health to rebuild reminders.')),
      );
      Navigator.pop(context, true);
    }
  }

  void _continueStep() {
    if (_step == 0) {
      final strength = double.tryParse(_dosageController.text.trim());
      setState(() { _nameError = _nameController.text.trim().isEmpty ? 'Enter the medication name' : null; _strengthError = strength == null || strength <= 0 || !strength.isFinite ? 'Enter a positive numeric strength' : null; });
      if (_nameError != null || _strengthError != null) return;
    }
    if (_step == 1) {
      final total = int.tryParse(_totalPillsController.text);
      final threshold = int.tryParse(_refillThresholdController.text);
      setState(() { _scheduleError = _selectedTimes.isEmpty ? 'Add at least one scheduled time' : null; _countError = _trackRefills && (total == null || total <= 0 || (_refillThresholdController.text.isNotEmpty && (threshold == null || threshold < 0 || threshold > total))) ? 'Enter a positive bottle count and a threshold between zero and that count' : null; });
      if (_scheduleError != null || _countError != null) return;
    }
    if (_step < 2) { setState(() => _step++); _saveDraft(); } else { _saveMedication(); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add medication')),
    body: _restoring ? const Center(child: CircularProgressIndicator()) : Stepper(
      currentStep: _step,
      onStepTapped: (i) { if (i < _step) setState(() => _step = i); },
      controlsBuilder: (context, details) => Padding(padding: const EdgeInsets.only(top: 20), child: Wrap(spacing: 12, runSpacing: 8, children: [
        ElevatedButton(onPressed: _saving ? null : _continueStep, child: Text(_saving ? 'Saving…' : _step == 2 ? 'Save medication' : 'Continue')),
        if (_step > 0) TextButton(onPressed: _saving ? null : () => setState(() => _step--), child: const Text('Back')),
      ])),
      steps: [
        Step(title: const Text('Medication details'), isActive: _step >= 0, state: _step > 0 ? StepState.complete : StepState.indexed, content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          OutlinedButton.icon(onPressed: _scanPrescription, icon: const Icon(Icons.document_scanner_outlined), label: const Text('Scan prescription label')),
          const SizedBox(height: 12), const Text('Or enter the details manually. Check any scan suggestions against your label.'), const SizedBox(height: 16),
          TextField(controller: _nameController, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Medication name', errorText: _nameError)), const SizedBox(height: 16),
          StrengthField(controller: _dosageController, unit: _strengthUnit, error: _strengthError, onUnitChanged: (v) { setState(() => _strengthUnit = v); _saveDraft(); }), const SizedBox(height: 12),
          const Text('Strength is separate from how much you take. Record the instructions you were given.'), const SizedBox(height: 12),
          TextField(controller: _notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Label instructions / notes')),
        ])),
        Step(title: const Text('Schedule and reminders'), isActive: _step >= 1, state: _step > 1 ? StepState.complete : StepState.indexed, content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add the times on your prescribed schedule. Flexible weekdays, pauses and as-needed use are available under Schedule / archive after saving.'), const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final time in _selectedTimes) InputChip(label: Text(time), onDeleted: () { _removeTime(time); _saveDraft(); })]),
          TextButton.icon(onPressed: _addTime, icon: const Icon(Icons.add), label: const Text('Add scheduled time')),
          if (_scheduleError != null) Text(_scheduleError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const Divider(height: 24),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Track bottle inventory'), value: _trackRefills, onChanged: (v) { setState(() => _trackRefills = v); _saveDraft(); }),
          if (_trackRefills) ...[
            TextField(controller: _totalPillsController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Pills in this bottle', errorText: _countError)), const SizedBox(height: 12),
            TextField(controller: _refillThresholdController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Low-stock alert at (optional)', helperText: 'Default: 25% of the bottle count')),
          ], const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReminderHealthPage())), icon: const Icon(Icons.notifications_outlined), label: const Text('Reminder permissions / privacy')),
        ])),
        Step(title: const Text('Review before saving'), isActive: _step >= 2, content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_nameController.text.trim(), style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8), Text('Strength: ${_dosageController.text.trim()} $_strengthUnit'),
            Text('Schedule: ${_selectedTimes.join(', ')}'), if (_notesController.text.trim().isNotEmpty) Text('Instructions: ${_notesController.text.trim()}'),
            Text(_trackRefills ? 'Inventory: ${_totalPillsController.text} pills' : 'Inventory tracking off'),
          ]))), const SizedBox(height: 12),
          const Text('Confirm these details against your label or prescribed instructions. This is your record, not a dosing recommendation. Your draft is retained if you leave before saving.'),
        ])),
      ],
    ),
  );

  @override
  void dispose() {
    _draftTimer?.cancel();
    _saveDraft();
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _totalPillsController.dispose();
    _refillThresholdController.dispose();
    super.dispose();
  }
}
