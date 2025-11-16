import 'package:flutter/material.dart';
import 'models/medication.dart';
import 'edit_medication_page.dart';
import 'widgets/side_effects_dialog.dart';

class DetailPage extends StatefulWidget {
  final Medication medication;
  final String? specificTime; //Optional specific time to mark

  const DetailPage({
    super.key, 
    required this.medication,
    this.specificTime, //Accept specific time
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  // Pill color pairs (light, dark) - same as square.dart
  static const List<List<Color>> pillColors = [
    [Color(0xFFB3E5FC), Color(0xFF4FC3F7)], // Light blue, Blue
    [Color(0xFFFFCC80), Color(0xFFFF9800)], // Light orange, Orange
    [Color(0xFFEF9A9A), Color(0xFFE53935)], // Light red, Red
    [Color(0xFFE1BEE7), Color(0xFFAB47BC)], // Light purple, Purple
    [Color(0xFFA5D6A7), Color(0xFF66BB6A)], // Light green, Green
  ];

  List<Color> _getPillColors() {
    // Use medication ID hashCode to determine color (consistent per medication)
    final index = widget.medication.id.hashCode.abs() % pillColors.length;
    return pillColors[index];
  }

  Future<void> _showRefillDialog() async {
    final controller = TextEditingController(
      text: widget.medication.totalPills?.toString() ?? '30',
    );

    final newCount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refill Medication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How many pills are in the new bottle?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g., 30',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.inventory_2),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final count = int.tryParse(controller.text);
              Navigator.pop(context, count);
            },
            child: const Text('Refill'),
          ),
        ],
      ),
    );

    if (newCount != null && newCount > 0) {
      setState(() {
        widget.medication.refill(newCount);
      });
      await widget.medication.save();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Refilled with $newCount pills'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  //Unmark a dose as taken
  Future<void> _unmarkAsTaken() async {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    //Find all taken times for today
    final takenTimes = widget.medication.times
        .where((time) => widget.medication.wasTakenOn(normalizedToday, time))
        .toList();

    if (takenTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('No doses have been marked as taken today'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    //If multiple taken times, let user choose
    String? selectedTime = widget.specificTime;
    
    if (selectedTime == null || !widget.medication.wasTakenOn(normalizedToday, selectedTime)) {
      if (takenTimes.length > 1) {
        selectedTime = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Select Time to Unmark'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: takenTimes.map((time) {
                return ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(time),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, time),
                );
              }).toList(),
            ),
          ),
        );
        
        if (selectedTime == null) return;
      } else {
        selectedTime = takenTimes.first;
      }
    }

    //Confirm unmark
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unmark as Taken'),
        content: Text('Are you sure you want to unmark the $selectedTime dose?'),
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

  //Remove from taken log
  widget.medication.takenLog?.removeWhere((log) =>
    log['date'] == _formatDateIso(normalizedToday) &&
    log['scheduledTime'] == selectedTime);
    
    //Add pills back to remaining count
    if (widget.medication.pillsRemaining != null && widget.medication.totalPills != null) {
      widget.medication.pillsRemaining = 
          (widget.medication.pillsRemaining! + widget.medication.pillsPerDose)
          .clamp(0, widget.medication.totalPills!);
    }

    await widget.medication.save();

    if (mounted) {
      setState(() {});
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.undo, color: Colors.white),
              const SizedBox(width: 12),
              Text('${widget.medication.name} unmarked for $selectedTime'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _formatDateIso(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // FIXED: Mark specific time or show time selection dialog
  Future<void> _markAsTaken() async {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    //f a specific time was passed, use it. Otherwise, let user choose
    String? selectedTime = widget.specificTime;
    
    if (selectedTime == null) {
      // Find all untaken times for today
      final untakenTimes = widget.medication.times
          .where((time) => !widget.medication.wasTakenOn(normalizedToday, time))
          .toList();

      if (untakenTimes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('All doses for today have been taken!'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // If multiple untaken times, let user choose
      if (untakenTimes.length > 1) {
        selectedTime = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Select Time'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: untakenTimes.map((time) {
                return ListTile(
                  title: Text(time),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, time),
                );
              }).toList(),
            ),
          ),
        );
        
        if (selectedTime == null) return; // User cancelled
      } else {
        // Only one untaken time
        selectedTime = untakenTimes.first;
      }
    } else {
      // Check if this specific time was already taken
      if (widget.medication.wasTakenOn(normalizedToday, selectedTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 12),
                Text('$selectedTime dose already marked as taken'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final shouldLogSideEffects = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mark as Taken'),
        content: Text('Mark $selectedTime dose as taken?\n\nDid you experience any side effects?'),
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

    widget.medication.markAsTakenOn(normalizedToday, selectedTime);
    await widget.medication.save();

    if (shouldLogSideEffects && mounted) {
      await showDialog(
        context: context,
        builder: (context) => SideEffectsDialog(
          medication: widget.medication,
          takenDate: normalizedToday,
          takenTime: selectedTime!,
        ),
      );
    }

    if (mounted) {
      setState(() {}); // Update UI immediately
      Navigator.pop(context, true); // Signal home page to refresh
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('${widget.medication.name} marked as taken at $selectedTime'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _deleteMedication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication?'),
        content: Text('Are you sure you want to delete ${widget.medication.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.medication.delete();
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsRefill = widget.medication.needsRefill();
    final daysLeft = widget.medication.daysUntilOut();
    final hasRefillTracking = widget.medication.totalPills != null;
    final colors = _getPillColors(); // Get pill colors

    return Scaffold(
      appBar: AppBar(
        title: const Text(''), // Empty title
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF5B67CA),
                const Color(0xFF9B8CE8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditMedicationPage(medication: widget.medication),
                ),
              );
              if (result == true && mounted) {
                setState(() {});
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteMedication,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF5B67CA),
                    const Color(0xFF9B8CE8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pill icon with two-tone colors
                  Transform.rotate(
                    angle: -0.785398, // -45 degrees diagonal
                    child: Container(
                      width: 80,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19),
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: Row(
                        children: [
                          // Left half of pill
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: colors[0],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(19),
                                  bottomLeft: Radius.circular(19),
                                ),
                              ),
                            ),
                          ),
                          // Right half of pill
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: colors[1],
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(19),
                                  bottomRight: Radius.circular(19),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.medication.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.medication.dosage,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.medication.pillsPerDose} pill${widget.medication.pillsPerDose > 1 ? 's' : ''} per dose',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mark as Taken Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _markAsTaken,
                      icon: const Icon(Icons.check_circle_outline, size: 24),
                      label: const Text(
                        'Mark as Taken',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  //Unmark as Taken Button (only show if any dose was taken today)
                  if (_hasAnyTakenToday())
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _unmarkAsTaken,
                        icon: const Icon(Icons.undo, size: 24),
                        label: const Text(
                          'Unmark as Taken',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Refill Warning Banner
                  if (needsRefill)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Running Low!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.medication.pillsRemaining} pills left (~$daysLeft days)',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showRefillDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Refill'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Refill Tracking Card (if enabled)
                  if (hasRefillTracking)
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.inventory_2, color: Colors.orange),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Refill Tracking',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1D2E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              icon: Icons.medication,
                              label: 'Pills Remaining',
                              value: '${widget.medication.pillsRemaining}',
                              valueColor: needsRefill ? Colors.orange : Colors.green,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              icon: Icons.inventory,
                              label: 'Total in Bottle',
                              value: '${widget.medication.totalPills}',
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              icon: Icons.warning_amber_rounded,
                              label: 'Alert Threshold',
                              value: '${widget.medication.refillThreshold}',
                            ),
                            if (daysLeft != null) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                icon: Icons.calendar_today,
                                label: 'Days Until Out',
                                value: '~$daysLeft days',
                                valueColor: daysLeft < 7 ? Colors.red : null,
                              ),
                            ],
                            if (widget.medication.lastRefillDate != null) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                icon: Icons.history,
                                label: 'Last Refilled',
                                value: _formatDate(widget.medication.lastRefillDate!),
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showRefillDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Mark as Refilled'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                  side: const BorderSide(color: Colors.orange, width: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Schedule Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5B67CA).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.schedule, color: Color(0xFF5B67CA)),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Schedule',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1D2E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...widget.medication.times.map((time) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 20, color: Color(0xFF718096)),
                                const SizedBox(width: 12),
                                Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Notes Card
                  if (widget.medication.notes.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.notes, color: Colors.blue),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'Notes',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1D2E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.medication.notes,
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to check if any dose was taken today
  bool _hasAnyTakenToday() {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    
    return widget.medication.times.any(
      (time) => widget.medication.wasTakenOn(normalizedToday, time)
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF718096),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF1A1D2E),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    if (diff < 30) return '${(diff / 7).round()} weeks ago';
    
    return '${date.month}/${date.day}/${date.year}';
  }
}
