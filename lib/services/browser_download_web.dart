import 'dart:js_interop';
@JS('dosebuddyDownload')
external void _download(JSString contents,JSString filename);
void downloadText(String contents,String filename) => _download(contents.toJS,filename.toJS);
