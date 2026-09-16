import 'package:flutter/material.dart';
import 'models/medication.dart';
import 'package:intl/intl.dart';

class SideEffectsHistoryPage extends StatefulWidget {
  final Medication medication;

  const SideEffectsHistoryPage({super.key, required this.medication});

  @override
  State<SideEffectsHistoryPage> createState() => _SideEffectsHistoryPageState();
}

class _SideEffectsHistoryPageState extends State<SideEffectsHistoryPage> {
  // Pill color pairs (light, dark) - same as in square.dart and calendar_page.dart
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

  @override
  Widget build(BuildContext context) {
    final sideEffects = widget.medication.sideEffects ?? [];
    final colors = _getPillColors();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Side Effects History'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header section
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Colorful Pill Icon (same as home page and calendar)
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.785398, // -45 degrees in radians
                          child: Container(
                            width: 36,
                            height: 16,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                // Left half of pill
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: colors[0],
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        bottomLeft: Radius.circular(8),
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
                                        topRight: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.medication.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.medication.dosage,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${sideEffects.length} log${sideEffects.length != 1 ? 's' : ''} recorded',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Side effects list
          Expanded(
            child: sideEffects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sentiment_satisfied_alt,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No side effects logged yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Side effects will appear here when you log them',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sideEffects.length,
                    itemBuilder: (context, index) {
                      // Show most recent first
                      final log = sideEffects[sideEffects.length - 1 - index];
                      return _buildSideEffectCard(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideEffectCard(Map<String, dynamic> log) {
    final timestamp = DateTime.parse(log['timestamp'] as String);
    final effects = (log['effects'] as List).cast<String>();
    final notes = log['notes'] as String? ?? '';
    final hasNone = effects.contains('None');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and time
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy • h:mm a').format(timestamp),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Side effects
            if (hasNone)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'No side effects',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              const Text(
                'Side Effects:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1D2E),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: effects.map((effect) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      effect,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            
            // Notes
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Notes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notes,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}