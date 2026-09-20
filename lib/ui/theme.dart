import 'package:flutter/material.dart';

const ink=Color(0xFF193C34);
const paper=Color(0xFFF4F5F2);
const muted=Color(0xFF56665D);
ThemeData doseTheme()=>ThemeData(
  useMaterial3:true,
  colorScheme:ColorScheme.fromSeed(seedColor:ink,primary:ink,surface:Colors.white,error:const Color(0xFFA22C29)),
  scaffoldBackgroundColor:paper,
  textTheme:const TextTheme(headlineLarge:TextStyle(fontSize:30,fontWeight:FontWeight.w600,color:ink),headlineSmall:TextStyle(fontSize:22,fontWeight:FontWeight.w600,color:ink),titleLarge:TextStyle(fontSize:20,fontWeight:FontWeight.w600),titleMedium:TextStyle(fontSize:17,fontWeight:FontWeight.w600),bodyLarge:TextStyle(fontSize:17,height:1.45),bodyMedium:TextStyle(fontSize:16,height:1.4),bodySmall:TextStyle(fontSize:14,height:1.4,color:muted),labelLarge:TextStyle(fontSize:16,fontWeight:FontWeight.w600)),
  appBarTheme:const AppBarTheme(backgroundColor:paper,foregroundColor:ink,surfaceTintColor:Colors.transparent,centerTitle:false),
  inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),contentPadding:const EdgeInsets.all(16)),
  filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(minimumSize:const Size(48,50),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)))),
  outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(minimumSize:const Size(48,50),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)))),
  navigationBarTheme:const NavigationBarThemeData(backgroundColor:Colors.white,indicatorColor:Color(0xFFDDE8DB)),
  dividerTheme:const DividerThemeData(color:Color(0xFFD3DAD4),space:24),
);

class Section extends StatelessWidget {
  final String title; final Widget child;
  const Section(this.title,this.child,{super.key});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),child]));
}
class Notice extends StatelessWidget {
  final String text;
  const Notice(this.text,{super.key});
  @override Widget build(BuildContext context)=>Container(width:double.infinity,margin:const EdgeInsets.symmetric(vertical:12),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFFF6E8C6),borderRadius:BorderRadius.circular(10)),child:Text(text,style:const TextStyle(color:Color(0xFF59461C),fontSize:15,height:1.4)));
}
void showError(BuildContext context,Object error){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error.toString().replaceFirst('Invalid argument(s): ',''))));}
