import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/notebook/models/note_document.dart';
import 'package:open_note/features/notebook/models/note_page.dart';
import 'package:open_note/features/storage/note_storage_service.dart';

class NotebookController extends ChangeNotifier {
  final CanvasController canvasController;
  final NoteStorageService _storageService;

  List<NoteDocument> _notes = [];
  late NoteDocument _currentNote;
  int _currentPageIndex = 0;
  bool _isLoading = false;

  NotebookController({
    required this.canvasController,
    NoteStorageService? storageService,
  }) : _storageService = storageService ?? NoteStorageService() {
    _initDefaultNote();
  }

  List<NoteDocument> get notes => List.unmodifiable(_notes);
  NoteDocument get currentNote => _currentNote;
  int get currentPageIndex => _currentPageIndex;
  bool get isLoading => _isLoading;
  NotePage get currentPage => _currentNote.pages[_currentPageIndex];

  void _initDefaultNote() {
    _currentNote = NoteDocument(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Untitled Note',
    );
    _notes = [_currentNote];
    _currentPageIndex = 0;
  }

  void setCurrentNote(NoteDocument note) {
    _syncCurrentPageStrokes();
    _currentNote = note;
    _currentPageIndex = 0;
    canvasController.loadStrokes(_currentNote.pages[0].strokes);
    notifyListeners();
  }

  void createNewNote({String title = 'New Note'}) {
    _syncCurrentPageStrokes();
    final newNote = NoteDocument(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
    );
    _notes.add(newNote);
    setCurrentNote(newNote);
  }

  void updateNoteTitle(String title) {
    _currentNote.title = title;
    notifyListeners();
  }

  void addPage() {
    _syncCurrentPageStrokes();
    final newPage = NotePage(
      id: 'page_${DateTime.now().millisecondsSinceEpoch}',
      pageNumber: _currentNote.pages.length + 1,
    );
    _currentNote.pages.add(newPage);
    _currentPageIndex = _currentNote.pages.length - 1;
    canvasController.loadStrokes([]);
    notifyListeners();
  }

  void goToPage(int index) {
    if (index < 0 || index >= _currentNote.pages.length || index == _currentPageIndex) {
      return;
    }
    _syncCurrentPageStrokes();
    _currentPageIndex = index;
    canvasController.loadStrokes(_currentNote.pages[index].strokes);
    notifyListeners();
  }

  void _syncCurrentPageStrokes() {
    if (_currentPageIndex < _currentNote.pages.length) {
      _currentNote.pages[_currentPageIndex].strokes =
          List.from(canvasController.strokes);
      _currentNote.updatedAt = DateTime.now();
    }
  }

  Future<void> saveCurrentNote() async {
    _syncCurrentPageStrokes();
    _isLoading = true;
    notifyListeners();

    try {
      await _storageService.saveNote(_currentNote.id, _currentNote.toJson());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNote(String noteId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final json = await _storageService.loadNote(noteId);
      if (json != null) {
        final loaded = NoteDocument.fromJson(json);
        setCurrentNote(loaded);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
