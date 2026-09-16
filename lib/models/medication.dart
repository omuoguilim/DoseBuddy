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

  @HiveField(10)
  List<Map<String, dynamic>>? takenLog;

  @HiveField(11)
  int? totalPills;

  @HiveField(12)
  int? pillsRemaining;

  @HiveField(13)
  int? refillThreshold;

  @HiveField(14)
  DateTime? lastRefillDate;

  @HiveField(15)
  int pillsPerDose; // How many units to take each time

  @HiveField(16)
  String dosageForm;

  @HiveField(17)
  String medicationType; // scheduled or as_needed

  @HiveField(18)
  String reason;

  @HiveField(19)
  String instructions;

  @HiveField(20)
  String foodInstruction;

  @HiveField(21)
  DateTime? startDate;

  @HiveField(22)
  DateTime? endDate;

  @HiveField(23)
  String prescriber;

  @HiveField(24)
  String pharmacy;

  @HiveField(25)
  String lifecycleStatus; // active, paused, completed

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
    this.takenLog,
    this.totalPills,
    this.pillsRemaining,
    this.refillThreshold,
    this.lastRefillDate,
    this.pillsPerDose = 1,
    this.dosageForm = 'Tablet',
    this.medicationType = 'scheduled',
    this.reason = '',
    this.instructions = '',
    this.foodInstruction = 'No preference',
    DateTime? startDate,
    this.endDate,
    this.prescriber = '',
    this.pharmacy = '',
    this.lifecycleStatus = 'active',
  }) : createdAt = createdAt ?? DateTime.now(),
       startDate = startDate ?? createdAt ?? DateTime.now();

  bool get isAsNeeded => medicationType == 'as_needed';
  bool get isCompleted => lifecycleStatus == 'completed' ||
      (endDate != null && DateTime.now().isAfter(endDate!));

  int? get courseDaysRemaining {
    if (endDate == null) return null;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    final days = end.difference(today).inDays;
    return days < 0 ? 0 : days;
  }

  bool isOverdue(String scheduleTime) {
    final now = DateTime.now();
    final scheduledDateTime = _parseTimeToDateTime(scheduleTime);
    final graceEndTime = scheduledDateTime.add(Duration(minutes: gracePeriodMinutes));
    
    return now.isAfter(graceEndTime);
  }

  DateTime _parseTimeToDateTime(String timeStr, {DateTime? forDate}) {
    final referenceDate = forDate ?? DateTime.now();
    final parts = timeStr.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final isPM = parts[1].toUpperCase() == 'PM';

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    return DateTime(referenceDate.year, referenceDate.month, referenceDate.day, hour, minute);
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

  bool isInGracePeriod(String scheduleTime) {
    final now = DateTime.now();
    final scheduledDateTime = _parseTimeToDateTime(scheduleTime);
    final graceEndTime = scheduledDateTime.add(Duration(minutes: gracePeriodMinutes));
    
    return now.isAfter(scheduledDateTime) && now.isBefore(graceEndTime);
  }

  String getStatusForTime(String scheduleTime) {
    final now = DateTime.now();
    final scheduledDateTime = _parseTimeToDateTime(scheduleTime);
    final graceEndTime = scheduledDateTime.add(Duration(minutes: gracePeriodMinutes));
    
    if (now.isBefore(scheduledDateTime)) {
      return 'upcoming';
    } else if (now.isBefore(graceEndTime)) {
      return 'grace_period';
    } else {
      if (lastTaken != null) {
        final takenTime = lastTaken!;
        final takenDateTime = DateTime(
          now.year, now.month, now.day,
          takenTime.hour, takenTime.minute
        );
        
        if (takenDateTime.isAfter(scheduledDateTime) && 
            takenDateTime.isBefore(graceEndTime)) {
          return 'taken';
        }
      }
      return 'missed';
    }
  }

  bool wasTakenOn(DateTime date, String scheduledTime) {
    if (takenLog == null || takenLog!.isEmpty) return false;
    
    final dateStr = _formatDate(date);
    
    for (var log in takenLog!) {
      if (log['date'] == dateStr && log['scheduledTime'] == scheduledTime) {
        return true;
      }
    }
    return false;
  }

  String getStatusForDateTime(DateTime date, String scheduledTime) {
    final now = DateTime.now();
    final scheduledDateTime = _parseTimeToDateTime(scheduledTime, forDate: date);
    final graceEndTime = scheduledDateTime.add(Duration(minutes: gracePeriodMinutes));
    
    final isPast = now.isAfter(graceEndTime);
    
    if (wasTakenOn(date, scheduledTime)) {
      return 'taken';
    }
    
    if (isPast) {
      return 'missed';
    }
    
    if (now.isAfter(scheduledDateTime) && now.isBefore(graceEndTime)) {
      return 'grace_period';
    }
    
    return 'upcoming';
  }

  //ark as taken and reduce pill count by pillsPerDose
  void markAsTakenOn(DateTime date, String scheduledTime) {
    takenLog ??= [];
    
    final dateStr = _formatDate(date);
    
    final exists = takenLog!.any(
      (log) => log['date'] == dateStr && log['scheduledTime'] == scheduledTime
    );
    
    if (!exists) {
      takenLog!.add({
        'date': dateStr,
        'scheduledTime': scheduledTime,
        'takenAt': DateTime.now().toIso8601String(),
      });
      
      //ecrement pill count by pillsPerDose (not just 1)
      if (pillsRemaining != null && pillsRemaining! > 0) {
        pillsRemaining = pillsRemaining! - pillsPerDose;
        if (pillsRemaining! < 0) pillsRemaining = 0; // Don't go negative
      }
    }
    
    lastTaken = DateTime.now();
    status = 'taken';
  }

  bool isScheduledFor(DateTime date) {
    final createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    
    return checkDate.isAfter(createdDate.subtract(const Duration(days: 1))) || 
           checkDate.isAtSameMomentAs(createdDate);
  }

  bool needsRefill() {
    if (pillsRemaining == null || refillThreshold == null) return false;
    return pillsRemaining! <= refillThreshold!;
  }

  //alculates days until out considering pillsPerDose
  int? daysUntilOut() {
    if (pillsRemaining == null || times.isEmpty) return null;
    final pillsPerDay = times.length * pillsPerDose; // Total pills consumed per day
    if (pillsPerDay == 0) return null;
    return (pillsRemaining! / pillsPerDay).floor();
  }

  void refill(int newPillCount) {
    pillsRemaining = newPillCount;
    totalPills = newPillCount;
    lastRefillDate = DateTime.now();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
