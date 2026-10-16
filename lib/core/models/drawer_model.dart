import 'package:open_note/core/models/note_model.dart';

class DrawerModel {
  bool isOpen;
  List<NoteModel> notes;

  DrawerModel({this.isOpen = false, List<NoteModel>? notes})
      : notes = notes ?? [];
}