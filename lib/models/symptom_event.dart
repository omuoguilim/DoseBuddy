import 'package:hive/hive.dart';

@HiveType(typeId: 2)
class SymptomEvent extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  int severity;
  @HiveField(3)
  DateTime occurredAt;
  @HiveField(4)
  String? medicationId;
  @HiveField(5)
  int? durationMinutes;
  @HiveField(6)
  String? notes;

  SymptomEvent({
    required this.id,
    required this.name,
    required this.severity,
    required this.occurredAt,
    this.medicationId,
    this.durationMinutes,
    this.notes,
  });
}

class SymptomEventAdapter extends TypeAdapter<SymptomEvent> {
  @override
  final int typeId = 2;
  @override
  SymptomEvent read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return SymptomEvent(
      id: fields[0] as String,
      name: fields[1] as String,
      severity: fields[2] as int,
      occurredAt: fields[3] as DateTime,
      medicationId: fields[4] as String?,
      durationMinutes: fields[5] as int?,
      notes: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SymptomEvent obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.severity)
      ..writeByte(3)
      ..write(obj.occurredAt)
      ..writeByte(4)
      ..write(obj.medicationId)
      ..writeByte(5)
      ..write(obj.durationMinutes)
      ..writeByte(6)
      ..write(obj.notes);
  }
}
