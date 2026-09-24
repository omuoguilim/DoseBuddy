import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class DoseEvent extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String medicationId;
  @HiveField(2)
  DateTime scheduledAt;
  @HiveField(3)
  DateTime? takenAt;
  @HiveField(4)
  String status;
  @HiveField(5)
  int amount;
  @HiveField(6)
  String? reason;
  @HiveField(7)
  String? notes;

  DoseEvent({
    required this.id,
    required this.medicationId,
    required this.scheduledAt,
    this.takenAt,
    this.status = 'upcoming',
    this.amount = 1,
    this.reason,
    this.notes,
  });
}

class DoseEventAdapter extends TypeAdapter<DoseEvent> {
  @override
  final int typeId = 1;

  @override
  DoseEvent read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return DoseEvent(
      id: fields[0] as String,
      medicationId: fields[1] as String,
      scheduledAt: fields[2] as DateTime,
      takenAt: fields[3] as DateTime?,
      status: fields[4] as String? ?? 'upcoming',
      amount: fields[5] as int? ?? 1,
      reason: fields[6] as String?,
      notes: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DoseEvent obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.medicationId)
      ..writeByte(2)
      ..write(obj.scheduledAt)
      ..writeByte(3)
      ..write(obj.takenAt)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.amount)
      ..writeByte(6)
      ..write(obj.reason)
      ..writeByte(7)
      ..write(obj.notes);
  }
}
