import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dosebuddy/add_medication_page.dart';
import 'package:dosebuddy/widgets/dosebuddy_theme.dart';
void main(){
  testWidgets('unfinished medication restores its details and stops invalid strength',(tester)async{
    SharedPreferences.setMockInitialValues({'medication_draft':jsonEncode({'name':'Restored medication','strength':'20','unit':'mg','notes':'Label instructions','times':['8:00 AM'],'track':false,'total':'','threshold':''})});
    await tester.pumpWidget(MaterialApp(theme:DoseBuddyTheme.light,home:const AddMedicationPage()));
    await tester.pumpAndSettle();
    final fields=tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.any((f)=>f.controller?.text=='Restored medication'),true);
    expect(fields.any((f)=>f.controller?.text=='20'),true);
    final strength=find.byWidgetPredicate((w)=>w is TextField&&w.controller?.text=='20');
    await tester.enterText(strength,'0');
    await tester.ensureVisible(find.text('Continue'));await tester.tap(find.text('Continue'));await tester.pumpAndSettle();
    expect(find.text('Enter a positive numeric strength'),findsOneWidget);
    final p=await SharedPreferences.getInstance();
    expect((jsonDecode(p.getString('medication_draft')!) as Map)['name'],'Restored medication');
    await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
  });
}
