import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive/hive.dart';
import 'models/medication.dart';
import 'widgets/side_effects_dialog.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Medication>> _medicationsByDay = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMedicationsForMonth();
  }

  void _loadMedicationsForMonth() {
    final box = Hive.box<Medication>('medications');
    final medications = box.values.toList();
    
    // Group medications by day based on their scheduled times
    _medicationsByDay.clear();
    
    for (var medication in medications) {
      for (var time in medication.times) {
        // For now, we'll show medications on today
        // In a real app, you'd parse the scheduled dates
        final day = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
        
        if (_medicationsByDay[day] == null) {
          _medicationsByDay[day] = [];
        }
        if (!_medicationsByDay[day]!.contains(medication)) {
          _medicationsByDay[day]!.add(medication);
        }
      }
    }
    
    setState(() {});
  }

  List<Medication> _getMedicationsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _medicationsByDay[normalizedDay] ?? [];
  }

  Color _getDayColor(DateTime day) {
    final meds = _getMedicationsForDay(day);
    if (meds.isEmpty) return Colors.transparent;
    
    final takenCount = meds.where((m) => m.status == 'taken').length;
    final missedCount = meds.where((m) => m.status == 'missed').length;
    final upcomingCount = meds.where((m) => m.status == 'upcoming' || m.status == 'grace_period').length;
    
    // Priority: missed > upcoming > taken
    if (missedCount > 0) return Colors.red;
    if (upcomingCount > 0) return Colors.orange;
    if (takenCount > 0) return Colors.green;
    
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calendar',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
      ),
      body: Column(
        children: [
          // Calendar widget
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2025, 12, 31),
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
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF5B67CA).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Color(0xFF5B67CA),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  final color = _getDayColor(day);
                  if (color == Colors.transparent) return null;
                  
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 6,
                      height: 6,
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

          const SizedBox(height: 16),

          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(Colors.green, 'Taken'),
                _buildLegendItem(Colors.orange, 'Upcoming'),
                _buildLegendItem(Colors.red, 'Missed'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Selected day details
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: _buildDayDetails(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF718096),
          ),
        ),
      ],
    );
  }

  Widget _buildDayDetails() {
    if (_selectedDay == null) {
      return const Center(child: Text('Select a day'));
    }

    final meds = _getMedicationsForDay(_selectedDay!);

    if (meds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No medications scheduled',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Medications for ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1D2E),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: meds.length,
            itemBuilder: (context, index) {
              final med = meds[index];
              return _buildMedicationCard(med);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationCard(Medication medication) {
    final statusColor = _getStatusColor(medication.status);
    final sideEffectsCount = medication.sideEffects?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showSideEffectsHistory(medication),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                          medication.dosage,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _getStatusText(medication.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (sideEffectsCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '$sideEffectsCount side effect log${sideEffectsCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Tap to view',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
        return Colors.orange;
      case 'grace_period':
        return Colors.amber;
      case 'missed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'taken':
        return 'Taken ✓';
      case 'upcoming':
        return 'Upcoming';
      case 'grace_period':
        return '⏱️ Grace';
      case 'missed':
        return 'Missed';
      default:
        return 'Unknown';
    }
  }
}