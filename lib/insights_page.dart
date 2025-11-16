import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'models/medication.dart';
import 'package:fl_chart/fl_chart.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  String _selectedPeriod = 'week'; // week, month

  @override
  Widget build(BuildContext context) {
    final stats = _calculateDetailedStats();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Insights',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            //Period Selector
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildPeriodButton('Week', 'week'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPeriodButton('Month', 'month'),
                  ),
                ],
              ),
            ),

            //Overall Adherence Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF5B67CA),
                        const Color(0xFF9B8CE8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Overall Adherence',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${stats['adherenceRate'].toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${stats['takenDoses']} of ${stats['totalDoses']} doses taken',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            //Weekly Chart
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Adherence',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1D2E),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 250,
                        child: _buildAdherenceChart(stats['dailyData']),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            //Stats Grid
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statistics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.check_circle,
                          label: 'Taken',
                          value: '${stats['takenDoses']}',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.cancel,
                          label: 'Missed',
                          value: '${stats['missedDoses']}',
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.local_fire_department,
                          label: 'Best Day',
                          value: stats['bestDay'],
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.trending_up,
                          label: 'Avg/Day',
                          value: '${stats['avgPerDay'].toStringAsFixed(1)}',
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            //Medication Breakdown
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'By Medication',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1D2E),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._buildMedicationBreakdown(stats['byMedication']),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedPeriod = value;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF5B67CA) : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.grey[700],
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdherenceChart(List<Map<String, dynamic>> dailyData) {
    if (dailyData.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    final isMonth = _selectedPeriod == 'month';

    return BarChart(
      BarChartData(
        maxY: 100,
        minY: 0,
        barGroups: dailyData.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final percentage = data['percentage'] as double;
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: percentage,
                color: percentage >= 80
                    ? Colors.green
                    : percentage >= 50
                        ? Colors.orange
                        : Colors.red,
                width: isMonth ? 8 : 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 25,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${value.toInt()}%',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= dailyData.length) {
                  return const SizedBox.shrink();
                }
                
                // For month view, show every 3rd label to avoid overlap
                if (isMonth && index % 3 != 0) {
                  return const SizedBox.shrink();
                }
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    dailyData[index]['day'],
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final data = dailyData[groupIndex];
              return BarTooltipItem(
                '${data['day']}\n${data['percentage'].toStringAsFixed(0)}%\n${data['taken']}/${data['total']} doses',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMedicationBreakdown(Map<String, Map<String, int>> byMedication) {
    if (byMedication.isEmpty) {
      return [const Text('No medications tracked')];
    }

    return byMedication.entries.map((entry) {
      final medName = entry.key;
      final taken = entry.value['taken'] ?? 0;
      final total = entry.value['total'] ?? 1;
      final percentage = (taken / total * 100).toStringAsFixed(0);

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  medName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$percentage% ($taken/$total)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF718096),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: taken / total,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                taken / total >= 0.8 ? Colors.green : Colors.orange,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }).toList();
  }

  Map<String, dynamic> _calculateDetailedStats() {
    final box = Hive.box<Medication>('medications');
    final medications = box.values.toList();
    
    final now = DateTime.now();
    final daysToCheck = _selectedPeriod == 'week' ? 7 : 30;
    
    int totalDoses = 0;
    int takenDoses = 0;
    int missedDoses = 0;
    
    Map<String, int> dailyTaken = {};
    Map<String, int> dailyTotal = {};
    Map<String, Map<String, int>> byMedication = {};
    
    for (int i = 0; i < daysToCheck; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayKey = _getDayLabel(date, i, daysToCheck);
      
      dailyTaken[dayKey] = 0;
      dailyTotal[dayKey] = 0;
      
      for (var med in medications) {
        if (med.isScheduledFor(date)) {
          byMedication.putIfAbsent(med.name, () => {'taken': 0, 'total': 0});
          
          for (var time in med.times) {
            totalDoses++;
            dailyTotal[dayKey] = (dailyTotal[dayKey] ?? 0) + 1;
            byMedication[med.name]!['total'] = (byMedication[med.name]!['total'] ?? 0) + 1;
            
            if (med.wasTakenOn(date, time)) {
              takenDoses++;
              dailyTaken[dayKey] = (dailyTaken[dayKey] ?? 0) + 1;
              byMedication[med.name]!['taken'] = (byMedication[med.name]!['taken'] ?? 0) + 1;
            } else if (date.isBefore(DateTime(now.year, now.month, now.day))) {
              missedDoses++;
            }
          }
        }
      }
    }
    
    // Build daily data for chart
    List<Map<String, dynamic>> dailyData = [];
    for (int i = daysToCheck - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayKey = _getDayLabel(date, i, daysToCheck);
      final taken = dailyTaken[dayKey] ?? 0;
      final total = dailyTotal[dayKey] ?? 1;
      final percentage = total > 0 ? (taken / total * 100) : 0.0;
      
      dailyData.add({
        'day': dayKey,
        'taken': taken,
        'total': total,
        'percentage': percentage,
      });
    }
    
    // Find best day
    String bestDay = 'None';
    double bestPercentage = 0;
    for (var data in dailyData) {
      if (data['percentage'] > bestPercentage && data['total'] > 0) {
        bestPercentage = data['percentage'];
        bestDay = data['day'];
      }
    }
    
    double adherenceRate = totalDoses > 0 ? (takenDoses / totalDoses * 100) : 0.0;
    double avgPerDay = daysToCheck > 0 ? (takenDoses / daysToCheck) : 0.0;
    
    return {
      'totalDoses': totalDoses,
      'takenDoses': takenDoses,
      'missedDoses': missedDoses,
      'adherenceRate': adherenceRate,
      'avgPerDay': avgPerDay,
      'bestDay': bestDay,
      'dailyData': dailyData,
      'byMedication': byMedication,
    };
  }

  String _getDayLabel(DateTime date, int daysAgo, int totalDays) {
    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1 && totalDays == 7) return 'Yest';
    
    // For week view, use 3-letter abbreviations
    if (totalDays == 7) {
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return days[date.weekday % 7];
    }
    
    // For month view, use date numbers
    return '${date.day}';
  }
}