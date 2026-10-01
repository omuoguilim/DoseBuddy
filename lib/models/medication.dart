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
  int pillsPerDose; //How many pills to take each time 

  @HiveField(16)
  Map<String, dynamic>? details;

  Medication({
    this.details,
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
    this.pillsPerDose = 1, //1 pill per dose
  }) : createdAt = createdAt ?? DateTime.now();

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
      if (log['date'] == dateStr && log['scheduledTime'] == scheduledTime &&
          (log['state'] == null || log['state'] == 'taken')) {
        return true;
      }
    }
    return false;
  }

  bool wasSkippedOn(DateTime date, String scheduledTime) => takenLog?.any(
        (log) => log['date'] == _formatDate(date) &&
            log['scheduledTime'] == scheduledTime && log['state'] == 'skipped',
      ) ?? false;

  void markAsSkippedOn(DateTime date, String scheduledTime, {String? reason}) {
    if (wasTakenOn(date, scheduledTime)) return;
    recordDose(date, scheduledTime, 'skipped', reason: reason ?? '');
  }

  void clearSkippedOn(DateTime date, String scheduledTime) {
    if (wasSkippedOn(date, scheduledTime)) recordDose(date, scheduledTime, 'unknown', reason: 'Corrected skipped entry');
  }

  DateTime scheduledAt(DateTime date, String time) =>
      _parseTimeToDateTime(time, forDate: date);

  String getStatusForDateTime(DateTime date, String scheduledTime) {
    final now = DateTime.now();
    final scheduledDateTime = _parseTimeToDateTime(scheduledTime, forDate: date);
    final graceEndTime = scheduledDateTime.add(Duration(minutes: gracePeriodMinutes));
    
    final isPast = now.isAfter(graceEndTime);
    
    if (wasTakenOn(date, scheduledTime)) {
      return 'taken';
    }
    if (wasSkippedOn(date, scheduledTime)) return 'skipped';
    if (wasMissedOn(date, scheduledTime)) return 'missed';
    
    if (isPast) {
      return 'unrecorded';
    }
    
    if (now.isAfter(scheduledDateTime) && now.isBefore(graceEndTime)) {
      return 'grace_period';
    }
    
    return 'upcoming';
  }

  bool wasMissedOn(DateTime date, String time) => takenLog?.any((l) => l['date'] == _formatDate(date) && l['scheduledTime'] == time && l['state'] == 'missed') ?? false;

  void recordDose(DateTime date, String time, String state, {String reason = '', DateTime? actualTime}) {
    if (!['taken', 'missed', 'skipped', 'unknown'].contains(state)) throw ArgumentError('Invalid dose state');
    takenLog ??= [];
    final keyDate = _formatDate(date);
    final matches = takenLog!.where((l) => l['date'] == keyDate && l['scheduledTime'] == time).toList();
    final old = matches.isEmpty ? null : Map<String, dynamic>.from(matches.first);
    final wasTaken = old != null && (old['state'] == null || old['state'] == 'taken');
    if (state == 'taken' && actualTime != null && actualTime.isAfter(DateTime.now())) throw ArgumentError('Actual time cannot be in the future');
    final oldStamp = DateTime.tryParse(old?['recordedAt'] as String? ?? old?['takenAt'] as String? ?? '');
    final bottle = lastRefillDate?.toIso8601String();
    final sameBottle = old?.containsKey('inventoryBottle') == true ? old!['inventoryBottle'] == bottle : lastRefillDate == null || (oldStamp != null && !oldStamp.isBefore(lastRefillDate!));
    final inventoryBottle = wasTaken ? (old?.containsKey('inventoryBottle') == true ? old!['inventoryBottle'] : sameBottle ? bottle : 'previous') : bottle;
    int inventoryDelta = old?['inventoryDelta'] as int? ?? (wasTaken ? pillsPerDose : 0);
    if (wasTaken && state != 'taken' && pillsRemaining != null && sameBottle) pillsRemaining = pillsRemaining! + inventoryDelta;
    if (!wasTaken && state == 'taken' && pillsRemaining != null) {
      inventoryDelta = pillsRemaining!.clamp(0, pillsPerDose).toInt();
      pillsRemaining = pillsRemaining! - inventoryDelta;
    }
    if (state != 'taken') inventoryDelta = 0;
    final history = old == null ? <Map<String, dynamic>>[] : (old['corrections'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (old != null) history.add({'state': old['state'] ?? 'taken', 'takenAt': old['takenAt'], 'reason': old['reason'], 'changedAt': DateTime.now().toIso8601String()});
    takenLog!.removeWhere((l) => l['date'] == keyDate && l['scheduledTime'] == time);
    takenLog!.add({'date': keyDate, 'scheduledTime': time, 'state': state, 'reason': reason, 'recordedAt': DateTime.now().toIso8601String(), 'takenAt': state == 'taken' ? (actualTime ?? DateTime.now()).toIso8601String() : null, 'corrections': history, 'inventoryDelta': inventoryDelta, 'inventoryBottle': inventoryBottle});
    if (state == 'taken') lastTaken = actualTime ?? DateTime.now();
  }

  void markAsTakenOn(DateTime date, String scheduledTime) {
    if (wasTakenOn(date, scheduledTime)) return;
    recordDose(date, scheduledTime, 'taken');
    status = 'taken';
  }

  Map<String, dynamic> scheduleFor(DateTime date) {
    final events = (details?['scheduleHistory'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).where((e) => !DateTime.parse(e['effectiveAt'] as String).isAfter(date)).toList();
    events.sort((a, b) => (a['effectiveAt'] as String).compareTo(b['effectiveAt'] as String));
    return events.isEmpty ? {} : events.last;
  }

  List<String> timesFor(DateTime date) => ((scheduleFor(date)['times'] as List?) ?? times).cast<String>();

  bool isScheduledFor(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final created = DateTime(createdAt.year, createdAt.month, createdAt.day);
    if (day.isBefore(created)) return false;
    final s = scheduleFor(day);
    if (s['paused'] == true || s['archived'] == true || s['asNeeded'] == true) return false;
    final start = DateTime.tryParse(s['start'] as String? ?? '');
    final end = DateTime.tryParse(s['end'] as String? ?? '');
    if (start != null && day.isBefore(start)) return false;
    if (end != null && day.isAfter(end)) return false;
    final weekdays = (s['weekdays'] as List?)?.cast<int>();
    if (weekdays != null && !weekdays.contains(day.weekday)) return false;
    final interval = s['intervalDays'] as int? ?? 1;
    if (interval > 1 && day.difference(start ?? created).inDays % interval != 0) return false;
    return true;
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
    if (newPillCount <= 0) throw ArgumentError('Count must be positive');
    details ??= {};
    final events = List<Map<String, dynamic>>.from((details!['refills'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
    events.add({'at': DateTime.now().toIso8601String(), 'previousCount': pillsRemaining, 'newCount': newPillCount, 'operation': 'replace bottle count'});
    details!['refills'] = events;
    pillsRemaining = newPillCount;
    totalPills = newPillCount;
    lastRefillDate = DateTime.now();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
