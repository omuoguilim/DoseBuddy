import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dosebuddy/demo/demo_mode.dart';
import 'package:dosebuddy/demo/demo_shell.dart';
import 'package:dosebuddy/models/medication.dart';
import 'package:dosebuddy/square.dart';
import 'package:dosebuddy/widgets/dosebuddy_theme.dart';

void main() {
 late Box<Medication> box;
 setUpAll(() async {
  if(!DemoMode.enabled)return;
  SharedPreferences.setMockInitialValues({});
  await Hive.initFlutter();
  if(!Hive.isAdapterRegistered(0)) Hive.registerAdapter(MedicationAdapter());
  box=await Hive.openBox<Medication>(DemoMode.boxName);
  await DemoMode.seed(reset:true);
 });
 tearDownAll(() async { if(DemoMode.enabled) await box.close(); });
 testWidgets('Practice startup, charts and Care Circle work without Firebase', (tester) async {
  final originalErrorHandler=FlutterError.onError;
  final errors=<String>[];
  FlutterError.onError=(details){errors.add(details.toString());print('BROWSER FRAMEWORK ERROR: ${details.toString()}');originalErrorHandler?.call(details);};
  addTearDown(()=>FlutterError.onError=originalErrorHandler);
  try {
  print('BROWSER STEP: seed ${box.length} medications');
  tester.view.physicalSize=const Size(390,844);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  expect(box.length,3);
  expect(box.values.first.takenLog,isNotEmpty);
  print('BROWSER STEP: startup');
  await tester.pumpWidget(MaterialApp(theme:DoseBuddyTheme.light,home:const DemoShell()));
  await tester.pump(const Duration(seconds:1));
  expect(find.text('Demo · sample records'),findsOneWidget);
  expect(errors,isEmpty,reason:errors.join('\n')); 
  print('BROWSER STEP: Insights');
  await tester.tap(find.text('Insights').last);
  await tester.pump(const Duration(seconds:1));
  expect(errors,isEmpty,reason:errors.join('\n')); 
  print('BROWSER STEP: Care Circle');
  await tester.tap(find.text('Care Circle').last);
  await tester.pump(const Duration(seconds:1));
  expect(find.text('Sharing unavailable'),findsOneWidget);
  expect(errors,isEmpty,reason:errors.join('\n')); 
  for(final tab in ['Medications','Profile']) {
   print('BROWSER STEP: $tab');
   await tester.tap(find.text(tab).last);
   await tester.pump(const Duration(seconds:1));
   expect(errors,isEmpty,reason:errors.join('\n'));
  }
  print('BROWSER STEP: dose confirmation dismissal');
  final med=box.values.first;
  await tester.pumpWidget(MaterialApp(theme:DoseBuddyTheme.light,home:Scaffold(body:MySquare(medication:med,displayTime:med.times.first))));
  await tester.tap(find.text('Record taken'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('No'));
  await tester.runAsync(() async {await Future<void>.delayed(const Duration(milliseconds:150));});
  await tester.pump(const Duration(milliseconds:500));
  await tester.pump(const Duration(milliseconds:500));
  expect(find.byType(SnackBar),findsOneWidget);
  expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist,isFalse);
  expect(tester.widget<SnackBar>(find.byType(SnackBar)).showCloseIcon,isTrue);
  await tester.pump(const Duration(seconds:6));
  await tester.pump(const Duration(seconds:1));
  expect(find.byType(SnackBar),findsNothing);
  expect(med.wasTakenOn(DateTime.now(),med.times.first),isTrue);
  expect(errors,isEmpty,reason:errors.join('\n'));
  await tester.pumpWidget(const SizedBox());
  } catch(error,stack){print('BROWSER TEST FAILURE: $error\n$stack');rethrow;}
 },skip:!DemoMode.enabled);
}
