import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dosebuddy/demo/demo_mode.dart';
import 'package:dosebuddy/demo/demo_shell.dart';
import 'package:dosebuddy/models/medication.dart';
import 'package:dosebuddy/widgets/dosebuddy_theme.dart';

void main() {
 testWidgets('Practice startup, charts and Care Circle work without Firebase', (tester) async {
  tester.view.physicalSize=const Size(390,844);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  await Hive.initFlutter();
  if(!Hive.isAdapterRegistered(0)) Hive.registerAdapter(MedicationAdapter());
  final box=await Hive.openBox<Medication>(DemoMode.boxName);
  await DemoMode.seed(reset:true);
  expect(box.length,3);
  expect(box.values.first.takenLog,isNotEmpty);
  await tester.pumpWidget(MaterialApp(theme:DoseBuddyTheme.light,home:const DemoShell()));
  await tester.pump(const Duration(seconds:1));
  expect(find.text('Practice mode · fictional data'),findsOneWidget);
  expect(tester.takeException(),isNull);
  await tester.tap(find.text('Insights').last);
  await tester.pump(const Duration(seconds:1));
  expect(tester.takeException(),isNull);
  await tester.tap(find.text('Care Circle').last);
  await tester.pump(const Duration(seconds:1));
  expect(find.text('Invitation beta'),findsOneWidget);
  expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox());
  await box.close();
 },skip:!DemoMode.enabled);
}
