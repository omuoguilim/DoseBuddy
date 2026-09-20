import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dosebuddy/core/records.dart';
import 'package:dosebuddy/core/store.dart';
import 'package:dosebuddy/core/reminders.dart';
import 'package:dosebuddy/ui/home.dart';
import 'package:dosebuddy/ui/theme.dart';
import 'package:dosebuddy/ui/settings.dart';
import 'records_test.dart' show prescription;

void main(){
  test('CSV quoting preserves commas and quotes and escapes formula prefixes',(){expect(csvCell('a,"b"'),'"a,""b"""');expect(csvCell('=1+1'),'"\'=1+1"');});
  testWidgets('PRN-only routine is visible and opens a real record form',(tester)async{final data=Records.empty();Records(data).saveMedication('prn',prescription(type:'as_needed',times:[]),DateTime.now());final store=AppStore(data,(_)async{});await tester.pumpWidget(MaterialApp(theme:doseTheme(),home:Home(store:store,reminders:Reminders(),authenticate:()async=>true)));expect(find.text('As needed'),findsOneWidget);await tester.tap(find.text('Example medication · 10 mg'));await tester.pumpAndSettle();expect(find.text('Record dose'),findsOneWidget);expect(find.text('Save record'),findsOneWidget);expect(tester.takeException(),isNull);});
  testWidgets('history is reachable and shows calendar and export',(tester)async{final store=AppStore(Records.empty(),(_)async{});await tester.pumpWidget(MaterialApp(theme:doseTheme(),home:Home(store:store,reminders:Reminders(),authenticate:()async=>true)));await tester.tap(find.text('History'));await tester.pumpAndSettle();expect(find.textContaining('Calendar ·'),findsOneWidget);expect(find.text('Review and export records'),findsOneWidget);expect(tester.takeException(),isNull);});
  testWidgets('empty Today remains usable with large text on a narrow screen',(tester)async{tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);final store=AppStore(Records.empty(),(_)async{});await tester.pumpWidget(MaterialApp(theme:doseTheme(),builder:(c,child)=>MediaQuery(data:MediaQuery.of(c).copyWith(textScaler:const TextScaler.linear(2)),child:child!),home:Home(store:store,reminders:Reminders(),authenticate:()async=>true)));expect(find.text('No scheduled doses today'),findsOneWidget);expect(tester.takeException(),isNull);});
}
