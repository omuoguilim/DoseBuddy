import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
Future<String> durablePhotoPath(XFile photo) async => kIsWeb ? Uri.dataFromBytes(await photo.readAsBytes(),mimeType:photo.mimeType ?? 'image/jpeg').toString() : photo.path;
Widget platformPhoto(String path,{double? height,BoxFit fit=BoxFit.cover,ImageErrorWidgetBuilder? errorBuilder}) => kIsWeb ? Image.network(path,height:height,fit:fit,errorBuilder:errorBuilder) : Image.file(File(path),height:height,fit:fit,errorBuilder:errorBuilder);
