import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dosebuddy/services/prescription_ocr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dosebuddy/prescription_ocr');
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('OCR passes image path and preserves recognized instructions', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'recognize');
      expect(call.arguments, {'path': '/tmp/label.jpg'});
      return 'Tacrolimus 1 mg\nTake 1 capsule in the morning';
    });
    expect(await PrescriptionOcr.recognize('/tmp/label.jpg'),
        'Tacrolimus 1 mg\nTake 1 capsule in the morning');
  });
  test('an unreadable label is not accepted as a successful scan', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => '  ');
    await expectLater(PrescriptionOcr.recognize('/tmp/label.jpg'),
        throwsA(isA<FormatException>()));
  });
}
