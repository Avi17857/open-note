import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:open_note/core/models/note_page_model.dart';
import 'package:open_note/core/utils/ReadWriteFiles.dart';

class NotePageViewModel with ChangeNotifier {
  bool _loading = false;
  NotePageModel page;

  bool get loading => _loading;

  NotePageViewModel({required this.page});

  loadPage() async {
    // Load page data from file
    String data = await readNote('$page.noteId/$page.pageId.txt');
    var json = jsonDecode(data);
    page.strokes = (json as List)
        .map<List<Offset>>((line) => (line as List)
            .map<Offset>((point) => Offset(point['dx'], point['dy']))
            .toList())
        .toList();
  }

  savePage() async {
    // Save page data to file
    var json = jsonEncode(page.strokes
        .map((line) =>
            line.map((point) => {'dx': point.dx, 'dy': point.dy}).toList())
        .toList());
    await writeNote(json, '${page.noteId}/${page.pageId}.txt');
  }
  
}