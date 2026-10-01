import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dosebuddy/models/medication.dart';
import 'package:dosebuddy/today_page.dart';
import 'package:dosebuddy/widgets/dosebuddy_theme.dart';
void main(){
  late Directory directory;
  setUpAll(()async{directory=await Directory.systemTemp.createTemp('dosebuddy-ui-test');Hive.init(directory.path);Hive.registerAdapter(MedicationAdapter());await Hive.openBox<Medication>('medications'); final m=Medication(id:'test',name:'A long medication label for layout testing',dosage:'10 mg',times:['8:00 AM','8:00 PM'],createdAt:DateTime.now().subtract(const Duration(days:1))); await Hive.box<Medication>('medications').put(m.id,m);});
  tearDownAll(()async{await Hive.close();await directory.delete(recursive:true);});
  testWidgets('Today supports a narrow screen with enlarged text and live dose records',(tester)async{
    SharedPreferences.setMockInitialValues({'user_name':'Oli'});
    tester.view.physicalSize=const Size(320,900);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme:DoseBuddyTheme.light,home:const MediaQuery(data:MediaQueryData(textScaler:TextScaler.linear(1.8)),child:TodayPage())));
    await tester.pump();await tester.pump(const Duration(milliseconds:100));
    expect(find.textContaining('Oli'),findsOneWidget);
    expect(find.text("Today's progress"),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
