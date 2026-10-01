import 'dart:js_interop';
@JS('dosebuddyRecognize')
external JSPromise<JSString> _recognize(JSString path);
Future<String> recognizeWeb(String path) async => (await _recognize(path.toJS).toDart).toDart;
