import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dosebuddy/onboarding_page.dart';
import 'package:dosebuddy/name_input_dialog.dart';
import 'package:dosebuddy/widgets/dosebuddy_theme.dart';

void main() {
  testWidgets('onboarding scrolls at enlarged text without losing Next', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: DoseBuddyTheme.light,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.8)), child: child!),
      home: const OnboardingPage()));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Track Your Progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('name dialog scrolls above keyboard with both name fields', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(theme: DoseBuddyTheme.light,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.8)), child: child!),
      home: const Scaffold(body: NameInputDialog())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.ensureVisible(find.text('Continue'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

