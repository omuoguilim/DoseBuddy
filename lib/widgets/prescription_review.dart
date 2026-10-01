import 'platform_photo.dart';
import '../demo/demo_mode.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/prescription_ocr.dart';
import '../services/prescription_parser.dart';
import 'strength_field.dart';

class PrescriptionReviewPage extends StatefulWidget {
  const PrescriptionReviewPage({super.key});
  @override
  State<PrescriptionReviewPage> createState() => _PrescriptionReviewPageState();
}
class _PrescriptionReviewPageState extends State<PrescriptionReviewPage> {
  final _name = TextEditingController(), _strength = TextEditingController(), _directions = TextEditingController();
  String _unit = 'mg', _text = '', _error = '';
  XFile? _photo;
  bool _busy = false, _confirmed = false;
  Future<void> _scan(ImageSource source) async {
    if (_busy) return;
    setState(() { _busy = true; _error = ''; _confirmed = false; });
    try {
      final photo = await ImagePicker().pickImage(source: source, maxWidth: 2400);
      if (photo == null) return;
      final text = await PrescriptionOcr.recognize(photo.path);
      final fields = PrescriptionFields.parse(text);
      if (!mounted) return;
      setState(() { _photo = photo; _text = text; _name.text = fields.name; _strength.text = fields.strength; _unit = fields.unit; _directions.text = fields.directions; });
    } catch (_) { if (mounted) setState(() => _error = 'Could not read this image. Try a clearer photo or enter the label manually.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Review prescription')), body: ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Text recognition can make mistakes. Compare every field with the label. Set your schedule manually from the confirmed instructions.'),
    Row(children: [TextButton.icon(onPressed: _busy ? null : () => _scan(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text('Camera')), TextButton.icon(onPressed: _busy ? null : () => _scan(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text('Upload'))]),
    if (DemoMode.enabled) ...[
      const Text('Browser OCR downloads a recognition model on first use. Use a fictional label; do not upload personal health information.'),
      TextButton.icon(onPressed: _busy ? null : () { const text = 'SAMPLE PRESCRIPTION\n10 mg\nTake one tablet as directed.\nFictional demonstration label'; final fields = PrescriptionFields.parse(text); setState(() { _text=text; _name.text=fields.name; _strength.text=fields.strength; _unit=fields.unit; _directions.text=fields.directions; _confirmed=false; }); }, icon: const Icon(Icons.description_outlined), label: const Text('Try sample label text')),
    ],
    if (_busy) const LinearProgressIndicator(),
    if (_error.isNotEmpty) Text(_error),
    if (_photo != null) platformPhoto(_photo!.path, height: 240, fit: BoxFit.contain),
    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Medication name (confirm)')),
    StrengthField(controller: _strength, unit: _unit, onUnitChanged: (v) => setState(() => _unit = v)),
    TextField(controller: _directions, maxLines: 4, decoration: const InputDecoration(labelText: 'Label directions (confirm)')),
    ExpansionTile(title: const Text('Recognized label text'), children: [Padding(padding: const EdgeInsets.all(12), child: SelectableText(_text))]),
    CheckboxListTile(value: _confirmed, onChanged: (v) => setState(() => _confirmed = v ?? false), title: const Text('I checked these details against the prescription label')),
    ElevatedButton(onPressed: !_confirmed || _busy ? null : () {
      if (_name.text.trim().isEmpty || (double.tryParse(_strength.text) ?? 0) <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confirm a medication name and positive strength.'))); return; }
      Navigator.pop(context, {'name': _name.text.trim(), 'strength': _strength.text.trim(), 'unit': _unit, 'directions': _directions.text.trim()});
    }, child: const Text('Use confirmed details')),
  ]));
  @override
  void dispose() { _name.dispose(); _strength.dispose(); _directions.dispose(); super.dispose(); }
}
