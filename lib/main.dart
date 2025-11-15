import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'login_page.dart';
import 'models/medication.dart';
import 'services/notification_services.dart';

void main() async 
{

  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  
  Hive.registerAdapter(MedicationAdapter());
  
  await Hive.openBox<Medication>('medications');

  await NotificationService().initialize();
  
  runApp(const MyApp());

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoseBuddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF5B67CA), 
          secondary: const Color(0xFF9B8CE8), 
          surface: Colors.white,
          background: const Color(0xFFF8F9FE), 
          error: const Color(0xFFE57373),
        ),
        
        scaffoldBackgroundColor: const Color(0xFFF8F9FE),
        
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Colors.white,
        ),
        
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF5B67CA),
          foregroundColor: Colors.white,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1D2E),
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1D2E),
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1D2E),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Color(0xFF6B6B6B),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Color(0xFF9E9E9E),
          ),
        ),
        
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B67CA),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF5B67CA),
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      home: const LoginPage(),
    );
  }
}