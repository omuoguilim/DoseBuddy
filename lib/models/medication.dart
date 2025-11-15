import 'package:hive/hive.dart';

part 'medication.g.dart';

@HiveType(typeId: 0)
class Medication extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String dosage;

  @HiveField(3)
  List<String> times; 

  @HiveField(4)
  String notes;

  @HiveField(5)
  String status; 

  @HiveField(6)
  DateTime? lastTaken;

  @HiveField(7)
  int gracePeriodMinutes;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  List<Map<String, dynamic>>? sideEffects;

  Medication({
  required this.id,
  required this.name,
  required this.dosage,
  required this.times,
  this.notes = '',
  this.status = 'upcoming',
  this.lastTaken,
  this.gracePeriodMinutes = 30,
  DateTime? createdAt,
  this.sideEffects,
}) : createdAt = createdAt ?? DateTime.now();

  // Helper method to check if medication is overdue
  bool isOverdue(String scheduleTime) {
    final now = DateTime.now();
    final scheduledDateTime = _parseTimeToDateTime(scheduleTime);
    final graceEndTime = scheduledDateTime.add(Duration(minutes: gracePeriodMinutes));
    
    return now.isAfter(graceEndTime);
  }

  DateTime _parseTimeToDateTime(String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final isPM = parts[1].toUpperCase() == 'PM';

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String? getNextScheduledTime() {
    final now = DateTime.now();
    
    for (var time in times) {
      final scheduledDateTime = _parseTimeToDateTime(time);
      if (now.isBefore(scheduledDateTime)) {
        return time;
      }
    }
    
    return times.isNotEmpty ? times.first : null;
  }

  // Check if we're in the grace period for a specific time
bool isInGracePeriod(String scheduleTime) {
  final now = DateTime.now();
  final scheduledDateTime = _parseTimeToDateTime(scheduleTime);
  final graceEndTime = scheduledDateTime.add(Duration(minutes: gracePeriodMinutes));
  
  return now.isAfter(scheduledDateTime) && now.isBefore(graceEndTime);
}

// Get current status for a specific scheduled time
String getStatusForTime(String scheduleTime) {
  final now = DateTime.now();
  final scheduledDateTime = _parseTimeToDateTime(scheduleTime);
  final graceEndTime = scheduledDateTime.add(Duration(minutes: gracePeriodMinutes));
  
  if (now.isBefore(scheduledDateTime)) {
    return 'upcoming';
  } else if (now.isBefore(graceEndTime)) {
    return 'grace_period'; // In grace period window
  } else {
    // Check if it was taken
    if (lastTaken != null) {
      final takenTime = lastTaken!;
      final takenDateTime = DateTime(
        now.year, now.month, now.day,
        takenTime.hour, takenTime.minute
      );
      
      // If taken within grace period
      if (takenDateTime.isAfter(scheduledDateTime) && 
          takenDateTime.isBefore(graceEndTime)) {
        return 'taken';
      }
    }
    return 'missed';
  }
}
}
