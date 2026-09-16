import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/medication.dart';
import 'models/dose_event.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  String period = '7d';
  static const purple = Color(0xFF5B67CA);
  static const ink = Color(0xFF171A2B);
  static const muted = Color(0xFF8B93AA);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Medication>>(
      valueListenable: Hive.box<Medication>('medications').listenable(),
      builder: (_, __, ___) => ValueListenableBuilder<Box<DoseEvent>>(
        valueListenable: Hive.box<DoseEvent>('dose_events').listenable(),
        builder: (_, __, ___) {
          final data = _calculate(period == '7d' ? 7 : 30);
          return Scaffold(
            backgroundColor: const Color(0xFFF7F8FC),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Insights', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: ink, letterSpacing: -1.2)),
                  const SizedBox(height: 6),
                  const Text('Understand your medication routine', style: TextStyle(fontSize: 16, color: muted)),
                  const SizedBox(height: 22),
                  _periodSelector(),
                  const SizedBox(height: 22),
                  if (data.eligible == 0) _learningCard() else ...[
                    _scoreCard(data),
                    const SizedBox(height: 16),
                    _metricRow(data),
                    const SizedBox(height: 28),
                    const Text('DoseBuddy noticed', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
                    const SizedBox(height: 12),
                    ..._insightCards(data),
                    const SizedBox(height: 28),
                    _sectionTitle('By time of day', 'See where your routine is strongest'),
                    const SizedBox(height: 12),
                    _timeCard(data),
                    const SizedBox(height: 28),
                    _sectionTitle('By medication', 'Adherence for each active medication'),
                    const SizedBox(height: 12),
                    _medicationCard(data),
                    const SizedBox(height: 28),
                    _sectionTitle('Recent days', period == '7d' ? 'Your last 7 days' : 'Your last 30 days'),
                    const SizedBox(height: 12),
                    _daysCard(data),
                  ],
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _periodSelector() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: const Color(0xFFEFF1F8), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      _periodButton('7 days', '7d'),
      _periodButton('30 days', '30d'),
    ]),
  );

  Widget _periodButton(String label, String value) {
    final selected = period == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => period = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(11), boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 8)] : []),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? ink : muted)),
      ),
    ));
  }

  Widget _learningCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 25, backgroundColor: Color(0xFFE8E9FF), child: Icon(Icons.auto_awesome_rounded, color: purple)),
      SizedBox(height: 18),
      Text('DoseBuddy is learning your routine', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: ink)),
      SizedBox(height: 8),
      Text('Keep logging your scheduled doses. Personalized patterns will appear here as DoseBuddy learns what parts of your routine work best.', style: TextStyle(fontSize: 15, height: 1.45, color: muted)),
    ]),
  );

  Widget _scoreCard(_InsightData d) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF5864D8), Color(0xFF7D6BE8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(26),
      boxShadow: [BoxShadow(color: purple.withValues(alpha: .20), blurRadius: 24, offset: const Offset(0, 10))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('DOSEBUDDY SCORE', style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: Colors.white70)),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${d.score.round()}', style: const TextStyle(fontSize: 58, height: .95, fontWeight: FontWeight.w800, color: Colors.white)),
        const Padding(padding: EdgeInsets.only(bottom: 7), child: Text('/100', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white70))),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)), child: Text(_scoreLabel(d.score), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 16),
      Text('${d.completed} of ${d.eligible} completed doses • ${d.onTime} on time', style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 18),
      ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: d.score / 100, minHeight: 8, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white))),
      const SizedBox(height: 10),
      const Text('Score combines completion (80%) and on-time consistency (20%).', style: TextStyle(fontSize: 11.5, color: Colors.white60)),
    ]),
  );

  Widget _metricRow(_InsightData d) => Row(children: [
    Expanded(child: _metric('${d.adherence.round()}%', 'Adherence', Icons.check_circle_outline_rounded)),
    const SizedBox(width: 10),
    Expanded(child: _metric('${d.onTimeRate.round()}%', 'On time', Icons.schedule_rounded)),
    const SizedBox(width: 10),
    Expanded(child: _metric('${d.missed}', 'Missed', Icons.error_outline_rounded)),
  ]);

  Widget _metric(String value, String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19)),
    child: Column(children: [Icon(icon, color: purple, size: 21), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 11.5, color: muted))]),
  );

  List<Widget> _insightCards(_InsightData d) {
    final cards = <Widget>[];
    if (d.eligible < 5) {
      cards.add(_insight(Icons.auto_awesome_rounded, 'Still learning', 'Log a few more doses and DoseBuddy will start surfacing stronger patterns from your routine.', const Color(0xFFEEEFFF), purple));
    } else {
      final hardest = d.windows.entries.where((e) => e.value.eligible > 0).toList()..sort((a,b) => a.value.rate.compareTo(b.value.rate));
      if (hardest.isNotEmpty && hardest.first.value.rate < 90) {
        final h = hardest.first;
        cards.add(_insight(Icons.schedule_rounded, '${h.key} doses need attention', 'You completed ${h.value.rate.round()}% of eligible ${h.key.toLowerCase()} doses. This is currently your hardest dose window.', const Color(0xFFFFF3E8), const Color(0xFFE18A2B)));
      } else {
        cards.add(_insight(Icons.verified_rounded, 'Your routine is consistent', 'You are completing doses reliably across your daily medication windows.', const Color(0xFFEAF8F0), const Color(0xFF2F9A64)));
      }
      if (d.topMissReason != null) {
        cards.add(_insight(Icons.lightbulb_outline_rounded, 'A reason keeps showing up', '“${d.topMissReason}” is your most common reason for skipping a dose in this period.', const Color(0xFFF1EEFF), purple));
      }
      if (d.previousEligible >= 3) {
        final diff = d.adherence - d.previousAdherence;
        if (diff.abs() >= 5) {
          cards.add(_insight(diff > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, diff > 0 ? 'Your routine is improving' : 'Your routine dipped', 'Adherence is ${diff.abs().round()} points ${diff > 0 ? 'higher' : 'lower'} than the previous ${period == '7d' ? '7 days' : '30 days'}.', diff > 0 ? const Color(0xFFEAF8F0) : const Color(0xFFFFEEEE), diff > 0 ? const Color(0xFF2F9A64) : const Color(0xFFD75B5B)));
        }
      }
    }
    return cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)).toList();
  }

  Widget _insight(IconData icon, String title, String body, Color bg, Color accent) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .72), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: accent, size: 22)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 5), Text(body, style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF666E82)))])),
    ]),
  );

  Widget _sectionTitle(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(fontSize: 13.5, color: muted))]);

  Widget _timeCard(_InsightData d) => Container(
    padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
    child: Column(children: ['Morning','Afternoon','Evening'].map((name) {
      final w = d.windows[name]!;
      final icon = name == 'Morning' ? Icons.wb_sunny_outlined : name == 'Afternoon' ? Icons.light_mode_outlined : Icons.nightlight_outlined;
      return Padding(padding: EdgeInsets.only(bottom: name == 'Evening' ? 0 : 20), child: Row(children: [
        Icon(icon, color: purple, size: 22), const SizedBox(width: 12), SizedBox(width: 76, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: ink))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: w.eligible == 0 ? 0 : w.rate/100, minHeight: 8, backgroundColor: const Color(0xFFF0F1F6), valueColor: const AlwaysStoppedAnimation(purple)))),
        const SizedBox(width: 12), SizedBox(width: 42, child: Text(w.eligible == 0 ? '—' : '${w.rate.round()}%', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, color: ink))),
      ]));
    }).toList()),
  );

  Widget _medicationCard(_InsightData d) {
    if (d.byMedication.isEmpty) return _simpleEmpty('No medication data yet.');
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(children: d.byMedication.entries.map((e) {
        final m = e.value;
        return Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(e.key, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ink))), Text('${m.rate.round()}%', style: const TextStyle(fontWeight: FontWeight.w800, color: purple))]),
          const SizedBox(height: 7),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: m.eligible == 0 ? 0 : m.rate/100, minHeight: 7, backgroundColor: const Color(0xFFF0F1F6), valueColor: const AlwaysStoppedAnimation(purple))),
          const SizedBox(height: 6), Text('${m.completed} of ${m.eligible} eligible doses completed', style: const TextStyle(fontSize: 12, color: muted)),
        ]));
      }).toList()),
    );
  }

  Widget _daysCard(_InsightData d) => Container(
    padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
    child: period == '7d'
      ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: d.days.map((day) => _dayDot(day)).toList())
      : Column(children: [
          Row(children: [Expanded(child: _miniStat('${d.perfectDays}', 'Perfect days')), Expanded(child: _miniStat('${d.daysWithDoses}', 'Days tracked'))]),
          const SizedBox(height: 14),
          Text('30-day view summarizes your consistency without crowding the screen.', style: const TextStyle(fontSize: 12.5, color: muted)),
        ]),
  );

  Widget _dayDot(_DayData d) => Column(children: [
    Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: d.eligible == 0 ? const Color(0xFFF1F2F6) : d.rate >= 99 ? const Color(0xFFE5F7EC) : d.rate >= 70 ? const Color(0xFFFFF1DF) : const Color(0xFFFFE8E8)), child: Icon(d.eligible == 0 ? Icons.remove : d.rate >= 99 ? Icons.check_rounded : Icons.circle, size: d.rate >= 99 ? 18 : 8, color: d.eligible == 0 ? muted : d.rate >= 99 ? const Color(0xFF2F9A64) : d.rate >= 70 ? const Color(0xFFE18A2B) : const Color(0xFFD75B5B))),
    const SizedBox(height: 7), Text(d.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
  ]);

  Widget _miniStat(String value, String label) => Column(children: [Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 12, color: muted))]);
  Widget _simpleEmpty(String text) => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Text(text, style: const TextStyle(color: muted)));

  String _scoreLabel(double score) => score >= 90 ? 'Excellent' : score >= 80 ? 'Strong' : score >= 65 ? 'Building' : 'Needs attention';

  _InsightData _calculate(int days) {
    final meds = Hive.box<Medication>('medications').values.toList();
    final events = Hive.box<DoseEvent>('dose_events').values.toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    final previousStart = start.subtract(Duration(days: days));

    final medById = {for (final m in meds) m.id: m};
    final eventByKey = <String, DoseEvent>{};
    for (final e in events) {
      eventByKey['${e.medicationId}_${e.scheduledAt.millisecondsSinceEpoch}'] = e;
    }

    final current = _aggregate(meds, medById, eventByKey, start, now);
    final previousEnd = start.subtract(const Duration(milliseconds: 1));
    final previous = _aggregate(meds, medById, eventByKey, previousStart, previousEnd);

    final dayData = <_DayData>[];
    int perfectDays = 0;
    int daysWithDoses = 0;
    for (int i = 0; i < days; i++) {
      final date = start.add(Duration(days: i));
      final end = i == days - 1 ? now : DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
      final a = _aggregate(meds, medById, eventByKey, date, end);
      if (a.eligible > 0) {
        daysWithDoses++;
        if (a.completed == a.eligible) perfectDays++;
      }
      dayData.add(_DayData(_weekday(date), a.eligible, a.completed));
    }

    return _InsightData(
      eligible: current.eligible, completed: current.completed, onTime: current.onTime, missed: current.missed,
      skipped: current.skipped, byMedication: current.byMedication, windows: current.windows,
      missReasons: current.missReasons, previousEligible: previous.eligible, previousCompleted: previous.completed,
      days: dayData, perfectDays: perfectDays, daysWithDoses: daysWithDoses,
    );
  }

  _Aggregate _aggregate(List<Medication> meds, Map<String, Medication> medById, Map<String, DoseEvent> eventByKey, DateTime start, DateTime end) {
    final a = _Aggregate();
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    for (DateTime date = startDay; !date.isAfter(endDay); date = date.add(const Duration(days: 1))) {
      for (final med in meds) {
        if (med.isAsNeeded || med.isCompleted || !med.isScheduledFor(date)) continue;
        for (final time in med.times) {
          final scheduled = _scheduledAt(date, time);
          final key = '${med.id}_${scheduled.millisecondsSinceEpoch}';
          final event = eventByKey[key];
          final legacyTaken = med.wasTakenOn(date, time);
          // Future scheduled doses are excluded UNLESS the user has already
          // explicitly resolved them (taken/skipped). This makes Insights react
          // immediately during testing and also handles early doses correctly.
          if (scheduled.isBefore(start)) continue;
          if (scheduled.isAfter(end) && event == null && !legacyTaken) continue;
          final graceEnd = scheduled.add(Duration(minutes: med.gracePeriodMinutes));
          final hasOutcome = event != null || legacyTaken || end.isAfter(graceEnd);
          if (!hasOutcome) continue;

          a.eligible++;
          final medStat = a.byMedication.putIfAbsent(med.name, () => _Bucket());
          final window = a.windows[_windowName(scheduled.hour)]!;
          medStat.eligible++;
          window.eligible++;

          final status = event?.status;
          final completed = legacyTaken || status == 'taken' || status == 'late';
          if (completed) {
            a.completed++; medStat.completed++; window.completed++;
            final takenAt = event?.takenAt;
            final isOnTime = status == 'taken' || (status == null && legacyTaken) || (takenAt != null && !takenAt.isAfter(graceEnd));
            if (isOnTime) a.onTime++;
          } else {
            a.missed++;
            if (status == 'skipped') {
              a.skipped++;
              final reason = event?.reason;
              if (reason != null && reason.trim().isNotEmpty) a.missReasons[reason] = (a.missReasons[reason] ?? 0) + 1;
            }
          }
        }
      }
    }
    return a;
  }

  DateTime _scheduledAt(DateTime date, String time) {
    final parts = time.trim().split(' ');
    final hm = parts[0].split(':');
    int hour = int.parse(hm[0]);
    final minute = int.parse(hm[1]);
    final pm = parts.length > 1 && parts[1].toUpperCase() == 'PM';
    if (pm && hour != 12) hour += 12;
    if (!pm && hour == 12) hour = 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _windowName(int hour) => hour < 12 ? 'Morning' : hour < 17 ? 'Afternoon' : 'Evening';
  String _weekday(DateTime d) => const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d.weekday - 1];
}

class _Bucket {
  int eligible = 0;
  int completed = 0;
  double get rate => eligible == 0 ? 0 : completed / eligible * 100;
}

class _Aggregate {
  int eligible = 0;
  int completed = 0;
  int onTime = 0;
  int missed = 0;
  int skipped = 0;
  final Map<String, _Bucket> byMedication = {};
  final Map<String, _Bucket> windows = {'Morning': _Bucket(), 'Afternoon': _Bucket(), 'Evening': _Bucket()};
  final Map<String, int> missReasons = {};
}

class _DayData {
  final String label;
  final int eligible;
  final int completed;
  _DayData(this.label, this.eligible, this.completed);
  double get rate => eligible == 0 ? 0 : completed / eligible * 100;
}

class _InsightData {
  final int eligible, completed, onTime, missed, skipped, previousEligible, previousCompleted, perfectDays, daysWithDoses;
  final Map<String, _Bucket> byMedication, windows;
  final Map<String, int> missReasons;
  final List<_DayData> days;
  _InsightData({required this.eligible, required this.completed, required this.onTime, required this.missed, required this.skipped, required this.byMedication, required this.windows, required this.missReasons, required this.previousEligible, required this.previousCompleted, required this.days, required this.perfectDays, required this.daysWithDoses});
  double get adherence => eligible == 0 ? 0 : completed / eligible * 100;
  double get onTimeRate => completed == 0 ? 0 : onTime / completed * 100;
  double get score => (adherence * .8 + onTimeRate * .2).clamp(0, 100).toDouble();
  double get previousAdherence => previousEligible == 0 ? 0 : previousCompleted / previousEligible * 100;
  String? get topMissReason {
    if (missReasons.isEmpty) return null;
    final entries = missReasons.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    return entries.first.key;
  }
}
