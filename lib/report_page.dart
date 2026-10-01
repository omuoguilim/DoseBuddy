import 'demo/demo_mode.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'models/medication.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});
  @override
  State<ReportPage> createState() => _ReportPageState();
}
class _ReportPageState extends State<ReportPage> {
  final _name = TextEditingController(), _notes = TextEditingController();
  final Set<String> _selected = {};
  bool _symptoms = true, _identity = true;
  DateTimeRange _range = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now());
  @override
  void initState() { super.initState(); _selected.addAll(Hive.box<Medication>(DemoMode.boxName).values.map((m) => m.id)); _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); if (mounted) setState(() { _notes.text = p.getString('appointment_notes') ?? ''; _name.text = '${p.getString('user_first_name') ?? p.getString('user_name') ?? ''} ${p.getString('user_last_name') ?? ''}'.trim(); }); }
  bool _included(String? stamp) { final d = DateTime.tryParse(stamp ?? ''); return d != null && !d.isBefore(DateTime(_range.start.year, _range.start.month, _range.start.day)) && d.isBefore(DateTime(_range.end.year, _range.end.month, _range.end.day + 1)); }
  List<List<String>> _rows(Medication med) {
    final result = <List<String>>[];
    final included = <String>{};
    final start = DateTime(_range.start.year,_range.start.month,_range.start.day);
    final end = DateTime(_range.end.year,_range.end.month,_range.end.day);
    for (var day = start; !day.isAfter(end); day = DateTime(day.year,day.month,day.day+1)) {
      if (!med.isScheduledFor(day)) continue;
      for (final time in med.timesFor(day)) {
        if (med.scheduledAt(day,time).isAfter(DateTime.now())) continue;
        final stamp = day.toIso8601String().substring(0,10);
        final records = (med.takenLog ?? []).where((r) => r['date'] == stamp && r['scheduledTime'] == time).toList();
        final row = records.isEmpty ? <String,dynamic>{} : records.first;
        included.add('$stamp|$time');
        result.add([stamp,time,'${row.isEmpty ? 'Not recorded' : row['state'] ?? 'taken'}','${row['takenAt'] ?? ''}','${row['reason'] ?? ''}']);
      }
    }
    for (final row in med.takenLog ?? <Map<String,dynamic>>[]) {
      if (_included(row['date'] as String?) && !included.contains('${row['date']}|${row['scheduledTime']}')) result.add(['${row['date'] ?? ''}','${row['scheduledTime'] ?? ''}','${row['state'] ?? 'taken'}','${row['takenAt'] ?? ''}','${row['reason'] ?? ''}']);
    }
    return result;
  }
  Future<Uint8List> _pdf() async {
    final doc = pw.Document();
    final medications = Hive.box<Medication>(DemoMode.boxName).values.where((m) => _selected.contains(m.id)).toList();
    doc.addPage(pw.MultiPage(maxPages: 100, pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(36), footer: (c) => pw.Text('DoseBuddy · Patient-reported records · Page ${c.pageNumber}/${c.pagesCount}', style: const pw.TextStyle(fontSize: 9)), build: (_) => [
      pw.Header(level: 0, text: 'Medication and symptom report'),
      if (_identity) pw.Text('Patient: ${_name.text.trim()}'),
      pw.Text('Period: ${_range.start.toIso8601String().substring(0, 10)} to ${_range.end.toIso8601String().substring(0, 10)}'),
      pw.Text('Generated: ${DateTime.now().toIso8601String()}'),
      pw.SizedBox(height: 12),
      pw.Text('This report contains patient-entered records. Missing entries do not establish that a medication was missed. It is not a prescription or verified clinical record.'),
      for (final m in medications) ...[
        pw.Header(level: 1, text: '${m.name} (${m.dosage})'),
        pw.Text('Current listed schedule: ${m.times.join(', ')}. Historical instructions may differ.'),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(headers: ['Scheduled date', 'Time', 'Recorded status', 'Actual time', 'Reason'], data: _rows(m), cellStyle: const pw.TextStyle(fontSize: 8)),
        if (_symptoms) ...[
          pw.SizedBox(height: 8),
          pw.Text('Reported symptoms (association does not establish cause):'),
          for (final s in (m.sideEffects ?? []).where((s) => _included(s['timestamp'] as String?))) pw.Text('${s['timestamp']} · ${(s['effects'] as List? ?? []).join(', ')} · ${s['severity'] ?? ''} · ${s['notes'] ?? ''}', style: const pw.TextStyle(fontSize: 9)),
        ],
      ],
      if (_notes.text.trim().isNotEmpty) ...[pw.Header(level: 1, text: 'Questions and appointment notes'), pw.Text(_notes.text.trim())],
    ]));
    return doc.save();
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Doctor report')), body: ListView(padding: const EdgeInsets.all(20), children: [
    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Patient full name')),
    SwitchListTile(title: const Text('Include patient name'), value: _identity, onChanged: (v) => setState(() => _identity = v)),
    ListTile(title: const Text('Report dates'), subtitle: Text('${_range.start.toIso8601String().substring(0, 10)} – ${_range.end.toIso8601String().substring(0, 10)}'), onTap: () async { final r = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now(), initialDateRange: _range); if (r != null) setState(() => _range = r); }),
    const Text('Choose which medications to include'),
    for (final m in Hive.box<Medication>(DemoMode.boxName).values) CheckboxListTile(title: Text(m.name), value: _selected.contains(m.id), onChanged: (v) => setState(() { if (v == true) { _selected.add(m.id); } else { _selected.remove(m.id); } })),
    SwitchListTile(title: const Text('Include symptom records'), value: _symptoms, onChanged: (v) => setState(() => _symptoms = v)),
    TextField(controller: _notes, maxLines: 4, decoration: const InputDecoration(labelText: 'Questions and notes to include')),
    const SizedBox(height: 16),
    ElevatedButton(onPressed: _selected.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Report preview')), body: PdfPreview(build: (_) => _pdf(), canChangeOrientation: false, canChangePageFormat: false, allowSharing: false, allowPrinting: false)))), child: const Text('Preview report')),
    TextButton(onPressed: _selected.isEmpty ? null : () async { final bytes = await _pdf(); if (!mounted) return; final sent = await Printing.sharePdf(bytes: bytes, filename: 'dosebuddy-report.pdf', bounds: Rect.fromLTWH(0, 0, MediaQuery.sizeOf(context).width, 100)); if (sent) { final p = await SharedPreferences.getInstance(); final list = p.getStringList('report_exports') ?? []; list.add(DateTime.now().toIso8601String()); await p.setStringList('report_exports', list); } }, child: const Text(DemoMode.enabled ? 'Download sample PDF' : 'Share PDF (delivery is not confirmed)')),
  ]));
  @override
  void dispose() { _name.dispose(); _notes.dispose(); super.dispose(); }
}
