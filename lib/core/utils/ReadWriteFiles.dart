
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:path_provider/path_provider.dart';


writeNote(String content, String filePath) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = directory.path;
  final file = File('$path/$filePath');
  // print("JSON ENCODED:\n $json");
  // for (var line in lines) {
  //   for (var point in line) {
  //     data += "${point.dx},${point.dy};";
  //   }
  //   data += "\n";
  // }
  await file.writeAsString(content);
}

Future<String> readNote(String filePath) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = directory.path;
  final file = File('$path/$filePath');
  String data = await file.readAsString();
  return data;
  // print("JSON DECODED:\n $json");

}