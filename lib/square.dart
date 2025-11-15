import 'package:flutter/material.dart';
import 'detailpage.dart';
import 'models/medication.dart';
import 'package:hive/hive.dart';
import 'homepage.dart';
import 'edit_medication_page.dart';
import 'services/notification_services.dart';

class MySquare extends StatelessWidget {
  final Medication medication;
  final String displayTime;

  const MySquare({
    super.key,
    required this.medication,
    required this.displayTime,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailPage(medication: medication),
          ),
        );
      },
      onLongPress: () {
        _showOptionsMenu(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF5B67CA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.medication,
                color: Color(0xFF5B67CA),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayTime,
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
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getStatusColor().withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                _getStatusText(),
                style: TextStyle(
                  color: _getStatusColor(),
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

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF5B67CA)),
              title: const Text('Edit Medication'),
              onTap: () {
                Navigator.pop(context);
                _editMedication(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Medication'),
              onTap: () {
                Navigator.pop(context);
                _deleteMedication(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.grey),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _editMedication(BuildContext context) async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EditMedicationPage(medication: medication),
    ),
  );
  
  if (result == true && context.mounted) {
    // Refresh homepage
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }
}

  void _deleteMedication(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Medication?'),
      content: Text('Are you sure you want to delete ${medication.name}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {

            await NotificationService().cancelMedicationNotifications(medication);
            // Delete from Hive
            final box = Hive.box<Medication>('medications');
            await box.delete(medication.key);
            
            if (context.mounted) {
              Navigator.pop(context); // Close dialog
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${medication.name} deleted'),
                  backgroundColor: Colors.red,
                ),
              );
              
              // Force rebuild by navigating back to a fresh HomePage
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) {
                  return const HomePage();
                }),
                (route) => false,
              );
            }
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

  Color _getStatusColor() {
    switch (medication.status.toLowerCase()) {
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

  String _getStatusText() {
    switch (medication.status.toLowerCase()) {
      case 'taken':
        return 'Taken ✓';
      case 'upcoming':
        return 'Upcoming';
      case 'grace_period':
        return '⏱️ Grace Period';
      case 'missed':
        return 'Missed';
      default:
        return 'Unknown';
    }
  }
}
