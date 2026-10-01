import 'package:flutter/material.dart';

class DoseBuddyTheme {
  static const purple = Color(0xFF5B67CA);
  static const lavender = Color(0xFF9B8CE8);
  static const ink = Color(0xFF1A1D2E);
  static const muted = Color(0xFF62677A);
  static const surface = Color(0xFFF7F7FC);
  static const tint = Color(0xFFF0EEFF);
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: purple).copyWith(primary: purple, secondary: lavender, surface: Colors.white),
    scaffoldBackgroundColor: surface,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize:24,fontWeight:FontWeight.w700,color:ink),
      titleLarge: TextStyle(fontSize:20,fontWeight:FontWeight.w700,color:ink),
      titleMedium: TextStyle(fontSize:16,fontWeight:FontWeight.w600,color:ink),
      bodyLarge: TextStyle(fontSize:16,color:ink),
      bodyMedium: TextStyle(fontSize:14,color:ink,height:1.4),
      bodySmall: TextStyle(fontSize:12,color:muted,height:1.4),
    ),
    appBarTheme: const AppBarTheme(backgroundColor:surface,foregroundColor:ink,elevation:0,scrolledUnderElevation:0,centerTitle:false,titleTextStyle:TextStyle(fontSize:24,fontWeight:FontWeight.w700,color:ink)),
    cardTheme: CardThemeData(elevation:0,color:Colors.white,margin:const EdgeInsets.symmetric(vertical:6),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:const BorderSide(color:Color(0xFFE8E8F2)))),
    inputDecorationTheme: InputDecorationTheme(filled:true,fillColor:Colors.white,contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:16),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:Color(0xFFDEDFEB))),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:Color(0xFFDEDFEB))),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:purple,width:2))),
    elevatedButtonTheme: ElevatedButtonThemeData(style:ElevatedButton.styleFrom(backgroundColor:purple,foregroundColor:Colors.white,elevation:0,minimumSize:const Size(48,48),padding:const EdgeInsets.symmetric(horizontal:20,vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),textStyle:const TextStyle(fontSize:15,fontWeight:FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(style:OutlinedButton.styleFrom(foregroundColor:purple,minimumSize:const Size(48,48),side:const BorderSide(color:purple),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)))),
    textButtonTheme: TextButtonThemeData(style:TextButton.styleFrom(foregroundColor:purple,minimumSize:const Size(48,48))),
    chipTheme: ChipThemeData(selectedColor:tint,backgroundColor:Colors.white,side:const BorderSide(color:Color(0xFFE2E1EF)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
    snackBarTheme: SnackBarThemeData(backgroundColor:ink,actionTextColor:Colors.white,behavior:SnackBarBehavior.floating,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
    floatingActionButtonTheme:const FloatingActionButtonThemeData(backgroundColor:purple,foregroundColor:Colors.white),
  );
}

class MedicationGlyph extends StatelessWidget {
  const MedicationGlyph({super.key});
  @override
  Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:DoseBuddyTheme.tint,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.medication_outlined,color:DoseBuddyTheme.purple));
}
