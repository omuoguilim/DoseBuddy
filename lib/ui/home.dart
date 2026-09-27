import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:table_calendar/table_calendar.dart';
import '../core/records.dart';
import '../core/store.dart';
import '../core/reminders.dart';
import 'theme.dart';
import 'medication_editor.dart';
import 'record_editor.dart';
import 'settings.dart';
import 'scan.dart';
import 'insights.dart';
import 'timeline.dart';

class Home extends StatefulWidget {
  final AppStore store;
  final Reminders reminders;
  final Future<bool> Function() authenticate;
  const Home({
    super.key,
    required this.store,
    required this.reminders,
    required this.authenticate,
  });
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  DateTime selected = DateTime.now();
  DateTime focused = DateTime.now();
  String medicationFilter = 'Active';
  Future<void> push(Widget child) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => child));
  void edit([String? id]) => push(
    MedicationEditor(store: widget.store, reminders: widget.reminders, id: id),
  );
  void record(ScheduledDose dose, {bool prn = false}) => push(
    RecordEditor(
      store: widget.store,
      reminders: widget.reminders,
      dose: dose,
      prn: prn,
    ),
  );
  bool active(Json f) =>
      f['active'] == true &&
      (f['end'] == null ||
          (f['end'] as String).compareTo(dayKey(DateTime.now())) >= 0);
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.store, widget.reminders]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(['Today', 'Medications', 'Insights', 'History', 'Settings'][tab]),
        actions: tab == 1
            ? [
                IconButton(
                  tooltip: 'Scan prescription label',
                  onPressed: () => push(
                    ScanPage(store: widget.store, reminders: widget.reminders),
                  ),
                  icon: const Icon(Icons.document_scanner_outlined),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: tab == 0
            ? today()
            : tab == 1
            ? medications()
            : tab == 2
            ? InsightsPage(store: widget.store)
            : tab == 3
            ? history()
            : SettingsPage(
                store: widget.store,
                reminders: widget.reminders,
                authenticate: widget.authenticate,
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            label: 'Medications',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Insights',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    ),
  );
  Widget today() {
    final r = widget.store.records;
    final now = DateTime.now();
    final doses = r.schedule(now, now);
    final due = doses
        .where((d) => !d.at.isAfter(now) && !r.outcomes.containsKey(d.key))
        .length;
    final upcoming = doses
        .where((d) => d.at.isAfter(now) && !r.outcomes.containsKey(d.key))
        .length;
    final completed = doses.where((d) => r.status(d, now) == 'Taken').length;
    final next = doses.where((d) => !r.outcomes.containsKey(d.key)).firstOrNull;
    final displayName = (r.settings['displayName'] as String? ?? '').trim();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final prn = r.medications.entries.where((e) {
      final f = r.current(e.value as Json);
      return active(f) && (f['start'] as String).compareTo(dayKey(now)) <= 0 && f['type'] == 'as_needed';
    }).toList();
    return RefreshIndicator(
      onRefresh: () async {
        await widget.reminders.sync(widget.store.records);
        if (mounted) setState(() {});
      },
      child: ListView(
        key: const PageStorageKey('today'),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5B67CA), Color(0xFF9B8CE8)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayKey(now), style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text(
                  displayName.isEmpty ? greeting : '$greeting, $displayName',
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (displayName.isEmpty)
                  TextButton(
                    onPressed: () => setState(() => tab = 4),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Add your name in Settings →'),
                  ),
                const SizedBox(height: 12),
                Text(
                  due > 0
                      ? '$due dose${due == 1 ? '' : 's'} not recorded'
                      : upcoming > 0
                      ? '$upcoming dose${upcoming == 1 ? '' : 's'} later today'
                      : doses.isEmpty
                      ? 'No scheduled doses today'
                      : 'Today’s doses are recorded',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          if (widget.reminders.error != null) Notice(widget.reminders.error!),
          if (widget.reminders.through != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Reminders queued through ${dayKey(widget.reminders.through!)}. Open the app regularly to refresh them.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          if (doses.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                SizedBox(
                  height: 52,
                  width: 52,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                      value: completed / doses.length,
                      strokeWidth: 6,
                      backgroundColor: const Color(0xFFEEEFFF),
                    ),
                    Text('$completed/${doses.length}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Daily progress',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    Text('$completed recorded taken · $upcoming upcoming',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                )),
              ]),
            ),
          if (next != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEFFF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('NEXT DOSE', style: TextStyle(
                    color: ink, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                const SizedBox(height: 12),
                Text(next.details['name'] as String,
                    style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w800, color: deepInk)),
                Text('${clockLabel(next.at.hour * 60 + next.at.minute)} · ${next.details['strength']}',
                    style: const TextStyle(color: muted)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: widget.store.busy ? null : () => record(next),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Review dose'),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          if (doses.isEmpty && prn.isEmpty)
            const Text(
              'Add a medication using the directions on your prescription.',
            ),
          if (doses.isNotEmpty)
            const Text('Today’s doses', style: TextStyle(
                fontSize: 21, fontWeight: FontWeight.w800, color: deepInk)),
          const SizedBox(height: 12),
          ...doseGroup('Morning', doses.where((d) => d.at.hour < 12).toList()),
          ...doseGroup('Afternoon', doses.where((d) => d.at.hour >= 12 && d.at.hour < 17).toList()),
          ...doseGroup('Evening', doses.where((d) => d.at.hour >= 17).toList()),
          if (prn.isNotEmpty)
            Section(
              'As needed',
              Column(
                children: prn.map((e) {
                  final f = r.current(e.value as Json);
                  final prior =
                      r.outcomes.values
                          .cast<Json>()
                          .where(
                            (x) =>
                                (x['dose'] as Json)['medicationId'] == e.key &&
                                x['status'] == 'Taken',
                          )
                          .toList()
                        ..sort(
                          (a, b) => (b['takenAt'] as String? ?? '').compareTo(
                            a['takenAt'] as String? ?? '',
                          ),
                        );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${f['name']} · ${f['strength']}'),
                    subtitle: Text(
                      prior.isEmpty
                          ? 'No dose recorded'
                          : 'Last recorded: ${prior.first['takenAt']}',
                    ),
                    trailing: const Icon(Icons.add),
                    onTap: () => record(
                      ScheduledDose('prn_${const Uuid().v4()}', e.key, now, f),
                      prn: true,
                    ),
                  );
                }).toList(),
              ),
            ),
          ...r.medications.entries
              .where((e) {
                final m = e.value as Json;
                return r.settings['refillAlerts'] != false && active(r.current(m)) &&
                    m['supply'] != null &&
                    m['threshold'] != null &&
                    (m['supply'] as num) <= (m['threshold'] as num);
              })
              .map(
                (e) => Notice(
                  '${r.current(e.value as Json)['name']}: ${(e.value as Json)['supply']} remaining. Check your supply and arrange a refill if needed.',
                ),
              ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => edit(),
                icon: const Icon(Icons.add),
                label: const Text('Add medication'),
              ),
              OutlinedButton.icon(
                onPressed: () => push(SymptomEditor(store: widget.store)),
                icon: const Icon(Icons.edit_note),
                label: const Text('Log symptom'),
              ),
              OutlinedButton.icon(
                onPressed: () => push(TimelinePage(store: widget.store)),
                icon: const Icon(Icons.timeline_outlined),
                label: const Text('Timeline'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> doseGroup(String label, List<ScheduledDose> doses) => [
    if (doses.isNotEmpty) ...[
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 12),
        child: Text(label, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
      ),
      ...doses.map(doseRow),
    ],
  ];

  Widget doseRow(ScheduledDose d) {
    final status = widget.store.records.status(d, DateTime.now());
    final taken = status == 'Taken';
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE4E7F2)),
      ),
      child: Semantics(
        button: true,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          leading: Icon(
            taken
                ? Icons.check_circle_outline
                : status == 'Skipped'
                ? Icons.remove_circle_outline
                : Icons.schedule,
            color: ink,
          ),
          title: Text(d.details['name'] as String),
          subtitle: Text(
            '${clockLabel(d.at.hour * 60 + d.at.minute)} · ${d.details['strength']}\n$status',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: widget.store.busy ? null : () => record(d),
        ),
      ),
    );
  }

  Widget medications() {
    final r = widget.store.records;
    final entries = r.medications.entries
        .where((e) {
          final f = r.current(e.value as Json);
          final isActive = active(f);
          return medicationFilter == 'As needed'
              ? isActive && f['type'] == 'as_needed'
              : medicationFilter == 'Paused / ended'
              ? !isActive
              : isActive && f['type'] != 'as_needed';
        })
        .toList();
    return ListView(
      key: const PageStorageKey('medications'),
      padding: const EdgeInsets.all(20),
      children: [
        FilledButton.icon(
          onPressed: () => edit(),
          icon: const Icon(Icons.add),
          label: const Text('Add medication'),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final label in ['Active', 'As needed', 'Paused / ended'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: medicationFilter == label,
                  onSelected: (_) => setState(() => medicationFilter = label),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 18),
        if (entries.isEmpty) const Text('No medications in this view.'),
        ...entries.map((e) {
          final f = r.current(e.value as Json);
          final med = e.value as Json;
          return Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => push(MedicationDetail(
                store: widget.store,
                reminders: widget.reminders,
                id: e.key,
              )),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFEEEFFF),
                      child: Icon(Icons.medication_outlined, color: ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f['name'] as String, style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: deepInk)),
                        Text('${f['strength']} · ${f['form']}',
                            style: const TextStyle(color: muted)),
                      ],
                    )),
                    const Icon(Icons.chevron_right),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Chip(label: Text(!active(f)
                        ? 'Paused or ended'
                        : f['type'] == 'as_needed'
                        ? 'As needed'
                        : (f['times'] as List).cast<int>().map(clockLabel).join(', '))),
                    if (med['supply'] != null)
                      Chip(label: Text('${med['supply']} ${f['unit']} remaining')),
                    if ((f['food'] as String? ?? '').isNotEmpty &&
                        f['food'] != 'No preference')
                      Chip(label: Text(f['food'] as String)),
                  ]),
                  if ((f['reason'] as String? ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('For ${f['reason']}',
                          style: const TextStyle(color: muted)),
                    ),
                  if (med['supply'] != null && med['threshold'] != null &&
                      (med['supply'] as num) <= (med['threshold'] as num))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Running low · check your supply',
                          style: TextStyle(color: Color(0xFF8A5A16))),
                    ),
                ]),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget history() {
    final r = widget.store.records;
    final rows = r.schedule(selected, selected);
    final c = r.counts(
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day - 29,
      ),
      DateTime.now(),
    );
    final prn = r.outcomes.values.cast<Json>().where(
      (e) =>
          e['prn'] == true &&
          dayKey(
                DateTime.parse(
                  e['takenAt'] as String? ?? e['recordedAt'] as String,
                ),
              ) ==
              dayKey(selected),
    );
    final symptoms = (r.data['symptoms'] as Json).entries.where(
      (e) =>
          dayKey(DateTime.parse((e.value as Json)['at'] as String)) ==
          dayKey(selected),
    );
    return ListView(
      key: const PageStorageKey('history'),
      padding: const EdgeInsets.all(20),
      children: [
        Section(
          'Last 30 days',
          Text(
            '${c['taken']} recorded taken · ${c['skipped']} skipped\n${c['unrecorded']} not recorded out of ${c['scheduled']} scheduled doses due. As-needed doses are separate.',
          ),
        ),
        for (final note in r.data['migrationNotes'] as List)
          Notice(note as String),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  'Calendar · ${dayKey(selected)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TableCalendar<ScheduledDose>(
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: focused,
                selectedDayPredicate: (date) => isSameDay(selected, date),
                onDaySelected: (date, month) => setState(() {
                  selected = date;
                  focused = month;
                }),
                onPageChanged: (month) => setState(() => focused = month),
                eventLoader: (date) => r.schedule(date, date),
                calendarBuilders: CalendarBuilders<ScheduledDose>(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return null;
                    final statuses = events.map((dose) => r.status(dose, DateTime.now()));
                    final color = statuses.contains('Skipped')
                        ? const Color(0xFFC65353)
                        : statuses.every((status) => status == 'Taken')
                        ? const Color(0xFF2E8B57)
                        : statuses.contains('Upcoming')
                        ? const Color(0xFFB7791F)
                        : ink;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(bottom: 5),
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    );
                  },
                ),
                calendarStyle: const CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: ink, shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Color(0xFF9B8CE8), shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: ink, shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (rows.isEmpty && prn.isEmpty && symptoms.isEmpty)
          const Text('No records for this date.'),
        ...rows.map(doseRow),
        ...prn.map((e) {
          final d = ScheduledDose.fromSnapshot(e['dose'] as Json);
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(d.details['name'] as String),
            subtitle: Text(
              'As needed · ${e['amount']} ${d.details['unit']} · ${e['takenAt']}',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => record(d, prn: true),
          );
        }),
        ...symptoms.map((e) {
          final s = e.value as Json;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s['name'] as String),
            subtitle: Text('Symptom · ${s['severity']}/5 · ${s['duration']}'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => push(SymptomEditor(store: widget.store, id: e.key)),
          );
        }),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => push(ExportPage(store: widget.store)),
          icon: const Icon(Icons.ios_share),
          label: const Text('Review and export records'),
        ),
      ],
    );
  }
}

class MedicationDetail extends StatelessWidget {
  final AppStore store;
  final Reminders reminders;
  final String id;
  const MedicationDetail({
    super.key,
    required this.store,
    required this.reminders,
    required this.id,
  });
  Future<void> quantity(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update remaining supply'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Total remaining now',
            helperText: 'A new baseline for future records.',
            helperMaxLines: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      final n = num.parse(value);
      if (!n.isFinite || n < 0) throw ArgumentError('Enter a valid quantity.');
      await store.update((r) {
        final med = r.medications[id] as Json;
        (r.data['audit'] as List).add({
          'action': 'supply reconciled',
          'id': id,
          'previous': med['supply'],
          'new': n,
          'at': DateTime.now().toIso8601String(),
        });
        med['supply'] = n;
        for (final raw in r.outcomes.values) {
          final o = raw as Json;
          if ((o['dose'] as Json)['medicationId'] == id) {
            o['inventoryDeduction'] = 0;
            o['inventoryReconciled'] = true;
          }
        }
      });
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final r = store.records;
      final med = r.medications[id] as Json?;
      if (med == null)
        return const Scaffold(body: Center(child: Text('Medication removed')));
      final f = r.current(med);
      return Scaffold(
        appBar: AppBar(title: const Text('Medication details')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              f['name'] as String,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            Text('${f['strength']} · ${f['form']}'),
            const SizedBox(height: 24),
            Section(
              'Directions',
              Text(
                '${f['amount']} ${f['unit']}\n${f['type'] == 'as_needed' ? 'As needed' : (f['times'] as List).cast<int>().map(clockLabel).join(', ')}\n${f['food']}\n${f['instructions']}',
              ),
            ),
            Section(
              'Course',
              Text(
                '${f['start']} through ${f['end'] ?? 'no end date'}\n${f['active'] == true ? 'Active' : 'Paused'}',
              ),
            ),
            if (med['supply'] != null)
              Section(
                'Supply',
                Text('${med['supply']} ${f['unit']} remaining (estimate)'),
              ),
            for (final field in ['reason', 'prescriber', 'pharmacy', 'notes'])
              if ((f[field] as String? ?? '').isNotEmpty)
                Section(
                  field[0].toUpperCase() + field.substring(1),
                  Text(f[field] as String),
                ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: store.busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => MedicationEditor(
                              store: store,
                              reminders: reminders,
                              id: id,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit medication'),
                ),
                OutlinedButton(
                  onPressed: store.busy ? null : () => quantity(context),
                  child: const Text('Update supply'),
                ),
                OutlinedButton(
                  onPressed: store.busy
                      ? null
                      : () async {
                          try {
                            await store.update(
                              (r) => r.changeActive(
                                id,
                                f['active'] != true,
                                DateTime.now(),
                              ),
                            );
                            await reminders.sync(store.records);
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          }
                        },
                  child: Text(
                    f['active'] == true
                        ? 'Pause reminders'
                        : 'Resume reminders',
                  ),
                ),
              ],
            ),
            const Notice(
              'These are directions you entered, not verified drug information. For interactions, missed doses, or changes to treatment, contact your pharmacist or clinician.',
            ),
            TextButton(
              onPressed: store.busy
                  ? null
                  : () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(
                            'Permanently delete this medication?',
                          ),
                          content: const Text(
                            'This removes its schedule, dose history and related audit records. Symptom notes remain, with the medication link removed. Use Pause or an end date to keep history.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (yes != true) return;
                      try {
                        await store.update((r) {
                          r.medications.remove(id);
                          r.outcomes.removeWhere(
                            (_, v) => (v['dose'] as Json)['medicationId'] == id,
                          );
                          for (final s in (r.data['symptoms'] as Json).values) {
                            if (s['medicationId'] == id)
                              s['medicationId'] = null;
                          }
                          (r.data['audit'] as List).removeWhere(
                            (a) =>
                                a['id'] == id ||
                                a['medicationId'] == id ||
                                (a['previous'] is Map &&
                                    a['previous']['dose'] is Map &&
                                    a['previous']['dose']['medicationId'] ==
                                        id),
                          );
                        });
                        await reminders.sync(store.records);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
              child: const Text(
                'Permanently delete',
                style: TextStyle(color: Color(0xFFA22C29)),
              ),
            ),
          ],
        ),
      );
    },
  );
}
