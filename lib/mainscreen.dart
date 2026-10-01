import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'today_page.dart';
import 'medication_library_page.dart';
import 'profile_page.dart';
import 'insights_page.dart';
import 'care_circle_page.dart';
import 'services/notification_services.dart';
import 'dose_review_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); NotificationService().onReviewRequested = () async { if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => const DoseReviewPage())); }; _refreshReminders(); }
  Future<void> _refreshReminders() async { try { await NotificationService().rescheduleAll(); } catch (_) { /* Permission status remains visible in reminder health. */ } }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _refreshReminders(); }
  @override
  void dispose() { NotificationService().onReviewRequested = null; WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  int _currentIndex = 0;

  final List<Widget> _pages = [
    const TodayPage(),
    const MedicationLibraryPage(),
    const InsightsPage(),
    const CareCirclePage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (_currentIndex == 0 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _currentIndex == 0 ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        extendBodyBehindAppBar: true,
        body: _pages[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              selectedItemColor: const Color(0xFF5B67CA),
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Today',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.medication_outlined),
                  label: 'Medications',
                ),
                BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Insights'),
                BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Care Circle'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
