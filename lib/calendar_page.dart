import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'models/medication.dart';
import 'widgets/side_effects_dialog.dart';
import 'side_effectsHistoryPage.dart';
import 'services/notification_settings_page.dart';
import 'auth_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _medicationsByDay = {};
  String _userName = 'User';
  String _userEmail = 'user@example.com';
  String? _profileImagePath;
  bool _notificationsEnabled = true;

  // Pill color pairs 
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
    _selectedDay = _focusedDay;
    _loadMedicationsForMonth();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMedicationsForMonth();
  }

  void _loadMedicationsForMonth() {
    print('📄 Reloading calendar data...');
    final box = Hive.box<Medication>('medications');
    final medications = box.values.toList();
    
    _medicationsByDay.clear();
    
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    
    for (var date = firstDay; 
         date.isBefore(lastDay.add(const Duration(days: 1))); 
         date = date.add(const Duration(days: 1))) {
      
      final normalizedDate = DateTime(date.year, date.month, date.day);
      
      for (var medication in medications) {
        if (medication.isScheduledFor(normalizedDate)) {
          for (var time in medication.times) {
            if (_medicationsByDay[normalizedDate] == null) {
              _medicationsByDay[normalizedDate] = [];
            }
            
            final status = medication.getStatusForDateTime(normalizedDate, time);
            
            _medicationsByDay[normalizedDate]!.add({
              'medication': medication,
              'time': time,
              'status': status,
            });
          }
        }
      }
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> _getMedicationsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _medicationsByDay[normalizedDay] ?? [];
  }

  Color _getDayColor(DateTime day) {
    final items = _getMedicationsForDay(day);
    if (items.isEmpty) return Colors.transparent;
    
    final statuses = items.map((item) => item['status'] as String).toList();
    
    if (statuses.contains('missed')) return Colors.red;
    if (statuses.contains('upcoming') || statuses.contains('grace_period')) return Colors.orange;
    if (statuses.contains('taken')) return Colors.green;
    
    return Colors.transparent;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _formatSelectedDay(DateTime day) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    
    return '${days[day.weekday - 1]}, ${months[day.month - 1]} ${day.day}';
  }

  List<Color> _getPillColors(Medication medication) {
    //Use medication ID hashCode to determine color per medication
    final index = medication.id.hashCode.abs() % pillColors.length;
    return pillColors[index];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            //Header with month and profile
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: SvgPicture.asset(
                        'assets/images/pill_bottle_icon.svg',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getMonthName(_focusedDay.month),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _loadMedicationsForMonth,
                    color: const Color(0xFF5B67CA),
                  ),
                ],
              ),
            ),

            // Calendar widget
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2026, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                  _loadMedicationsForMonth();
                },
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: true,
                  weekendTextStyle: const TextStyle(color: Color(0xFF1A1D2E)),
                  todayDecoration: BoxDecoration(
                    color: const Color(0xFF5B67CA).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                    color: Color(0xFF5B67CA),
                    fontWeight: FontWeight.bold,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Color(0xFF5B67CA),
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  defaultTextStyle: const TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontWeight: FontWeight.w500,
                  ),
                  outsideTextStyle: TextStyle(
                    color: Colors.grey[400],
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronVisible: false,
                  rightChevronVisible: false,
                  titleTextStyle: const TextStyle(
                    fontSize: 0, // Hide the default title
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  weekendStyle: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    final color = _getDayColor(day);
                    if (color == Colors.transparent) return null;
                    
                    return Positioned(
                      bottom: 4,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            //Selected day details
            Expanded(
              child: _buildDayDetails(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetails() {
    if (_selectedDay == null) {
      return const Center(child: Text('Select a day'));
    }

    final items = _getMedicationsForDay(_selectedDay!);

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF5B67CA).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 64,
                color: const Color(0xFF5B67CA).withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No medications scheduled',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'for this day',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final medication = item['medication'] as Medication;
        final time = item['time'] as String;
        final status = item['status'] as String;
        
        return _buildMedicationCard(medication, time, status);
      },
    );
  }

  Widget _buildMedicationCard(Medication medication, String time, String status) {
    final statusColor = _getStatusColor(status);
    final sideEffectsCount = medication.sideEffects?.length ?? 0;
    final colors = _getPillColors(medication);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showSideEffectsHistory(medication),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            // Colorful Pill Icon (same as home page)
            Transform.rotate(
              angle: -0.785398, // -45 degrees in radians (top-left to bottom-right diagonal)
              child: Container(
                width: 48,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    // Left half of pill
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors[0],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(11),
                            bottomLeft: Radius.circular(11),
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
                            topRight: Radius.circular(11),
                            bottomRight: Radius.circular(11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Medication info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${medication.dosage} • $time',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF718096),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Time badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                time,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSideEffectsHistory(Medication medication) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SideEffectsHistoryPage(medication: medication),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'taken':
        return Colors.green;
      case 'upcoming':
        return const Color(0xFF5B67CA);
      case 'grace_period':
        return Colors.amber;
      case 'missed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}