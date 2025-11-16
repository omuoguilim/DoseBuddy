import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'models/medication.dart';
import 'package:share_plus/share_plus.dart';
import 'services/notification_settings_page.dart';
import 'auth_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _gracePeriodMinutes = 30;
  bool _notificationsEnabled = true;
  String _userName = 'User';
  String _userEmail = 'user@example.com';
  String? _profileImagePath;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'User';
      _userEmail = prefs.getString('user_email') ?? 'user@example.com';
      _profileImagePath = prefs.getString('profile_image');
    });
  }

  void _loadSettings() {
    setState(() {
      _gracePeriodMinutes = 30;
      _notificationsEnabled = true;
    });
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _userName);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Enter your name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', newName);
      setState(() {
        _userName = newName;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _changeProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Choose Photo Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF5B67CA)),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF5B67CA)),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image', image.path);
        setState(() {
          _profileImagePath = image.path;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Map<String, dynamic> _calculateStats() {
    final box = Hive.box<Medication>('medications');
    final medications = box.values.toList();
    
    int totalMedications = medications.length;
    int totalDosesToday = 0;
    int takenDosesToday = 0;
    int totalDosesThisWeek = 0;
    int takenDosesThisWeek = 0;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    for (var med in medications) {
      if (med.isScheduledFor(today)) {
        totalDosesToday += med.times.length;
        for (var time in med.times) {
          if (med.wasTakenOn(today, time)) {
            takenDosesToday++;
          }
        }
      }
      
      for (int i = 0; i < 7; i++) {
        final date = today.subtract(Duration(days: i));
        if (med.isScheduledFor(date)) {
          totalDosesThisWeek += med.times.length;
          for (var time in med.times) {
            if (med.wasTakenOn(date, time)) {
              takenDosesThisWeek++;
            }
          }
        }
      }
    }
    
    double adherenceRate = totalDosesThisWeek > 0 
        ? (takenDosesThisWeek / totalDosesThisWeek * 100) 
        : 0.0;
    
    int streak = _calculateStreak(medications);
    
    return {
      'totalMedications': totalMedications,
      'totalDosesToday': totalDosesToday,
      'takenDosesToday': takenDosesToday,
      'totalDosesThisWeek': totalDosesThisWeek,
      'takenDosesThisWeek': takenDosesThisWeek,
      'adherenceRate': adherenceRate,
      'streak': streak,
    };
  }

  int _calculateStreak(List<Medication> medications) {
    if (medications.isEmpty) return 0;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int streak = 0;
    
    for (int i = 0; i < 365; i++) {
      final date = today.subtract(Duration(days: i));
      bool allTaken = true;
      int dosesForDay = 0;
      
      for (var med in medications) {
        if (med.isScheduledFor(date)) {
          for (var time in med.times) {
            dosesForDay++;
            if (!med.wasTakenOn(date, time)) {
              allTaken = false;
              break;
            }
          }
          if (!allTaken) break;
        }
      }
      
      if (dosesForDay > 0 && allTaken) {
        streak++;
      } else if (dosesForDay > 0) {
        break;
      }
    }
    
    return streak;
  }

  Future<void> _exportData() async {
    final box = Hive.box<Medication>('medications');
    final medications = box.values.toList();
    
    String csvData = 'Medication,Dosage,Times,Notes,Created\n';
    
    for (var med in medications) {
      csvData += '${med.name},${med.dosage},"${med.times.join('; ')}",${med.notes},${med.createdAt}\n';
    }
    
    await Share.share(csvData, subject: 'DoseBuddy Medication Export');
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your medications and history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final box = Hive.box<Medication>('medications');
      await box.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {});
      }
    }
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
    final stats = _calculateStats();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            //Profile Header
            Container(
              width: double.infinity,
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
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(51),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _profileImagePath != null
                            ? ClipOval(
                                child: Image.file(
                                  File(_profileImagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Color(0xFF5B67CA),
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 50,
                                color: Color(0xFF5B67CA),
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _changeProfilePicture,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5B67CA),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                        onPressed: _editName,
                      ),
                    ],
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

            const SizedBox(height: 16),

            //Statistics Cards
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Statistics',
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
                          icon: Icons.medication,
                          label: 'Medications',
                          value: '${stats['totalMedications']}',
                          color: const Color(0xFF5B67CA),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.local_fire_department,
                          label: 'Day Streak',
                          value: '${stats['streak']}',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.check_circle,
                          label: 'Today',
                          value: '${stats['takenDosesToday']}/${stats['totalDosesToday']}',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.analytics,
                          label: 'Adherence',
                          value: '${stats['adherenceRate'].toStringAsFixed(0)}%',
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.notifications_active, color: Color(0xFF5B67CA)),
                          title: const Text('Notification Settings'),
                          subtitle: const Text('Test and configure reminders'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationSettingsPage(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Enable Notifications'),
                          subtitle: const Text('Turn medication reminders on/off'),
                          value: _notificationsEnabled,
                          activeThumbColor: const Color(0xFF5B67CA),
                          onChanged: (value) {
                            setState(() {
                              _notificationsEnabled = value;
                            });
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Grace Period'),
                          subtitle: Text('$_gracePeriodMinutes minutes after scheduled time'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showGracePeriodDialog(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Data Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.upload, color: Color(0xFF5B67CA)),
                          title: const Text('Export Data'),
                          subtitle: const Text('Download your medication history'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _exportData,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.delete_forever, color: Colors.red),
                          title: const Text('Clear All Data'),
                          subtitle: const Text('Permanently delete all medications'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _clearAllData,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'About',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.info_outline, color: Color(0xFF5B67CA)),
                          title: const Text('App Version'),
                          subtitle: const Text('1.0.0'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF5B67CA)),
                          title: const Text('Privacy Policy'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.help_outline, color: Color(0xFF5B67CA)),
                          title: const Text('Help & Support'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text(
                            'Log Out',
                            style: TextStyle(color: Colors.red),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.red),
                          onTap: _logout,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
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
        padding: const EdgeInsets.all(16.0),
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

  void _showGracePeriodDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Grace Period'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How many minutes after the scheduled time should a dose still count as on-time?'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _gracePeriodMinutes,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: [15, 30, 45, 60, 90, 120]
                  .map((minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text('$minutes minutes'),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _gracePeriodMinutes = value;
                  });
                }
              },
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Grace period set to $_gracePeriodMinutes minutes'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

