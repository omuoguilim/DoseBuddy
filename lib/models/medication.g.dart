
part of 'medication.dart';

class MedicationAdapter extends TypeAdapter<Medication> {
  @override
  final int typeId = 0;

  @override
  Medication read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Medication(
      id: fields[0] as String,
      name: fields[1] as String,
      dosage: fields[2] as String,
      times: (fields[3] as List).cast<String>(),
      notes: fields[4] as String,
      status: fields[5] as String,
      lastTaken: fields[6] as DateTime?,
      gracePeriodMinutes: fields[7] as int,
      createdAt: fields[8] as DateTime?,
      sideEffects: (fields[9] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          ?.toList(),
      takenLog: (fields[10] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          ?.toList(),
      totalPills: fields[11] as int?,
      pillsRemaining: fields[12] as int?,
      refillThreshold: fields[13] as int?,
      lastRefillDate: fields[14] as DateTime?,
      pillsPerDose: fields[15] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Medication obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dosage)
      ..writeByte(3)
      ..write(obj.times)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.lastTaken)
      ..writeByte(7)
      ..write(obj.gracePeriodMinutes)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.sideEffects)
      ..writeByte(10)
      ..write(obj.takenLog)
      ..writeByte(11)
      ..write(obj.totalPills)
      ..writeByte(12)
      ..write(obj.pillsRemaining)
      ..writeByte(13)
      ..write(obj.refillThreshold)
      ..writeByte(14)
      ..write(obj.lastRefillDate)
      ..writeByte(15)
      ..write(obj.pillsPerDose);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
