import 'package:flutter/material.dart';
import 'notification_services.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  int _pendingNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final count = await NotificationService().getPendingNotificationsCount();
    setState(() {
      _pendingNotifications = count;
    });
  }

  Future<void> _sendTestNotification() async {
    await NotificationService().showImmediateNotification(
      title: '🧪 Test Notification',
      body: 'This is a test! If you see this, notifications are working.',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _scheduleTestNotification() async {
    await NotificationService().showTestNotification();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification scheduled for 5 seconds from now'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _cancelAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel All Notifications?'),
        content: const Text('This will remove all pending medication reminders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NotificationService().cancelAllNotifications();
      await _loadPendingCount();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cancelled'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //info Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF5B67CA).withValues(alpha: 0.1),
                    const Color(0xFF9B8CE8).withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF5B67CA).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF5B67CA),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'iOS Notifications',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1A1D2E),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'iOS will ask for permission automatically. Change settings in: iPhone Settings > DoseBuddy > Notifications',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF718096),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            //Pending Notifications
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF5B67CA).withValues(alpha: 0.2),
                        const Color(0xFF9B8CE8).withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.schedule,
                    color: Color(0xFF5B67CA),
                  ),
                ),
                title: const Text(
                  'Pending Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '$_pendingNotifications scheduled reminders',
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadPendingCount,
                  color: const Color(0xFF5B67CA),
                ),
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'Test Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 12),

            // Test Buttons
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B67CA).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        color: Color(0xFF5B67CA),
                      ),
                    ),
                    title: const Text(
                      'Send Test Notification',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Appears immediately',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _sendTestNotification,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Colors.grey[200],
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: Colors.orange,
                      ),
                    ),
                    title: const Text(
                      'Schedule Test (5 seconds)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Tests scheduled notifications',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _scheduleTestNotification,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'Danger Zone',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 0,
              color: Colors.red.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.red.withValues(alpha: 0.2),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red,
                  ),
                ),
                title: const Text(
                  'Cancel All Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                subtitle: const Text(
                  'Remove all pending reminders',
                  style: TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.red),
                onTap: _cancelAllNotifications,
              ),
            ),

            const SizedBox(height: 32),

            //Info Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'How to test',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Tap "Send Test Notification" for instant test\n'
                    '2. Tap "Schedule Test" and wait 5 seconds\n'
                    '3. If prompted by iOS, tap "Allow" for notifications\n'
                    '4. Check Settings > DoseBuddy > Notifications if needed',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF718096),
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
}