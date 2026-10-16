import 'package:flutter/foundation.dart';
import 'package:open_note/core/models/note_page_model.dart';

class NoteModel extends ChangeNotifier {
  String title;
  List<NotePageModel> pages;

  NoteModel({required this.title, required this.pages});
}