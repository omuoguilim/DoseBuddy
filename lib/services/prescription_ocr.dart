import 'package:flutter/services.dart';

/// Native, on-device OCR. Label suggestions still require user confirmation.
class PrescriptionOcr {
  static const _channel = MethodChannel('dosebuddy/prescription_ocr');

  static Future<String> recognize(String imagePath) async {
    final text = await _channel.invokeMethod<String>('recognize', {'path': imagePath});
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('No readable label text');
    }
    return text;
  }
}
