import 'package:flutter/material.dart';
import 'models/medication.dart';
import 'detailpage.dart';
import 'widgets/side_effects_dialog.dart';
import 'widgets/dosebuddy_theme.dart';

class MySquare extends StatefulWidget {
  final Medication medication;
  final String displayTime;
  final VoidCallback? onStatusChanged;

  const MySquare({
    super.key,
    required this.medication,
    required this.displayTime,
    this.onStatusChanged,
  });

  @override
  State<MySquare> createState() => _MySquareState();
}

class _MySquareState extends State<MySquare> with SingleTickerProviderStateMixin {
  bool _working = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  // Pill color pairs (light, dark)
  static const List<List<Color>> pillColors = [
    [Color(0xFFEAE6FF), Color(0xFF5B67CA)],
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _getPillColors() {
    // Use medication ID hashCode to determine color (consistent per medication)
    final index = widget.medication.id.hashCode.abs() % pillColors.length;
    return pillColors[index];
  }

  String get _currentStatus {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    return widget.medication.getStatusForDateTime(normalizedToday, widget.displayTime);
  }

  Color get _statusColor {
    switch (_currentStatus) {
      case 'taken':
        return DoseBuddyTheme.purple;
      case 'grace_period':
        return Colors.amber;
      case 'missed':
        return Colors.red;
      case 'skipped':
        return const Color(0xFF79728E);
      case 'upcoming':
      default:
        return const Color(0xFF5B67CA);
    }
  }

  IconData get _statusIcon {
    switch (_currentStatus) {
      case 'taken':
        return Icons.check_circle_rounded;
      case 'grace_period':
        return Icons.schedule_rounded;
      case 'missed':
        return Icons.cancel_rounded;
      case 'skipped':
        return Icons.remove_circle_outline;
      case 'upcoming':
      default:
        return Icons.access_time_rounded;
    }
  }

  String get _statusText {
    switch (_currentStatus) {
      case 'taken':
        return 'Taken';
      case 'grace_period':
        return 'Grace Period';
      case 'missed':
        return 'Missed';
      case 'skipped':
        return 'Skipped';
      case 'unrecorded':
        return 'Not recorded';
      case 'upcoming':
      default:
        return 'Upcoming';
    }
  }

  Future<void> _markAsTaken() async {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    if (widget.medication.wasTakenOn(normalizedToday, widget.displayTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Already marked as taken for this time'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final shouldLogSideEffects = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mark as Taken'),
        content: const Text('Did you experience any side effects?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Log Side Effects'),
          ),
        ],
      ),
    );

    if (shouldLogSideEffects == null) return;

    widget.medication.markAsTakenOn(normalizedToday, widget.displayTime);
    await widget.medication.save();

    if (shouldLogSideEffects && mounted) {
      await showDialog(
        context: context,
        builder: (context) => SideEffectsDialog(
          medication: widget.medication,
          takenDate: normalizedToday,
          takenTime: widget.displayTime,
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 5),
          showCloseIcon: true,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child:Text('${widget.medication.name} recorded taken')),
            ],
          ),
          action: SnackBarAction(label:'Undo',onPressed:()async{ScaffoldMessenger.of(context).removeCurrentSnackBar();widget.medication.recordDose(normalizedToday,widget.displayTime,'unknown',reason:'Undid taken entry');await widget.medication.save();if(mounted){widget.onStatusChanged?.call();setState((){});}}),
          backgroundColor: const Color(0xFF5B67CA),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      widget.onStatusChanged?.call();
      setState(() {});
    }
  }

  Future<void> _toggleSkipped() async {
    final today = DateTime.now();
    if (widget.medication.wasSkippedOn(today, widget.displayTime)) {
      widget.medication.clearSkippedOn(today, widget.displayTime);
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Skip this dose?'),
          content: Text('Record ${widget.medication.name} at ${widget.displayTime} as skipped? You can change this later.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Skip dose')),
          ],
        ),
      );
      if (confirmed != true) return;
      widget.medication.markAsSkippedOn(today, widget.displayTime);
    }
    await widget.medication.save();
    if (mounted) {
      widget.onStatusChanged?.call();
      setState(() {});
    }
  }

  Future<void> _unmarkAsTaken() async {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unmark as Taken'),
        content: Text('Are you sure you want to unmark ${widget.displayTime} dose?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unmark'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    widget.medication.recordDose(normalizedToday, widget.displayTime, 'unknown', reason: 'Corrected accidental Taken entry');

    await widget.medication.save();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.undo, color: Colors.white),
              const SizedBox(width: 12),
              Text('${widget.medication.name} unmarked'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      widget.onStatusChanged?.call();
      setState(() {});
    }
  }

  String _formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try { await action(); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update this record. Please check it before retrying.'))); }
    finally { if (mounted) setState(() => _working = false); }
  }
  Future<void> _details() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(medication: widget.medication, specificTime: widget.displayTime)));
    if (mounted) { widget.onStatusChanged?.call(); setState(() {}); }
  }
  @override
  Widget build(BuildContext context) {
    final isTaken = _currentStatus == 'taken';
    return ScaleTransition(scale: _scaleAnimation, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(onTap: _details, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
        const MedicationGlyph(), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.medication.name, style: Theme.of(context).textTheme.titleMedium),
          Text('Strength: ${widget.medication.dosage}', style: Theme.of(context).textTheme.bodySmall),
          Text(widget.displayTime, style: const TextStyle(fontWeight: FontWeight.w600)),
        ])), const Icon(Icons.chevron_right, color: DoseBuddyTheme.muted),
      ]))),
      const SizedBox(height: 8),
      Row(children: [Icon(_statusIcon, size: 18, color: _statusColor), const SizedBox(width: 6), Flexible(child: Text(_statusText, style: TextStyle(color: _statusColor, fontWeight: FontWeight.w600)))]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (!isTaken) ElevatedButton.icon(onPressed: _working ? null : () => _perform(_markAsTaken), icon: const Icon(Icons.check, size: 18), label: const Text('Record taken')),
        if (!isTaken) OutlinedButton(onPressed: _working ? null : () => _perform(_toggleSkipped), child: Text(_currentStatus == 'skipped' ? 'Undo skipped' : 'Skip dose')),
        if (isTaken) OutlinedButton.icon(onPressed: _working ? null : () => _perform(_unmarkAsTaken), icon: const Icon(Icons.undo, size: 18), label: const Text('Correct taken record')),
        TextButton(onPressed: _details, child: const Text('Details / symptoms')),
      ]),
    ]))));
  }
}
