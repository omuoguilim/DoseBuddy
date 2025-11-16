import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'square.dart';
import 'add_medication_page.dart';
import 'models/medication.dart';
import 'insights_page.dart';
import 'services/notification_settings_page.dart';
import 'auth_page.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Medication> medications = [];
  Timer? _statusCheckTimer;
  String _userName = 'User';
  String _userEmail = 'user@example.com';
  String? _profileImagePath;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadUserData();
    _loadMedications();

    _statusCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer){
      _updateMedicationStatuses();
    });
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'User';
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'User';
      _userEmail = prefs.getString('user_email') ?? 'user@example.com';
      _profileImagePath = prefs.getString('profile_image');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserName();
    _loadUserData();
    _loadMedications();
  }

  void _loadMedications() {
    final box = Hive.box<Medication>('medications');
    setState(() {
      medications = box.values.toList();
    });
  }

  void _updateMedicationStatuses() {
    if (!mounted) return;
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

  void refreshMedications() {
    _loadMedications();
  }

  List<Medication> _getMedicationsNeedingRefill() {
    return medications.where((med) => med.needsRefill()).toList();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Map<String, dynamic> _calculateStats() {
    final box = Hive.box<Medication>('medications');
    final medications = box.values.toList();
    
    int totalMedications = medications.length;
    
    return {
      'totalMedications': totalMedications,
    };
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF5B67CA)),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final refillNeeded = _getMedicationsNeedingRefill();
    final takenCount = medications.where((m) => m.status == 'taken').length;
    final upcomingCount = medications.where((m) => m.status == 'upcoming').length;
    final missedCount = medications.where((m) => m.status == 'missed').length;
    final stats = _calculateStats();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      endDrawer: Drawer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF5B67CA).withAlpha(26),
                Colors.white,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Drawer Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF5B67CA),
                        const Color(0xFF9B8CE8),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: _profileImagePath != null
                            ? ClipOval(
                                child: Image.file(
                                  File(_profileImagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Color(0xFF5B67CA),
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 40,
                                color: Color(0xFF5B67CA),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userEmail,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildDrawerItem(
                        icon: Icons.person,
                        title: 'My Account',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.edit,
                        title: 'Edit Profile',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(height: 32),
                      _buildDrawerItem(
                        icon: Icons.medical_information,
                        title: 'My Medications',
                        subtitle: '${stats['totalMedications']} active',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.history,
                        title: 'Medication History',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(height: 32),
                      _buildDrawerItem(
                        icon: Icons.notifications,
                        title: 'Notifications',
                        trailing: Switch(
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() {
                              _notificationsEnabled = value;
                            });
                          },
                          activeThumbColor: const Color(0xFF5B67CA),
                        ),
                      ),
                      _buildDrawerItem(
                        icon: Icons.notifications_active,
                        title: 'Notification Settings',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationSettingsPage(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.security,
                        title: 'Privacy Policy',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.info_outline,
                        title: 'About',
                        subtitle: 'Version 1.0.0',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(height: 32),
                      _buildDrawerItem(
                        icon: Icons.logout,
                        title: 'Log Out',
                        iconColor: Colors.red,
                        textColor: Colors.red,
                        onTap: () {
                          Navigator.pop(context);
                          _logout();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF5B67CA),
                    const Color(0xFF9B8CE8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF5B67CA).withAlpha(77),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userName,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Insights button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.analytics_rounded, color: Colors.white),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const InsightsPage(),
                                  ),
                                );
                              },
                              tooltip: 'View Insights',
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Menu button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Builder(
                              builder: (context) => IconButton(
                                icon: const Icon(Icons.menu, color: Colors.white),
                                onPressed: () {
                                  Scaffold.of(context).openEndDrawer();
                                },
                                tooltip: 'Menu',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Stats Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniStatCard(
                          icon: Icons.check_circle_rounded,
                          label: 'Taken',
                          count: takenCount,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMiniStatCard(
                          icon: Icons.access_time_rounded,
                          label: 'Upcoming',
                          count: upcomingCount,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMiniStatCard(
                          icon: Icons.cancel_rounded,
                          label: 'Missed',
                          count: missedCount,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: medications.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        children: [
                          // Refill Warning Banner
                          if (refillNeeded.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.shade50,
                                    Colors.orange.shade100,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.orange.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.inventory_2_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Refill Needed',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...refillNeeded.map((med) {
                                    final daysLeft = med.daysUntilOut() ?? 0;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.circle, size: 6, color: Colors.orange),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${med.name}: ${med.pillsRemaining} pills left (~$daysLeft days)',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),

                          // Today's Medications Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Today\'s Medications',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1D2E),
                                  ),
                                ),
                                Text(
                                  '${medications.length} total',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF718096),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Medication List
                          if (_getMorningMedTimes().isNotEmpty) ...[
                            _buildSectionHeader('Morning', Icons.wb_sunny_rounded, Colors.orange),
                            ..._getMorningMedTimes().map((item) => MySquare(
                              medication: item['medication'] as Medication,
                              displayTime: item['time'] as String,
                              onStatusChanged: refreshMedications,
                            )),
                          ],
                          
                          if (_getAfternoonMedTimes().isNotEmpty) ...[
                            _buildSectionHeader('Afternoon', Icons.wb_cloudy_rounded, Colors.blue),
                            ..._getAfternoonMedTimes().map((item) => MySquare(
                              medication: item['medication'] as Medication,
                              displayTime: item['time'] as String,
                              onStatusChanged: refreshMedications,
                            )),
                          ],
                          
                          if (_getEveningMedTimes().isNotEmpty) ...[
                            _buildSectionHeader('Evening', Icons.nights_stay_rounded, const Color(0xFF5B67CA)),
                            ..._getEveningMedTimes().map((item) => MySquare(
                              medication: item['medication'] as Medication,
                              displayTime: item['time'] as String,
                              onStatusChanged: refreshMedications,
                            )),
                          ],

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF5B67CA),
              const Color(0xFF9B8CE8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF5B67CA).withAlpha(102),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, size: 28),
          label: const Text(
            'Add Med',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? const Color(0xFF5B67CA)).withAlpha(26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor ?? const Color(0xFF5B67CA),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor ?? const Color(0xFF1A1D2E),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF718096),
              ),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Color(0xFF718096)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildMiniStatCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha(51),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF5B67CA).withAlpha(26),
                    Color(0xFF9B8CE8).withAlpha(26),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medication_rounded,
                size: 80,
                color: Color(0xFF5B67CA).withAlpha(128),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Medications Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start tracking your medications\nby adding your first one',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getMorningMedTimes() {
    List<Map<String, dynamic>> result = [];
    for (var med in medications) {
      for (var time in med.times) {
        if (_isMorningTime(time)) {
          result.add({'medication': med, 'time': time});
        }
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _getAfternoonMedTimes() {
    List<Map<String, dynamic>> result = [];
    for (var med in medications) {
      for (var time in med.times) {
        if (_isAfternoonTime(time)) {
          result.add({'medication': med, 'time': time});
        }
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _getEveningMedTimes() {
    List<Map<String, dynamic>> result = [];
    for (var med in medications) {
      for (var time in med.times) {
        if (_isEveningTime(time)) {
          result.add({'medication': med, 'time': time});
        }
      }
    }
    return result;
  }

  bool _isMorningTime(String time) {
    final timeLower = time.toLowerCase();
    if (!timeLower.contains('am')) return false;
    if (timeLower.contains('12:')) return false;
    return true;
  }

  bool _isAfternoonTime(String time) {
    final timeLower = time.toLowerCase();
    
    if (timeLower.contains('12:') && timeLower.contains('pm')) {
      return true;
    }
    
    if (timeLower.contains('pm')) {
      try {
        final hour = int.parse(timeLower.split(':')[0].trim());
        return hour >= 1 && hour < 6;
      } catch (e) {
        return false;
      }
    }
    
    return false;
  }

  bool _isEveningTime(String time) {
    final timeLower = time.toLowerCase();
    
    if (!timeLower.contains('pm')) return false;
    if (timeLower.contains('12:')) return false;
    
    try {
      final hour = int.parse(timeLower.split(':')[0].trim());
      return hour >= 6;
    } catch (e) {
      return false;
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
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