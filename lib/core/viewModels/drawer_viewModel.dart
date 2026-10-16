import 'package:flutter/foundation.dart';
import 'package:open_note/core/models/note_model.dart';
import 'package:open_note/core/models/drawer_model.dart';

class DrawerViewModel extends ChangeNotifier {
  final DrawerModel _drawerModel = DrawerModel();

  bool get isOpen => _drawerModel.isOpen;
  List<NoteModel> get notes => _drawerModel.notes;

  void toggleDrawer() {
    _drawerModel.isOpen = !_drawerModel.isOpen;
    notifyListeners();
  }

}