import 'package:flutter/material.dart';
import 'today_page.dart';
import 'medications_page.dart';
import 'insights_page.dart';
import 'profile_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Widget _page(int i) { switch(i){ case 0:return const TodayPage(); case 1:return const MedicationsPage(); case 2:return const InsightsPage(); default:return const ProfilePage(); } }

  @override Widget build(BuildContext context) => Scaffold(
    body: KeyedSubtree(key: ValueKey(_currentIndex), child: _page(_currentIndex)),
    bottomNavigationBar: NavigationBar(
      height:72,
      selectedIndex:_currentIndex,
      onDestinationSelected:(i)=>setState(()=>_currentIndex=i),
      indicatorColor:const Color(0xFFE6E8FF),
      destinations:const [
        NavigationDestination(icon:Icon(Icons.today_outlined),selectedIcon:Icon(Icons.today_rounded),label:'Today'),
        NavigationDestination(icon:Icon(Icons.medication_outlined),selectedIcon:Icon(Icons.medication_rounded),label:'Medications'),
        NavigationDestination(icon:Icon(Icons.insights_outlined),selectedIcon:Icon(Icons.insights_rounded),label:'Insights'),
        NavigationDestination(icon:Icon(Icons.person_outline_rounded),selectedIcon:Icon(Icons.person_rounded),label:'You'),
      ],
    ),
  );
}
