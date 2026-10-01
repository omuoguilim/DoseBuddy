class PrescriptionFields {
  final String strength;
  final String unit;
  final String name;
  final String directions;
  const PrescriptionFields({this.strength = '', this.unit = 'mg', this.name = '', this.directions = ''});
  static PrescriptionFields parse(String text) {
    // Suggestions only. Never turn OCR instructions into a dosing schedule.
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final match = RegExp(r'\b(\d+(?:\.\d+)?)\s*(mcg|mg|g|mL|IU|units|mEq|mmol)\b', caseSensitive: false).firstMatch(text);
    final units = {'mcg': 'mcg', 'mg': 'mg', 'g': 'g', 'ml': 'mL', 'iu': 'IU', 'units': 'units', 'meq': 'mEq', 'mmol': 'mmol'};
    String name = '';
    if (match != null) {
      final line = lines.firstWhere((l) => l.contains(match.group(0)!), orElse: () => '');
      final before = line.split(match.group(0)!).first.trim();
      if (before.isNotEmpty && !RegExp(r'^(take|qty|quantity|rx|patient|refills)\b', caseSensitive: false).hasMatch(before)) name = before;
    }
    return PrescriptionFields(strength: match?.group(1) ?? '', unit: units[match?.group(2)?.toLowerCase()] ?? 'mg', name: name,
      directions: lines.where((l) => RegExp(r'\b(take|apply|inject|inhale|instill)\b', caseSensitive: false).hasMatch(l)).join('\n'));
  }
}
