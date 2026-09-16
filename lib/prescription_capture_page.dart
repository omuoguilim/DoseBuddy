import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'add_medication_page.dart';

class PrescriptionCapturePage extends StatefulWidget {
  const PrescriptionCapturePage({super.key});
  @override State<PrescriptionCapturePage> createState()=>_PrescriptionCapturePageState();
}

class _PrescriptionCapturePageState extends State<PrescriptionCapturePage>{
  XFile? image;
  bool scanning=false;
  String? error;
  String rawText='';
  Map<String,String> fields={};

  Future<void> pick(ImageSource source) async {
    final x=await ImagePicker().pickImage(source:source,imageQuality:90,maxWidth:2200);
    if(x==null)return;
    setState((){image=x;rawText='';fields={};error=null;});
    await _scan(x);
  }

  Future<void> _scan(XFile x) async {
    setState(()=>scanning=true);
    final recognizer=TextRecognizer(script:TextRecognitionScript.latin);
    try{
      final result=await recognizer.processImage(InputImage.fromFilePath(x.path));
      final text=result.text.trim();
      if(!mounted)return;
      if(text.isEmpty){
        setState(()=>error='No readable text was found. Try a closer photo with the label flat, well lit, and in focus.');
        return;
      }
      setState((){rawText=text;fields=_parse(text);});
    }catch(e){
      if(mounted)setState(()=>error='DoseBuddy could not read this image. Try another photo. (${e.runtimeType})');
    }finally{
      await recognizer.close();
      if(mounted)setState(()=>scanning=false);
    }
  }

  Map<String,String> _parse(String text){
    final lines=text.split(RegExp(r'[\r\n]+')).map((e)=>e.replaceAll(RegExp(r'\s+'),' ').trim()).where((e)=>e.isNotEmpty).toList();
    String strength='', name='', instructions='', quantity='', prescriber='', pharmacy='';

    final strengthRe=RegExp(r'\b(\d+(?:\.\d+)?)\s*(mcg|mg|g|ml|mL|%|units?)\b',caseSensitive:false);
    final qtyRe=RegExp(r'\b(?:qty|quantity)\s*[:#]?\s*(\d+)\b',caseSensitive:false);
    final rxNoise=RegExp(r'\b(rx|rx#|refill|refills|ndc|dob|date|discard|use before|pharmacy|prescriber|patient)\b',caseSensitive:false);
    final sigStart=RegExp(r'^(take|use|apply|instill|inhale|inject|dissolve|place)\b',caseSensitive:false);

    for(final line in lines){
      final sm=strengthRe.firstMatch(line);
      if(strength.isEmpty && sm!=null) strength=sm.group(0)!;
      final qm=qtyRe.firstMatch(line);
      if(quantity.isEmpty && qm!=null) quantity=qm.group(1)!;
      if(instructions.isEmpty && sigStart.hasMatch(line)) instructions=line;
      if(prescriber.isEmpty){
        final m=RegExp(r'^(?:prescriber|prescribed by|dr\.?|doctor)\s*[:\-]?\s*(.+)$',caseSensitive:false).firstMatch(line);
        if(m!=null)prescriber=m.group(1)!.trim();
      }
      if(pharmacy.isEmpty && RegExp(r'\b(pharmacy|cvs|walgreens|rite aid|walmart pharmacy|publix pharmacy|kroger pharmacy)\b',caseSensitive:false).hasMatch(line)) pharmacy=line;
    }

    // Medication names are commonly printed near the strength. Prefer that line,
    // but never invent a value when the label structure is ambiguous.
    for(final line in lines){
      if(strengthRe.hasMatch(line) && !rxNoise.hasMatch(line)){
        var candidate=line.replaceAll(strengthRe,'').replaceAll(RegExp(r'\b(tablets?|capsules?|solution|suspension|cream|ointment)\b',caseSensitive:false),'').trim();
        candidate=candidate.replaceAll(RegExp(r'^[^A-Za-z]+|[^A-Za-z0-9)]+$'),'').trim();
        if(candidate.length>=3 && RegExp(r'[A-Za-z]{3}').hasMatch(candidate)){name=candidate;break;}
      }
    }

    return {
      'name':name,
      'strength':strength,
      'instructions':instructions,
      'quantity':quantity,
      'prescriber':prescriber,
      'pharmacy':pharmacy,
    };
  }

  void _review(){
    final values=Map<String,String>.from(fields);
    values['scanNotes']='Imported from a prescription-label scan. Verify every field against the original label before saving.';
    Navigator.push(context,MaterialPageRoute(builder:(_)=>AddMedicationPage(initialValues:values)));
  }

  Widget _field(String label,String key){
    final value=fields[key]?.trim()??'';
    return Padding(padding:const EdgeInsets.only(bottom:10),child:Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.grey.shade200)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:12,color:Colors.grey,fontWeight:FontWeight.w700)),const SizedBox(height:4),Text(value.isEmpty?'Not confidently detected':value,style:TextStyle(fontWeight:FontWeight.w700,color:value.isEmpty?Colors.orange.shade800:Colors.black87))])));
  }

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:const Color(0xFFF7F8FC),
    appBar:AppBar(backgroundColor:const Color(0xFFF7F8FC),surfaceTintColor:Colors.transparent,title:const Text('Scan prescription label')),
    body:ListView(padding:const EdgeInsets.all(22),children:[
      const Text('Scan your label',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),
      const SizedBox(height:8),
      const Text('DoseBuddy reads text on-device, then asks you to verify the result before anything is saved.',style:TextStyle(color:Colors.grey,height:1.45)),
      const SizedBox(height:20),
      Container(height:220,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:const Color(0xFFF0F1F7),borderRadius:BorderRadius.circular(24)),child:image==null?const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.document_scanner_outlined,size:54,color:Color(0xFF5B67CA)),SizedBox(height:10),Text('Keep the full pharmacy label in frame')])):Image.file(File(image!.path),fit:BoxFit.cover,width:double.infinity)),
      const SizedBox(height:14),
      Row(children:[Expanded(child:OutlinedButton.icon(onPressed:scanning?null:()=>pick(ImageSource.camera),icon:const Icon(Icons.camera_alt_outlined),label:const Text('Camera'))),const SizedBox(width:10),Expanded(child:OutlinedButton.icon(onPressed:scanning?null:()=>pick(ImageSource.gallery),icon:const Icon(Icons.photo_library_outlined),label:const Text('Library')))]),
      if(scanning)...[const SizedBox(height:22),const Center(child:Column(children:[CircularProgressIndicator(),SizedBox(height:10),Text('Reading prescription label…',style:TextStyle(fontWeight:FontWeight.w700))]))],
      if(error!=null)...[const SizedBox(height:18),Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:const Color(0xFFFFEEEE),borderRadius:BorderRadius.circular(16)),child:Text(error!,style:const TextStyle(height:1.4)))],
      if(rawText.isNotEmpty && !scanning)...[
        const SizedBox(height:24),
        const Text('DoseBuddy detected',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
        const SizedBox(height:12),
        _field('Medication','name'),_field('Strength','strength'),_field('Directions','instructions'),_field('Quantity','quantity'),_field('Prescriber','prescriber'),_field('Pharmacy','pharmacy'),
        const SizedBox(height:8),
        Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFFFFF4DE),borderRadius:BorderRadius.circular(16)),child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.verified_user_outlined,color:Color(0xFF9A6500)),SizedBox(width:10),Expanded(child:Text('OCR can make mistakes. Compare every detected field with the original prescription label before saving or scheduling a dose.',style:TextStyle(height:1.4)))])),
        const SizedBox(height:16),
        SizedBox(height:54,child:FilledButton.icon(onPressed:_review,icon:const Icon(Icons.fact_check_outlined),label:const Text('Verify medication details'))),
        const SizedBox(height:12),
        ExpansionTile(tilePadding:EdgeInsets.zero,title:const Text('View all recognized text'),children:[Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:SelectableText(rawText))]),
      ]
    ])
  );
}
