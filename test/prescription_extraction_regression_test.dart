import 'package:flutter_test/flutter_test.dart';
import 'package:dosebuddy/services/prescription_parser.dart';

void main() {
  group('prescription extraction after the synthetic-label baseline', () {
    test('separate strength line uses the adjacent medication name', () {
      final fields = PrescriptionFields.parse('FICTIONAL TEST LABEL - NOT FOR USE\nTestorin\nStrength: 25 mg\nTake only as directed by your prescriber.\nQuantity: 30 tablets');
      expect(fields.name, 'Testorin');
      expect(fields.strength, '25');
      expect(fields.unit, 'mg');
    });
    test('wrapped directions retain the complete sentence', () {
      final fields = PrescriptionFields.parse('Trialmed 50 mg\nTake only as directed\nby your prescriber.\nQuantity: 30 tablets');
      expect(fields.directions, 'Take only as directed\nby your prescriber.');
    });
    test('use starts directions and does not include quantity metadata', () {
      final fields = PrescriptionFields.parse('Finalmed 20 mg\nUse only as directed by your prescriber.\nQuantity: 30 tablets');
      expect(fields.directions, 'Use only as directed by your prescriber.');
    });
    test('OCR spaces in names remain visible for manual review', () {
      final fields = PrescriptionFields.parse('Samp Lemed 250 mg\nTake only as directed by your prescriber.');
      expect(fields.name, 'Samp Lemed');
    });
    test('missing name does not become strength or a test heading', () {
      final fields = PrescriptionFields.parse('FICTIONAL TEST LABEL - NOT FOR USE\nStrength: 25 mg\nUse as directed.');
      expect(fields.name, '');
      expect(fields.strength, '25');
    });
    test('patient name is not substituted for missing medication name', () {
      final fields = PrescriptionFields.parse('Patient: Jane Example\n25 mg\nUse as directed.');
      expect(fields.name, '');
    });
    test('decimal strength survives a quantity listed first', () {
      final fields = PrescriptionFields.parse('Quantity: 60 tablets\nExamplemed 0.5 mg\nTake only as directed by your prescriber.');
      expect(fields.name, 'Examplemed');
      expect(fields.strength, '0.5');
      expect(fields.unit, 'mg');
    });
    test('uppercase directions and a unit without a separating space work', () {
      final fields = PrescriptionFields.parse('DEMOTAB 100mg\nTAKE ONLY AS DIRECTED BY YOUR PRESCRIBER.');
      expect(fields.name, 'DEMOTAB');
      expect(fields.strength, '100');
      expect(fields.directions, 'TAKE ONLY AS DIRECTED BY YOUR PRESCRIBER.');
    });
    test('preserves a two-word name and topical directions', () {
      final fields = PrescriptionFields.parse('Demo Cream 15 g\nApply only as directed by your prescriber.\nQuantity: 1 tube');
      expect(fields.name, 'Demo Cream');
      expect(fields.unit, 'g');
      expect(fields.directions, 'Apply only as directed by your prescriber.');
    });
    test('preserves hyphens and liquid units', () {
      final fields = PrescriptionFields.parse('Demo-Liquid 5 mL\nTake only as directed by your prescriber.');
      expect(fields.name, 'Demo-Liquid');
      expect(fields.strength, '5');
      expect(fields.unit, 'mL');
    });
    test('labelled instructions retain negations on continuation lines', () {
      final fields = PrescriptionFields.parse('Freshmed 2.5 mcg\nDirections: Use only as directed.\nDo not change the confirmed instructions.\nRefills: 0');
      expect(fields.directions, 'Use only as directed.\nDo not change the confirmed instructions.');
      expect(fields.strength, '2.5');
      expect(fields.unit, 'mcg');
    });
    test('quantities and administration volumes are not strength', () {
      final fields = PrescriptionFields.parse('Quantity: 30 mL\nLiquid Example 2 mg\nUse 5 mL only as directed.');
      expect(fields.name, 'Liquid Example');
      expect(fields.strength, '2');
      expect(fields.unit, 'mg');
    });
  });
}
