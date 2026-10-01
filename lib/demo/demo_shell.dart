import 'package:flutter/material.dart';
import '../mainscreen.dart';
import 'demo_mode.dart';

class DemoShell extends StatefulWidget {
 const DemoShell({super.key});
 @override State<DemoShell> createState()=>_DemoShellState();
}
class _DemoShellState extends State<DemoShell> {
 int _revision=0; bool _busy=false;
 Future<void> _reset() async {
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Reset practice data?'),content:const Text('Restore the sample records and clear your changes?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Reset'))]));
  if(ok!=true)return;
  setState(()=>_busy=true);
  await DemoMode.seed(reset:true);
  if(mounted)setState((){_revision++;_busy=false;});
 }
 @override Widget build(BuildContext context)=>Scaffold(body:Column(children:[
  SafeArea(bottom:false,child:Container(color:const Color(0xFFEEEAFB),padding:const EdgeInsets.only(left:12,right:4),child:Row(children:[const Expanded(child:Text('Demo · sample records',style:TextStyle(fontSize:12,color:Color(0xFF4F4680)))),TextButton(onPressed:_busy?null:_reset,child:const Text('Reset',style:TextStyle(fontSize:12)))]))),
  Expanded(child:ScaffoldMessenger(child:MainScreen(key:ValueKey(_revision)))),
 ]));
}
