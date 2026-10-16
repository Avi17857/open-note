import 'package:flutter/foundation.dart';
import 'package:open_note/core/models/note_page_model.dart';

class NoteViewModel with ChangeNotifier {
  bool _loading = false;
  List<NotePageModel> pages = [];

  bool get loading => _loading;
  
  fetchPages() async {
    _loading = true;
    notifyListeners();
    // Simulate fetching pages from a data source
    await Future.delayed(Duration(seconds: 2));
    // After fetching, update the pages list
    pages = [
      NotePageModel(pageId: '1', noteId: 'note1', strokes: []),
      NotePageModel(pageId: '2', noteId: 'note1', strokes: []),
    ];
    _loading = false;
    notifyListeners();
  }

}