
import 'dart:convert';
import 'dart:ui';
import 'package:open_note/core/utils/ReadWriteFiles.dart';

class NotePageModel {
  String pageId;
  String noteId;
  List<List<Offset>> strokes;

  NotePageModel({
    required this.pageId,
    required this.noteId,
    this.strokes = const [],
  });

  factory NotePageModel.fromJson(Map<String, dynamic> json) {
    return NotePageModel(
      pageId: json['pageId'],
      noteId: json['noteId'],
      strokes: (json['strokes'] as List)
          .map<List<Offset>>((line) => (line as List)
              .map<Offset>((point) => Offset(point['dx'], point['dy']))
              .toList())
          .toList(),
    );
  }

}