import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'square.dart';
import 'add_medication_page.dart';
import 'models/medication.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Medication> medications = [];
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadMedications();

    _statusCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer){
    _updateMedicationStatuses();
  });


    _statusCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer){
      _updateMedicationStatuses();
    });
  }

  @override
void didChangeDependencies() {
  super.didChangeDependencies();
  _loadMedications(); // Reload whenever we come back to this screen
}

  void _loadMedications() {
    final box = Hive.box<Medication>('medications');
    print('📦 Box has ${box.length} medications');  // ADD THIS LINE
    for (var med in box.values) {
    print('Med: ${med.name} - ${med.times}');  // ADD THIS LINE
  }
    setState(() {
      medications = box.values.toList();
    });
  }

  void _updateMedicationStatuses() {
  final box = Hive.box<Medication>('medications');
  bool needsUpdate = false;
  
  for (var medication in medications) {
    for (var time in medication.times) {
      final newStatus = medication.getStatusForTime(time);
      if (medication.status != newStatus) {
        medication.status = newStatus;
        medication.save();
        needsUpdate = true;
      }
    }
  }
  
  if (needsUpdate) {
    setState(() {
      _loadMedications();
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DoseBuddy',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
      ),
      body: Column(
        children: [
          // Greeting header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Good Evening! 👋',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have ${medications.length} medications today',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Summary stats card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          icon: Icons.check_circle,
                          color: Colors.green,
                          label: 'Taken',
                          count: medications.where((m) => m.status == 'taken').length,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey[300],
                        ),
                        _buildStatItem(
                          icon: Icons.access_time,
                          color: Colors.orange,
                          label: 'Upcoming',
                          count: medications.where((m) => m.status == 'upcoming').length,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey[300],
                        ),
                        _buildStatItem(
                          icon: Icons.cancel,
                          color: Colors.red,
                          label: 'Missed',
                          count: medications.where((m) => m.status == 'missed').length,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Medication list
          Expanded(
            child: medications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.medication_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No medications yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first medication',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(top: 0),
                    children: [
                      // Morning section
                      if (_getMorningMeds().isNotEmpty) ...[
                        _buildSectionHeader('Morning', Icons.wb_sunny_rounded, Colors.orange),
                        ..._getMorningMeds().map((med) => MySquare(
      medication: med,
      displayTime: med.times.isNotEmpty ? med.times.first : 'No time set',
    )),
                      ],
                      
                      // Afternoon section
                      if (_getAfternoonMeds().isNotEmpty) ...[
                        _buildSectionHeader('Afternoon', Icons.wb_cloudy_rounded, Colors.blue),
                        ..._getAfternoonMeds().map((med) => MySquare(
      medication: med,
      displayTime: med.times.isNotEmpty ? med.times.first : 'No time set',
    )),
                      ],
                      
                      // Evening section
                      if (_getEveningMeds().isNotEmpty) ...[
                        _buildSectionHeader('Evening', Icons.nights_stay_rounded, Colors.indigo),
                        ..._getEveningMeds().map((med) => MySquare(
      medication: med,
      displayTime: med.times.isNotEmpty ? med.times.first : 'No time set',
    )),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddMedicationPage(),
            ),
          );
          
          if (result == true) {
            _loadMedications();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
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

  List<Medication> _getMorningMeds() {
    return medications.where((med) {
      if (med.times.isEmpty) return false;
      final time = med.times.first.toLowerCase();
      return time.contains('am') && !time.contains('12:');
    }).toList();
  }

  List<Medication> _getAfternoonMeds() {
    return medications.where((med) {
      if (med.times.isEmpty) return false;
      final time = med.times.first.toLowerCase();
      return time.contains('12:') || (time.contains('pm') && 
             int.parse(time.split(':')[0]) < 6);
    }).toList();
  }

  List<Medication> _getEveningMeds() {
    return medications.where((med) {
      if (med.times.isEmpty) return false;
      final time = med.times.first.toLowerCase();
      return time.contains('pm') && int.parse(time.split(':')[0]) >= 6;
    }).toList();
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(38),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }
}