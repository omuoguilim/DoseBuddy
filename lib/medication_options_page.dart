import 'package:flutter/material.dart';
import 'models/medication.dart';
import 'services/notification_services.dart';

class MedicationOptionsPage extends StatefulWidget {
  final Medication medication;
  const MedicationOptionsPage({super.key, required this.medication});
  @override
  State<MedicationOptionsPage> createState() => _MedicationOptionsPageState();
}
class _MedicationOptionsPageState extends State<MedicationOptionsPage> {
  final _pharmacy = TextEditingController(), _phone = TextEditingController(), _prescriber = TextEditingController(), _prescriberPhone = TextEditingController(), _instructions = TextEditingController(), _refills = TextEditingController();
  String _kind = 'Prescription';
  bool _paused = false, _archived = false, _asNeeded = false;
  int _interval = 1;
  Set<int> _weekdays = {1,2,3,4,5,6,7};
  DateTime? _start, _end;
  @override
  void initState() {
    super.initState(); final d = widget.medication.details ?? {}; final s = widget.medication.scheduleFor(DateTime.now());
    _pharmacy.text = d['pharmacy'] as String? ?? ''; _phone.text = d['pharmacyPhone'] as String? ?? ''; _prescriber.text = d['prescriber'] as String? ?? ''; _prescriberPhone.text = d['prescriberPhone'] as String? ?? ''; _instructions.text = d['instructions'] as String? ?? ''; _refills.text = '${d['prescriptionRefills'] ?? ''}'; _kind = d['kind'] as String? ?? 'Prescription';
    _paused = s['paused'] == true; _archived = s['archived'] == true; _asNeeded = s['asNeeded'] == true; _interval = s['intervalDays'] as int? ?? 1;
    _weekdays = (s['weekdays'] as List? ?? [1,2,3,4,5,6,7]).cast<int>().toSet(); _start = DateTime.tryParse(s['start'] as String? ?? ''); _end = DateTime.tryParse(s['end'] as String? ?? '');
  }
  Future<void> _save() async {
    if (_end != null && _start != null && _end!.isBefore(_start!)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date must follow start date.'))); return; }
    if (!_asNeeded && _weekdays.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one weekday.'))); return; }
    if (_refills.text.isNotEmpty && (int.tryParse(_refills.text) == null || int.parse(_refills.text) < 0)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refills must be a whole number of zero or more.'))); return; }
    final m = widget.medication; m.details ??= {};
    m.details!.addAll({'pharmacy': _pharmacy.text.trim(), 'pharmacyPhone': _phone.text.trim(), 'prescriber': _prescriber.text.trim(), 'prescriberPhone': _prescriberPhone.text.trim(), 'instructions': _instructions.text.trim(), 'kind': _kind, 'prescriptionRefills': int.tryParse(_refills.text)});
    final history = (m.details!['scheduleHistory'] as List? ?? []).toList();
    if (history.isEmpty) history.add({'effectiveAt': DateTime(m.createdAt.year,m.createdAt.month,m.createdAt.day).toIso8601String(), 'times': m.times.toList()});
    // Changes start tomorrow so today's scheduled records are never rewritten.
    final now = DateTime.now(); final effective = DateTime(now.year,now.month,now.day+1);
    history.removeWhere((s) => s['effectiveAt'] == effective.toIso8601String());
    history.add({'effectiveAt': effective.toIso8601String(), 'times': m.times.toList(), 'paused': _paused, 'archived': _archived, 'asNeeded': _asNeeded, 'start': _start?.toIso8601String(), 'end': _end?.toIso8601String(), 'intervalDays': _interval, 'weekdays': _weekdays.toList()});
    m.details!['scheduleHistory'] = history;
    await m.save(); await NotificationService().scheduleMedicationNotifications(m);
    if (mounted) Navigator.pop(context, true);
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('${widget.medication.name}: details')), body: ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Schedule changes apply tomorrow and preserve earlier records. These settings should reflect your prescribed instructions.'),
    DropdownButtonFormField<String>(value: _kind, decoration: const InputDecoration(labelText: 'Medication type'), items: ['Prescription','Over the counter','Supplement'].map((v) => DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>_kind=v!)),
    SwitchListTile(title:const Text('Pause scheduled reminders'),value:_paused,onChanged:(v)=>setState(()=>_paused=v)),
    SwitchListTile(title:const Text('Archive from tomorrow'),value:_archived,onChanged:(v)=>setState(()=>_archived=v)),
    SwitchListTile(title:const Text('As needed: no scheduled adherence denominator'),value:_asNeeded,onChanged:(v)=>setState(()=>_asNeeded=v)),
    Wrap(children: List.generate(7,(i)=>FilterChip(label:Text(['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i]),selected:_weekdays.contains(i+1),onSelected:(v)=>setState((){if(v){_weekdays.add(i+1);}else{_weekdays.remove(i+1);}})))),
    DropdownButtonFormField<int>(value:_interval, decoration:const InputDecoration(labelText:'Repeat every'),items:[1,2,3,7].map((v)=>DropdownMenuItem(value:v,child:Text('$v day${v==1?'':'s'}'))).toList(),onChanged:(v)=>setState(()=>_interval=v!)),
    ListTile(title:Text('Start: ${_start?.toIso8601String().substring(0,10) ?? 'Original start'}'),onTap:()async{final d=await showDatePicker(context:context,initialDate:_start??DateTime.now(),firstDate:DateTime(2000),lastDate:DateTime(2100));if(d!=null)setState(()=>_start=d);}),
    ListTile(title:Text('End: ${_end?.toIso8601String().substring(0,10) ?? 'No end date'}'),trailing:IconButton(icon:const Icon(Icons.clear),onPressed:()=>setState(()=>_end=null)),onTap:()async{final d=await showDatePicker(context:context,initialDate:_end??DateTime.now(),firstDate:DateTime(2000),lastDate:DateTime(2100));if(d!=null)setState(()=>_end=d);}),
    TextField(controller:_instructions,maxLines:3,decoration:const InputDecoration(labelText:'Confirmed food / storage instructions')),
    TextField(controller:_pharmacy,decoration:const InputDecoration(labelText:'Pharmacy')),
    TextField(controller:_phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Pharmacy phone')),
    TextField(controller:_prescriber,decoration:const InputDecoration(labelText:'Prescriber')),
    TextField(controller:_prescriberPhone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Prescriber phone')),
    TextField(controller:_refills,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Prescription refills remaining (separate from pill stock)')),
    const SizedBox(height:16),ElevatedButton(onPressed:_save,child:const Text('Save details')),
    const SizedBox(height:16),const Text('Bottle refill history'),
    for(final e in widget.medication.details?['refills'] as List? ?? []) ListTile(title:Text('${e['newCount']} pills'),subtitle:Text('${e['at']} · previous count ${e['previousCount']}')),
  ]));
  @override
  void dispose(){for(final c in [_pharmacy,_phone,_prescriber,_prescriberPhone,_instructions,_refills]){c.dispose();}super.dispose();}
}
