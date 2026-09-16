part of 'medication.dart';

class MedicationAdapter extends TypeAdapter<Medication> {
  @override
  final int typeId = 0;

  @override
  Medication read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i=0;i<numOfFields;i++) reader.readByte(): reader.read()};
    return Medication(
      id: fields[0] as String,
      name: fields[1] as String,
      dosage: fields[2] as String,
      times: (fields[3] as List).cast<String>(),
      notes: (fields[4] as String?) ?? '',
      status: (fields[5] as String?) ?? 'upcoming',
      lastTaken: fields[6] as DateTime?,
      gracePeriodMinutes: (fields[7] as int?) ?? 30,
      createdAt: fields[8] as DateTime?,
      sideEffects: (fields[9] as List?)?.map((e)=>(e as Map).cast<String,dynamic>()).toList(),
      takenLog: (fields[10] as List?)?.map((e)=>(e as Map).cast<String,dynamic>()).toList(),
      totalPills: fields[11] as int?, pillsRemaining: fields[12] as int?,
      refillThreshold: fields[13] as int?, lastRefillDate: fields[14] as DateTime?,
      pillsPerDose: (fields[15] as int?) ?? 1,
      dosageForm: (fields[16] as String?) ?? 'Tablet',
      medicationType: (fields[17] as String?) ?? 'scheduled',
      reason: (fields[18] as String?) ?? '', instructions: (fields[19] as String?) ?? '',
      foodInstruction: (fields[20] as String?) ?? 'No preference',
      startDate: fields[21] as DateTime?, endDate: fields[22] as DateTime?,
      prescriber: (fields[23] as String?) ?? '', pharmacy: (fields[24] as String?) ?? '',
      lifecycleStatus: (fields[25] as String?) ?? 'active',
    );
  }

  @override
  void write(BinaryWriter writer, Medication o) {
    writer..writeByte(26)
      ..writeByte(0)..write(o.id)..writeByte(1)..write(o.name)..writeByte(2)..write(o.dosage)
      ..writeByte(3)..write(o.times)..writeByte(4)..write(o.notes)..writeByte(5)..write(o.status)
      ..writeByte(6)..write(o.lastTaken)..writeByte(7)..write(o.gracePeriodMinutes)..writeByte(8)..write(o.createdAt)
      ..writeByte(9)..write(o.sideEffects)..writeByte(10)..write(o.takenLog)..writeByte(11)..write(o.totalPills)
      ..writeByte(12)..write(o.pillsRemaining)..writeByte(13)..write(o.refillThreshold)..writeByte(14)..write(o.lastRefillDate)
      ..writeByte(15)..write(o.pillsPerDose)..writeByte(16)..write(o.dosageForm)..writeByte(17)..write(o.medicationType)
      ..writeByte(18)..write(o.reason)..writeByte(19)..write(o.instructions)..writeByte(20)..write(o.foodInstruction)
      ..writeByte(21)..write(o.startDate)..writeByte(22)..write(o.endDate)..writeByte(23)..write(o.prescriber)
      ..writeByte(24)..write(o.pharmacy)..writeByte(25)..write(o.lifecycleStatus);
  }
  @override int get hashCode => typeId.hashCode;
  @override bool operator ==(Object other) => identical(this,other) || other is MedicationAdapter && runtimeType==other.runtimeType && typeId==other.typeId;
}
