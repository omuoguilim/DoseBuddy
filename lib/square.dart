import 'package:flutter/material.dart';
import 'models/medication.dart';
import 'detailpage.dart';
import 'widgets/side_effects_dialog.dart';

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
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  // Pill color pairs (light, dark)
  static const List<List<Color>> pillColors = [
    [Color(0xFFB3E5FC), Color(0xFF4FC3F7)], // Light blue, Blue
    [Color(0xFFFFCC80), Color(0xFFFF9800)], // Light orange, Orange
    [Color(0xFFEF9A9A), Color(0xFFE53935)], // Light red, Red
    [Color(0xFFE1BEE7), Color(0xFFAB47BC)], // Light purple, Purple
    [Color(0xFFA5D6A7), Color(0xFF66BB6A)], // Light green, Green
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
        return Colors.green;
      case 'grace_period':
        return Colors.amber;
      case 'missed':
        return Colors.red;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('${widget.medication.name} marked as taken'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

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

    // Remove from taken log
    widget.medication.takenLog?.removeWhere((log) =>
        log['date'] == _formatDateString(normalizedToday) &&
        log['scheduledTime'] == widget.displayTime);
    
    // Add pills back to remaining count
    if (widget.medication.pillsRemaining != null && widget.medication.totalPills != null) {
      widget.medication.pillsRemaining = 
          (widget.medication.pillsRemaining! + widget.medication.pillsPerDose)
          .clamp(0, widget.medication.totalPills!);
    }

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

  @override
  Widget build(BuildContext context) {
    final status = _currentStatus;
    final isTaken = status == 'taken';
    final isMissed = status == 'missed';
    final isGrace = status == 'grace_period';
    final colors = _getPillColors();

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        Future.delayed(const Duration(milliseconds: 150), () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailPage(
                medication: widget.medication,
                specificTime: widget.displayTime, 
              ),
            ),
          );
          
          if (result == true) {
            widget.onStatusChanged?.call();
            setState(() {});
          }
        });
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isTaken 
                  ? Colors.green.withValues(alpha: 0.2) 
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Colorful Pill Icon
              Transform.rotate(
                angle: -0.785398, // -45 degrees in radians (top-left to bottom-right diagonal)
                child: Container(
                  width: 60,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // Left half of pill
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors[0],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
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
                              topRight: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              //Medication Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.medication.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1D2E),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          widget.medication.dosage,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF718096),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.displayTime,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF718096),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _statusIcon,
                          size: 14,
                          color: _statusColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              //Action Button
              if (!isTaken)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isMissed
                          ? [Colors.red.shade400, Colors.red.shade300]
                          : isGrace
                              ? [Colors.amber.shade400, Colors.amber.shade300]
                              : [const Color(0xFF5B67CA), const Color(0xFF9B8CE8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _statusColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _markAsTaken,
                      borderRadius: BorderRadius.circular(14),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                )
              else
                //Taken button with long-press to unmark
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onLongPress: _unmarkAsTaken,
                      borderRadius: BorderRadius.circular(14),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
