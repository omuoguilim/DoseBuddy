import 'package:flutter/material.dart';

const medicationStrengthUnits = ['mg', 'mcg', 'g', 'mL', 'units', 'IU', 'mg/mL', 'mcg/mL', '%', 'mEq', 'mmol'];

class StrengthField extends StatelessWidget {
  final TextEditingController controller;
  final String unit;
  final String? error;
  final ValueChanged<String> onUnitChanged;
  const StrengthField({super.key, required this.controller, required this.unit, required this.onUnitChanged, this.error});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final strength = TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: 'Strength', hintText: '200', errorText: error),
    );
    final units = DropdownButtonFormField<String>(
      value: unit,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Unit'),
      items: medicationStrengthUnits.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) { if (v != null) onUnitChanged(v); },
    );
    if (constraints.maxWidth < 300 || MediaQuery.textScalerOf(context).scale(16) > 22) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        strength, const SizedBox(height: 16), units,
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: strength), const SizedBox(width: 16),
      SizedBox(width: 140, child: units),
    ]);
  });
}
