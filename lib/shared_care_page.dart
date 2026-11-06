import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'demo/demo_mode.dart';
import 'models/medication.dart';

/// Cloud records are deliberately separate from this device's private history.
/// Caregivers never replace the Hive box or switch the signed-in account.
class SharedCarePage extends StatefulWidget {
  final String ownerUid;
  const SharedCarePage({super.key, required this.ownerUid});
  @override
  State<SharedCarePage> createState() => _SharedCarePageState();
}

class _SharedCarePageState extends State<SharedCarePage> {
  Map<String, dynamic>? _profile;
  String? _error;
  bool _busy = false;
  final _random = Random.secure();
  bool get _isOwner => FirebaseAuth.instance.currentUser?.uid == widget.ownerUid;
  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'us-east1');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _busy = true; _error = null; _profile = null; });
    try {
      final result = await _functions.httpsCallable('getCareProfile').call({'ownerUid': widget.ownerUid});
      if (mounted) setState(() => _profile = Map<String, dynamic>.from(result.data as Map));
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Could not open shared records.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not connect. Refresh to try again.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _publish() async {
    final approved = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Publish your routine?'),
      content: const Text('This uploads medication names, strengths and scheduled times to your shared profile. Accepted caregivers can view these according to their permissions. Photos, symptom notes and your private local dose history are not uploaded. Shared dose records start separately here. Publishing again updates the routine; it does not erase shared history.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Publish'))],
    ));
    if (approved != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('dosebuddy_local_owner_uid') != widget.ownerUid) {
        throw StateError('Local data ownership must be confirmed by signing in again.');
      }
      final medications = Hive.box<Medication>(DemoMode.boxName).values.map((med) => {
        'id': med.id, 'name': med.name, 'dosage': med.dosage,
        'times': med.isScheduledFor(DateTime.now()) ? med.timesFor(DateTime.now()) : <String>[],
        'archived': med.scheduleFor(DateTime.now())['archived'] == true,
      }).toList();
      await _functions.httpsCallable('publishCareProfile').call({
        'displayName': prefs.getString('user_name') ?? 'Family member',
        'expectedRevision': _profile?['revision'] ?? 0, 'medications': medications,
      });
      await _load();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Could not publish.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not publish. Check your connection and sign in again if needed.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _stop() async {
    final approved = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Stop all sharing?'),
      content: const Text('This disables shared profile access and revokes current invitations. It cannot remove copies someone already saw or saved.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Stop sharing'))],
    ));
    if (approved != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _functions.httpsCallable('stopCareSharing').call();
      await _load();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Could not stop sharing.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not connect. Try again.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _record(Map<String, dynamic> med) async {
    var date = DateTime.now();
    var time = (med['times'] as List).first as String;
    var state = 'taken';
    final reason = TextEditingController();
    final submit = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(
      builder: (c, update) => AlertDialog(
        title: Text('Record ${med['name']}'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextButton(onPressed: () async {
            final next = await showDatePicker(context: c, initialDate: date,
              firstDate: DateTime(2020), lastDate: DateTime.now());
            if (next != null) update(() => date = next);
          }, child: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}')),
          DropdownButtonFormField<String>(initialValue: time, decoration: const InputDecoration(labelText: 'Scheduled time'),
            items: [for (final t in med['times'] as List) DropdownMenuItem(value: t as String, child: Text(t))],
            onChanged: (v) => update(() => time = v!)),
          DropdownButtonFormField<String>(initialValue: state, decoration: const InputDecoration(labelText: 'Record'),
            items: const [DropdownMenuItem(value: 'taken', child: Text('Taken')),
              DropdownMenuItem(value: 'missed', child: Text('Confirmed missed')),
              DropdownMenuItem(value: 'skipped', child: Text('Intentionally skipped')),
              DropdownMenuItem(value: 'unknown', child: Text('Unknown / correct earlier record'))],
            onChanged: (v) => update(() => state = v!)),
          TextField(controller: reason, maxLength: 500, decoration: const InputDecoration(labelText: 'Reason or correction note')),
          const Text('The server records who made this entry and when. Earlier entries remain in the audit history.'),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save record'))],
      ),
    ));
    final note = reason.text;
    reason.dispose();
    if (submit != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      final histories = _profile!['histories'] as Map;
      final history = histories[med['id']] as Map?;
      await _functions.httpsCallable('recordSharedDose').call({
        'ownerUid': widget.ownerUid, 'medicationId': med['id'],
        'requestId': '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}',
        'expectedRevision': history?['revision'] ?? 0,
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'scheduledTime': time, 'state': state, 'reason': note,
      });
      await _load();
    } on FirebaseFunctionsException catch (e) {
      // Clear potentially stale data even if this was a revoked grant.
      if (mounted) setState(() { _profile = null; _error = e.message ?? 'Refresh before trying again.'; });
    } catch (_) {
      if (mounted) setState(() { _profile = null; _error = 'Save could not be confirmed. Refresh the history before recording again.'; });
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _audit(Map<String, dynamic> med) async {
    setState(() => _busy = true);
    try {
      final result = await _functions.httpsCallable('getSharedDoseAudit').call({
        'ownerUid': widget.ownerUid, 'medicationId': med['id'],
      });
      if (!mounted) return;
      final events = (result.data as Map)['events'] as List;
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: Text('${med['name']} correction history'),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (events.isEmpty) const Text('No shared changes yet.'),
            for (final event in events) ListTile(contentPadding: EdgeInsets.zero,
              title: Text('${event['entry']['date']} ${event['entry']['scheduledTime']}'),
              subtitle: Text('${event['previous']?['state'] ?? 'No record'} → ${event['entry']['state']}\n${event['entry']['reason']}\n${event['entry']['recordedAt']}')),
          ],
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
      ));
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() { _profile = null; _error = e.message ?? 'History unavailable.'; });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load correction history.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_profile?['displayName'] as String? ?? 'Shared medication profile'),
      actions: [IconButton(onPressed: _busy ? null : _load, tooltip: 'Refresh shared records', icon: const Icon(Icons.refresh))]),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Shared records are stored online separately from private records on this device. Refresh to see other caregivers’ changes. A missing entry does not mean a dose was missed.'),
      if (_profile?['sharingEnabled'] == false) const Text('Sharing is stopped. Publishing again requires new caregiver invitations.'),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
      if (_isOwner) ...[
        FilledButton(onPressed: _busy ? null : _publish, child: const Text('Publish / update my shared routine')),
        TextButton(onPressed: _busy || _profile == null ? null : _stop, child: const Text('Stop sharing and revoke invitations')),
      ],
      for (final raw in (_profile?['medications'] as List? ?? [])) _medication(Map<String, dynamic>.from(raw as Map)),
    ]),
  );

  Widget _medication(Map<String, dynamic> med) {
    final history = (_profile?['histories'] as Map?)?[med['id']] as Map?;
    final records = List<Map>.from(history?['records'] as List? ?? []);
    records.sort((a, b) => '${b['date']} ${b['scheduledTime']}'.compareTo('${a['date']} ${a['scheduledTime']}'));
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${med['name']} · ${med['dosage']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      Text((med['times'] as List).join(', ')),
      const Text('Published times snapshot. Confirm any schedule changes with the owner.'),
      if (med['archived'] == true) const Text('Archived'),
      if (_profile?['viewHistory'] != true) const Text('Dose history has not been shared with you.'),
      if (_profile?['viewHistory'] == true && records.isEmpty) const Text('No shared dose records yet.'),
      for (final record in records.take(20)) Padding(padding: const EdgeInsets.only(top: 8), child:
        Text('${record['date']} ${record['scheduledTime']}: ${record['state']}\nRecorded by ${record['actorUid'] == FirebaseAuth.instance.currentUser?.uid ? 'you' : 'another authorized member'} at ${record['recordedAt']}')),
      if (_profile?['manageDoses'] == true && med['archived'] != true && (med['times'] as List).isNotEmpty)
        OutlinedButton(onPressed: _busy ? null : () => _record(med), child: const Text('Record / correct dose')),
      if (_profile?['viewHistory'] == true)
        TextButton(onPressed: _busy ? null : () => _audit(med), child: const Text('View correction history')),
    ])));
  }
}
