class PrescriptionFields {
  final String strength;
  final String unit;
  final String name;
  final String directions;
  const PrescriptionFields({this.strength = '', this.unit = 'mg', this.name = '', this.directions = ''});
  static PrescriptionFields parse(String text) {
    // Suggestions only. Never turn OCR instructions into a dosing schedule.
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final strengthPattern = RegExp(r'\b(\d+(?:\.\d+)?)\s*(mcg|mg|g|mL|IU|units|mEq|mmol)\b', caseSensitive: false);
    final units = {'mcg': 'mcg', 'mg': 'mg', 'g': 'g', 'ml': 'mL', 'iu': 'IU', 'units': 'units', 'meq': 'mEq', 'mmol': 'mmol'};
    RegExpMatch? match;
    var strengthLine = -1;
    for (var i = 0; i < lines.length; i++) {
      // A quantity or instruction containing units is not medication strength.
      if (_isMetadata(lines[i]) || _isDirection(lines[i])) continue;
      final candidate = strengthPattern.firstMatch(lines[i]);
      if (candidate != null) {
        match = candidate;
        strengthLine = i;
        break;
      }
    }
    String name = '';
    if (match != null) {
      final before = lines[strengthLine].substring(0, match.start).trim();
      final strengthLabelOnly = RegExp(r'^(?:strength|dosage)\s*:?$', caseSensitive: false).hasMatch(before);
      if (before.isNotEmpty && !strengthLabelOnly) {
        name = _nameCandidate(before);
      } else if (strengthLine > 0) {
        // Only use the adjacent line. Never search past patient/pharmacy metadata
        // or invent a name from a heading when the actual name is missing.
        name = _nameCandidate(lines[strengthLine - 1]);
      }
    }

    final directionLines = <String>[];
    var readingDirections = false;
    for (final line in lines) {
      final startsDirections = _isDirection(line);
      if (startsDirections) {
        readingDirections = true;
        directionLines.add(line.replaceFirst(_directionLabel, '').trim());
      } else if (readingDirections) {
        if (_isMetadata(line) || strengthPattern.hasMatch(line) &&
            RegExp(r'^(?:strength|dosage)\b', caseSensitive: false).hasMatch(line)) {
          readingDirections = false;
        } else {
          // Retain wrapped text, including numbers and negations, in reading order.
          directionLines.add(line);
        }
      }
    }
    return PrescriptionFields(strength: match?.group(1) ?? '', unit: units[match?.group(2)?.toLowerCase()] ?? 'mg', name: name,
      directions: directionLines.join('\n'));
  }

  static final _directionLabel = RegExp(r'^(?:directions|instructions|sig)\s*:\s*', caseSensitive: false);
  static final _directionStart = RegExp(r'^(?:take|apply|inject|inhale|instill|use)\b', caseSensitive: false);
  static bool _isDirection(String line) => _directionStart.hasMatch(line) || _directionLabel.hasMatch(line);
  static bool _isMetadata(String line) => RegExp(
    r'^(?:qty|quantity|rx|rx\s*(?:number|no)|patient|patient\s*name|refills?|prescriber|doctor|pharmacy|dispensed|dispense\s*date|expiration|expires|expiry|lot|ndc|date|storage|store|keep|warning|caution)\b|^fictional\s+test\s+label\b|^not\s+for\s+use\b',
    caseSensitive: false,
  ).hasMatch(line);
  static String _nameCandidate(String line) {
    if (_isMetadata(line) || _isDirection(line) ||
        RegExp(r'^(?:strength|dosage)\s*:?$', caseSensitive: false).hasMatch(line)) return '';
    final candidate = line.replaceFirst(RegExp(r'^(?:medication(?:\s*name)?|drug(?:\s*name)?|name)\s*:\s*', caseSensitive: false), '').trim();
    if (!RegExp(r'[A-Za-z]').hasMatch(candidate) || candidate.endsWith(':')) return '';
    // Preserve OCR spelling and spacing. Guessing a drug name could change it.
    return candidate;
  }
}
