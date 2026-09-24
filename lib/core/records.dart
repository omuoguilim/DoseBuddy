import 'dart:convert';

typedef Json = Map<String, dynamic>;
Json copyJson(Json value) => jsonDecode(jsonEncode(value)) as Json;
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
String doseKey(String id, DateTime day, int minute) =>
    '$id@${dayKey(day)}/$minute';
String clockLabel(int minute) =>
    '${minute ~/ 60 % 12 == 0 ? 12 : minute ~/ 60 % 12}:${(minute % 60).toString().padLeft(2, '0')} ${minute < 720 ? 'AM' : 'PM'}';
int parseClock(String value) {
  final m = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (m == null) throw FormatException('Invalid medication time: $value');
  final hour = int.parse(m[1]!);
  final minute = int.parse(m[2]!);
  if (hour < 1 || hour > 12 || minute > 59)
    throw const FormatException('Invalid time');
  return (hour % 12 + (m[3]!.toUpperCase() == 'PM' ? 12 : 0)) * 60 + minute;
}

class ScheduledDose {
  final String key, medicationId;
  final DateTime at;
  final Json details;
  ScheduledDose(this.key, this.medicationId, this.at, this.details);
  Json snapshot() => {
    'key': key,
    'medicationId': medicationId,
    'scheduledAt': at.toIso8601String(),
    'details': copyJson(details),
  };
  static ScheduledDose fromSnapshot(Json s) => ScheduledDose(
    s['key'] as String,
    s['medicationId'] as String,
    DateTime.parse(s['scheduledAt'] as String),
    Map<String, dynamic>.from(s['details'] as Map),
  );
}

class Records {
  static Json empty() => {
    'schema': 2,
    'medications': <String, dynamic>{},
    'outcomes': <String, dynamic>{},
    'symptoms': <String, dynamic>{},
    'audit': <dynamic>[],
    'settings': {
      'reminders': false,
      'privateNotifications': true,
      'appLock': false,
    },
    'emergency': {'allergies': '', 'contact': '', 'notes': ''},
    'migrationNotes': <dynamic>[],
  };
  final Json data;
  Records(this.data);
  Json get medications => data['medications'] as Json;
  Json get outcomes => data['outcomes'] as Json;
  Json get settings => data['settings'] as Json;
  Json current(Json med) =>
      Map<String, dynamic>.from((med['versions'] as List).last as Map);

  List<ScheduledDose> schedule(DateTime from, DateTime through) {
    final result = <String, ScheduledDose>{};
    for (final entry in medications.entries) {
      final med = entry.value as Json;
      for (final raw in med['versions'] as List) {
        final v = Map<String, dynamic>.from(raw as Map);
        if (v['active'] != true || v['type'] == 'as_needed') continue;
        final effective = DateTime.parse(v['effectiveFrom'] as String);
        final until = v['effectiveUntil'] == null
            ? null
            : DateTime.parse(v['effectiveUntil'] as String);
        for (
          var day = dayStart(from);
          !day.isAfter(dayStart(through));
          day = DateTime(day.year, day.month, day.day + 1)
        ) {
          if (dayKey(day).compareTo(v['start'] as String) < 0 ||
              (v['end'] != null &&
                  dayKey(day).compareTo(v['end'] as String) > 0))
            continue;
          for (final value in v['times'] as List) {
            final minute = value as int;
            final at = DateTime(
              day.year,
              day.month,
              day.day,
              minute ~/ 60,
              minute % 60,
            );
            if (at.isBefore(effective) ||
                (until != null && !at.isBefore(until)))
              continue;
            final key = doseKey(entry.key, day, minute);
            result[key] = ScheduledDose(key, entry.key, at, v);
          }
        }
      }
    }
    // Resolved doses retain their original details even after a schedule edit.
    for (final raw in outcomes.values) {
      final record = raw as Json;
      if (record['prn'] == true) continue;
      final dose = ScheduledDose.fromSnapshot(record['dose'] as Json);
      if (!dayStart(dose.at).isBefore(dayStart(from)) &&
          !dayStart(dose.at).isAfter(dayStart(through)))
        result[dose.key] = dose;
    }
    return result.values.toList()..sort((a, b) => a.at.compareTo(b.at));
  }

  String status(ScheduledDose d, DateTime now) =>
      (outcomes[d.key] as Json?)?['status'] as String? ??
      (d.at.isAfter(now) ? 'Upcoming' : 'Not recorded');

  void saveMedication(
    String id,
    Json fields,
    DateTime now, {
    num? supply,
    num? threshold,
  }) {
    validateMedication(fields);
    if (supply != null && (!supply.isFinite || supply < 0))
      throw ArgumentError('Supply must be zero or greater.');
    if (threshold != null && (!threshold.isFinite || threshold < 0))
      throw ArgumentError('Refill threshold must be zero or greater.');
    final previous = medications[id] as Json?;
    if (previous != null &&
        (previous['supply'] != supply ||
            current(previous)['unit'] != fields['unit'])) {
      for (final value in outcomes.values) {
        final o = value as Json;
        if ((o['dose'] as Json)['medicationId'] == id) {
          o['inventoryDeduction'] = 0;
          o['inventoryReconciled'] = true;
        }
      }
    }
    final versions = previous == null
        ? <dynamic>[]
        : previous['versions'] as List;
    if (versions.isNotEmpty)
      (versions.last as Json)['effectiveUntil'] = now.toIso8601String();
    versions.add({
      ...copyJson(fields),
      'effectiveFrom': now.toIso8601String(),
      'effectiveUntil': null,
    });
    medications[id] = {
      'id': id,
      'versions': versions,
      'supply': supply,
      'threshold': threshold,
    };
    (data['audit'] as List).add({
      'action': 'medication saved',
      'id': id,
      'at': now.toIso8601String(),
    });
  }

  void changeActive(String id, bool active, DateTime now) {
    final med = medications[id] as Json;
    final fields = current(med);
    fields['active'] = active;
    saveMedication(
      id,
      fields,
      now,
      supply: med['supply'] as num?,
      threshold: med['threshold'] as num?,
    );
  }

  void record(
    ScheduledDose d, {
    required String status,
    required DateTime now,
    DateTime? takenAt,
    num? amount,
    String reason = '',
    bool prn = false,
  }) {
    if (!['Taken', 'Skipped'].contains(status))
      throw ArgumentError('Unknown outcome');
    final actual = takenAt ?? now;
    final quantity = amount ?? d.details['amount'] as num;
    if (status == 'Taken' &&
        (actual.isAfter(now) || !quantity.isFinite || quantity <= 0))
      throw ArgumentError('Use a past or present time and a positive amount.');
    final previous = outcomes[d.key] as Json?;
    final med = medications[d.medicationId] as Json?;
    num deduction = 0;
    if (med?['supply'] != null && previous?['inventoryReconciled'] != true) {
      final restored =
          (med!['supply'] as num) +
          ((previous?['inventoryDeduction'] as num?) ?? 0);
      deduction = status == 'Taken' ? quantity.clamp(0, restored) : 0;
      med['supply'] = restored - deduction;
    }
    if (previous != null)
      (data['audit'] as List).add({
        'action': 'dose corrected',
        'previous': copyJson(previous),
        'at': now.toIso8601String(),
      });
    outcomes[d.key] = {
      'dose': d.snapshot(),
      'status': status,
      'takenAt': status == 'Taken' ? actual.toIso8601String() : null,
      'recordedAt': now.toIso8601String(),
      'utcOffsetMinutes': actual.timeZoneOffset.inMinutes,
      'amount': quantity,
      'reason': reason,
      'prn': prn,
      'inventoryDeduction': deduction,
      'inventoryReconciled': previous?['inventoryReconciled'] == true,
    };
  }

  void undo(String key, DateTime now) {
    final previous = outcomes.remove(key) as Json?;
    if (previous == null) return;
    final med =
        medications[(previous['dose'] as Json)['medicationId']] as Json?;
    if (med?['supply'] != null)
      med!['supply'] =
          (med['supply'] as num) +
          ((previous['inventoryDeduction'] as num?) ?? 0);
    (data['audit'] as List).add({
      'action': 'dose removed',
      'previous': previous,
      'at': now.toIso8601String(),
    });
  }

  Json counts(DateTime start, DateTime end) {
    final eligible = schedule(
      start,
      end,
    ).where((d) => !d.at.isAfter(end)).toList();
    final taken = eligible
        .where((d) => (outcomes[d.key] as Json?)?['status'] == 'Taken')
        .length;
    final skipped = eligible
        .where((d) => (outcomes[d.key] as Json?)?['status'] == 'Skipped')
        .length;
    return {
      'scheduled': eligible.length,
      'taken': taken,
      'skipped': skipped,
      'unrecorded': eligible.length - taken - skipped,
    };
  }

  String report(DateTime from, DateTime now) {
    final c = counts(from, now);
    final lines = <String>[
      'DoseBuddy record summary',
      '${dayKey(from)} to ${dayKey(now)}',
      'User-entered records; not confirmation that medication was consumed.',
      '',
      '${c['taken']} recorded taken / ${c['scheduled']} scheduled doses due',
      '${c['skipped']} recorded skipped; ${c['unrecorded']} not recorded',
      'As-needed doses are excluded from scheduled totals.',
      '',
    ];
    for (final dose in schedule(from, now).where((d) => !d.at.isAfter(now))) {
      final r = outcomes[dose.key] as Json?;
      lines.add(
        '${dayKey(dose.at)} ${clockLabel(dose.at.hour * 60 + dose.at.minute)} | ${dose.details['name']} | ${dose.details['strength']} | ${status(dose, now)}${r == null ? '' : ' | amount ${r['amount']} ${dose.details['unit']} | actual ${r['takenAt'] ?? 'not applicable'} | ${r['reason']}'}',
      );
    }
    lines.add('\nAS-NEEDED RECORDS');
    for (final raw in outcomes.values) {
      final r = raw as Json;
      if (r['prn'] != true) continue;
      final at = DateTime.parse(r['takenAt'] as String? ?? r['recordedAt'] as String);
      if (at.isBefore(from) || at.isAfter(now)) continue;
      final d = ScheduledDose.fromSnapshot(r['dose'] as Json);
      lines.add(
        '${r['takenAt']} | ${d.details['name']} | ${r['amount']} ${d.details['unit']} | ${r['reason']}',
      );
    }
    lines.add('\nSYMPTOM NOTES (user associations do not establish cause)');
    for (final raw in (data['symptoms'] as Json).values) {
      final s = raw as Json;
      final at = DateTime.parse(s['at'] as String);
      if (at.isBefore(from) || at.isAfter(now)) continue;
      lines.add(
        '${s['at']} | ${s['name']} | severity ${s['severity']}/5 | duration ${s['duration']} | ${s['notes']}',
      );
    }
    if ((data['migrationNotes'] as List).isNotEmpty)
      lines.add(
        '\nIMPORT LIMITATIONS\n${(data['migrationNotes'] as List).join('\n')}',
      );
    return lines.join('\n');
  }
}

void validateMedication(Json f) {
  if ((f['name'] as String).trim().isEmpty ||
      (f['strength'] as String).trim().isEmpty)
    throw ArgumentError('Enter the medication name and complete strength.');
  final amount = f['amount'] as num;
  if (!amount.isFinite || amount <= 0)
    throw ArgumentError('Enter a positive amount per dose.');
  if ((f['unit'] as String).trim().isEmpty)
    throw ArgumentError('Choose the amount unit.');
  final times = (f['times'] as List).cast<int>();
  if (f['type'] == 'scheduled' && times.isEmpty)
    throw ArgumentError('Add at least one scheduled time.');
  if (times.toSet().length != times.length ||
      times.any((m) => m < 0 || m >= 1440))
    throw ArgumentError('Each time must be valid and unique.');
  if (f['end'] != null &&
      (f['end'] as String).compareTo(f['start'] as String) < 0)
    throw ArgumentError('The end date must be on or after the start date.');
}
