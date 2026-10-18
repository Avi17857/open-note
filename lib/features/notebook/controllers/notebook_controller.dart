import 'dart:async';
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
    canvasController.addListener(_onCanvasChanged);
  }

  void _onCanvasChanged() {
    final pageCountChanged =
        _currentNote.pages.length != canvasController.pages.length;
    final activeIndexChanged =
        _currentPageIndex != canvasController.activePageIndex;

    if (pageCountChanged || activeIndexChanged) {
      _currentNote.pages =
          canvasController.pages.map((p) => p.clone()).toList();
      _currentPageIndex = canvasController.activePageIndex;
      _currentNote.updatedAt = DateTime.now();

      scheduleMicrotask(() {
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    canvasController.removeListener(_onCanvasChanged);
    super.dispose();
  }

  List<NoteDocument> get notes => List.unmodifiable(_notes);
  NoteDocument get currentNote => _currentNote;
  int get currentPageIndex => _currentPageIndex;
  bool get isLoading => _isLoading;
  NotePage get currentPage {
    if (_currentPageIndex >= 0 &&
        _currentPageIndex < _currentNote.pages.length) {
      return _currentNote.pages[_currentPageIndex];
    }
    return _currentNote.pages.first;
  }

  void _initDefaultNote() {
    _currentNote = NoteDocument(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Untitled Note',
    );
    _notes = [_currentNote];
    _currentPageIndex = 0;
    canvasController.loadPages(_currentNote.pages, clearHistory: true);
  }

  void setCurrentNote(NoteDocument note) {
    _syncCurrentNote();
    _currentNote = note;
    _currentPageIndex = 0;
    canvasController.loadPages(_currentNote.pages, clearHistory: true);
    notifyListeners();
  }

  void createNewNote({String title = 'New Note'}) {
    _syncCurrentNote();
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
    canvasController.addPage();
  }

  void goToPage(int index) {
    canvasController.setActivePage(index);
  }

  void _syncCurrentNote() {
    _currentNote.pages =
        canvasController.pages.map((p) => p.clone()).toList();
    _currentNote.updatedAt = DateTime.now();
  }

  Future<void> saveCurrentNote() async {
    _syncCurrentNote();
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

