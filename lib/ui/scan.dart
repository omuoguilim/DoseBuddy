import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/store.dart';
import '../core/reminders.dart';
import 'medication_editor.dart';
import 'theme.dart';

class ScanPage extends StatefulWidget{
  final AppStore store;final Reminders reminders;
  const ScanPage({super.key,required this.store,required this.reminders});
  @override State<ScanPage> createState()=>_ScanPageState();
}
class _ScanPageState extends State<ScanPage>{
  XFile? image;String text='';String? error;bool busy=false;
  Future<void> cleanup(XFile? file)async{if(file==null)return;try{await File(file.path).delete();}catch(_){/* OS cache cleanup may be deferred. */}}
  @override void dispose(){cleanup(image);super.dispose();}
  Future<void> pick(ImageSource source)async{
    setState((){busy=true;error=null;});TextRecognizer? reader;
    try{
      final file=await ImagePicker().pickImage(source:source,imageQuality:95,maxWidth:2500);
      if(file==null)return;if(!mounted){await cleanup(file);return;}
      await cleanup(image);image=file;
      reader=TextRecognizer(script:TextRecognitionScript.latin);
      final result=await reader.processImage(InputImage.fromFilePath(file.path));
      if(mounted)setState((){text=result.text.trim();if(text.isEmpty)error='No readable text found. Try a clear photo or enter the medication manually.';});
    }catch(_){if(mounted)setState(()=>error='Unable to read the label. Check camera or photo permissions, try another image, or enter the medication manually.');}
    finally{await reader?.close();if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Read a prescription label')),body:ListView(padding:const EdgeInsets.all(20),children:[
    const Text('Text is read on this device. Keep the original prescription beside you while you enter and verify the details.'),const SizedBox(height:16),
    if(image!=null)Image.file(File(image!.path),height:280,fit:BoxFit.contain),
    Wrap(spacing:12,runSpacing:12,children:[OutlinedButton.icon(onPressed:busy?null:()=>pick(ImageSource.camera),icon:const Icon(Icons.camera_alt_outlined),label:const Text('Camera')),OutlinedButton.icon(onPressed:busy?null:()=>pick(ImageSource.gallery),icon:const Icon(Icons.photo_library_outlined),label:const Text('Photo library'))]),
    if(busy)const Padding(padding:EdgeInsets.all(20),child:Center(child:CircularProgressIndicator())),if(error!=null)Notice(error!),
    if(text.isNotEmpty)...[const SizedBox(height:20),Section('Unverified text',SelectableText(text)),const Notice('Names, decimals, combination strengths and concentrations can be misread. No dose or schedule is inferred from this text.'),FilledButton(onPressed:busy?null:()async{final result=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>MedicationEditor(store:widget.store,reminders:widget.reminders,draft:{'notes':'Label transcription (unverified):\n$text'})));if(result==true&&context.mounted)Navigator.pop(context);},child:const Text('Enter and verify medication'))],
    const SizedBox(height:16),TextButton(onPressed:busy?null:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>MedicationEditor(store:widget.store,reminders:widget.reminders))),child:const Text('Enter manually instead')),
  ]));
}
