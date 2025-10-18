
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

List<List<Offset>> lines = [];

// class Strokes {
//   List<List<Offset>> points;
//   List<String> keys = [];

//   Strokes() : points = [];

//   @override
//   String toString() {
//     // TODO: implement toString
//     return 'Strokes{points: $points, keys: $keys}';
//   }
  
//   int get length {
//     return points.length;
//   }
// }


writeNote() async {
  final directory = await getApplicationDocumentsDirectory();
  final path = directory.path;
  final file = File('$path/note.txt');
  String data = "";
  var newData = lines.map((line) => line.map((point) => {'dx': point.dx, 'dy': point.dy}).toList()).toList();
  var json = jsonEncode(newData);
  // print("JSON ENCODED:\n $json");
  // for (var line in lines) {
  //   for (var point in line) {
  //     data += "${point.dx},${point.dy};";
  //   }
  //   data += "\n";
  // }
  await file.writeAsString(json);
}

readNote() async {
  final directory = await getApplicationDocumentsDirectory();
  final path = directory.path;
  final file = File('$path/note.txt');
  String data = await file.readAsString();
  var json = jsonDecode(data);
  // print("JSON DECODED:\n $json");
  lines = (json as List).map<List<Offset>>((line) => (line as List).map<Offset>((point) => Offset(point['dx'], point['dy'])).toList()).toList();

}