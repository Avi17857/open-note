import 'dart:async';
import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/notebook/models/note_document.dart';
import 'package:open_note/features/notebook/models/note_page.dart';
import 'package:open_note/features/storage/note_storage_service.dart';

/// Indicates the current persistence state of the active note.
enum SaveStatus {
  saved,
  saving,
  hasUnsavedChanges,
}

class NotebookController extends ChangeNotifier {
  final CanvasController canvasController;
  final NoteStorageService _storageService;

  List<NoteDocument> _notes = [];
  late NoteDocument _currentNote;
  int _currentPageIndex = 0;
  bool _isLoading = false;

  SaveStatus _saveStatus = SaveStatus.saved;
  Timer? _autoSaveTimer;
  static const Duration _autoSaveDebounce = Duration(milliseconds: 1200);
  int _lastCanvasContentVersion = 0;

  bool _isDisposed = false;
  Future<void>? _loadLibraryFuture;

  NotebookController({
    required this.canvasController,
    NoteStorageService? storageService,
  }) : _storageService = storageService ?? NoteStorageService() {
    _initDefaultNote();
    _loadLibraryFuture = _loadLibraryFromStorage();
    canvasController.addListener(_onCanvasChanged);
  }

  Future<void> get loadLibraryFuture => _loadLibraryFuture ?? Future.value();

  SaveStatus get saveStatus => _saveStatus;
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
    _lastCanvasContentVersion = canvasController.contentVersion;
    canvasController.loadPages(_currentNote.pages, clearHistory: true);
    _saveStatus = SaveStatus.saved;
  }

  /// Scans local disk storage / browser persistence on startup and loads existing note documents.
  Future<void> _loadLibraryFromStorage() async {
    _isLoading = true;
    if (!_isDisposed) notifyListeners();

    try {
      final loadedNotes = await _storageService.loadAllNotes();
      if (_isDisposed) return;

      if (loadedNotes.isNotEmpty) {
        // Merge without duplicate IDs
        final Set<String> existingIds = _notes.map((n) => n.id).toSet();
        for (final doc in loadedNotes) {
          if (!existingIds.contains(doc.id)) {
            _notes.add(doc);
          }
        }

        // If the initial note is untouched, activate the most recently updated note
        final initialNoteUntouched = _currentNote.title == 'Untitled Note' &&
            _currentNote.pages.length == 1 &&
            _currentNote.pages.first.strokes.isEmpty &&
            _currentNote.pages.first.textBoxes.isEmpty &&
            _currentNote.pages.first.images.isEmpty;

        if (initialNoteUntouched && loadedNotes.isNotEmpty) {
          _currentNote = loadedNotes.first;
          _currentPageIndex = 0;
          canvasController.loadPages(_currentNote.pages, clearHistory: true);
          _lastCanvasContentVersion = canvasController.contentVersion;
        }
        _saveStatus = SaveStatus.saved;
      } else {
        // Initial first-time launch: persist the initial default note
        await _storageService.saveNote(_currentNote.id, _currentNote.toJson());
        _saveStatus = SaveStatus.saved;
      }
    } catch (e) {
      debugPrint('Error initializing note library: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _onCanvasChanged() {
    if (_isDisposed) return;
    final pageCountChanged =
        _currentNote.pages.length != canvasController.pages.length;
    final activeIndexChanged =
        _currentPageIndex != canvasController.activePageIndex;
    final contentChanged =
        canvasController.contentVersion != _lastCanvasContentVersion;

    if (pageCountChanged || activeIndexChanged || contentChanged) {
      _lastCanvasContentVersion = canvasController.contentVersion;
      _currentNote.pages =
          canvasController.pages.map((p) => p.clone()).toList();
      _currentPageIndex = canvasController.activePageIndex;
      _currentNote.updatedAt = DateTime.now();

      _scheduleAutoSave();

      scheduleMicrotask(() {
        if (!_isDisposed) notifyListeners();
      });
    }
  }

  /// Debounces auto-save execution by 1200ms after drawing/editing pauses.
  void _scheduleAutoSave() {
    if (_isDisposed) return;
    _saveStatus = SaveStatus.hasUnsavedChanges;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDebounce, () async {
      await _executeAutoSave();
    });
  }

  Future<void> _executeAutoSave() async {
    if (_isDisposed || _saveStatus == SaveStatus.saving) return;
    _saveStatus = SaveStatus.saving;
    if (!_isDisposed) notifyListeners();

    try {
      _syncCurrentNote();
      await _storageService.saveNote(_currentNote.id, _currentNote.toJson());
      if (_isDisposed) return;
      _saveStatus = SaveStatus.saved;
    } catch (e) {
      debugPrint('Auto-save error: $e');
      if (_isDisposed) return;
      _saveStatus = SaveStatus.hasUnsavedChanges;
    } finally {
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// Immediately flushes any pending debounced auto-save to disk.
  Future<void> flushAutoSave() async {
    if (_autoSaveTimer?.isActive == true) {
      _autoSaveTimer?.cancel();
      await _executeAutoSave();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _autoSaveTimer?.cancel();
    canvasController.removeListener(_onCanvasChanged);
    super.dispose();
  }

  void setCurrentNote(NoteDocument note) {
    flushAutoSave();
    _syncCurrentNote();

    _currentNote = note;
    _currentPageIndex = 0;
    canvasController.loadPages(_currentNote.pages, clearHistory: true);
    _lastCanvasContentVersion = canvasController.contentVersion;
    _saveStatus = SaveStatus.saved;
    notifyListeners();
  }

  void createNewNote({String title = 'New Note'}) {
    flushAutoSave();
    _syncCurrentNote();

    final newNote = NoteDocument(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
    );
    _notes.insert(0, newNote);
    _storageService.saveNote(newNote.id, newNote.toJson());
    setCurrentNote(newNote);
  }

  void updateNoteTitle(String title) {
    if (_currentNote.title == title) return;
    _currentNote.title = title;
    _currentNote.updatedAt = DateTime.now();
    _scheduleAutoSave();
    notifyListeners();
  }

  Future<void> renameNote(String noteId, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;

    if (_currentNote.id == noteId) {
      updateNoteTitle(trimmed);
      return;
    }

    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _notes[index].title = trimmed;
      _notes[index].updatedAt = DateTime.now();
      await _storageService.saveNote(_notes[index].id, _notes[index].toJson());
      notifyListeners();
    } else {
      final doc = await _storageService.loadDocument(noteId);
      if (doc != null) {
        doc.title = trimmed;
        doc.updatedAt = DateTime.now();
        await _storageService.saveDocument(doc);
        _notes.add(doc);
        notifyListeners();
      }
    }
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

  /// Synchronizes canvas in-memory pages to the current note document model.
  void syncCurrentNote() {
    _syncCurrentNote();
  }

  /// Explicit manual save triggered by button or shortcut.
  Future<void> saveCurrentNote() async {
    _autoSaveTimer?.cancel();
    _syncCurrentNote();
    _saveStatus = SaveStatus.saving;
    _isLoading = true;
    notifyListeners();

    try {
      await _storageService.saveNote(_currentNote.id, _currentNote.toJson());
      _saveStatus = SaveStatus.saved;
    } catch (e) {
      _saveStatus = SaveStatus.hasUnsavedChanges;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNote(String noteId) async {
    await flushAutoSave();
    _isLoading = true;
    notifyListeners();

    try {
      final map = await _storageService.loadNote(noteId);
      if (map != null) {
        final loaded = NoteDocument.fromJson(map);
        setCurrentNote(loaded);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteNote(String noteId) async {
    await _storageService.deleteNote(noteId);
    _notes.removeWhere((n) => n.id == noteId);

    if (_currentNote.id == noteId) {
      if (_notes.isNotEmpty) {
        setCurrentNote(_notes.first);
      } else {
        createNewNote(title: 'Untitled Note');
      }
    } else {
      notifyListeners();
    }
  }

  Future<void> duplicateNote(NoteDocument note) async {
    await flushAutoSave();
    final cloned = note.clone(
      newId: 'note_${DateTime.now().millisecondsSinceEpoch}',
    );
    cloned.title = '${note.title} (Copy)';
    cloned.updatedAt = DateTime.now();

    _notes.insert(0, cloned);
    await _storageService.saveNote(cloned.id, cloned.toJson());
    notifyListeners();
  }

  /// Exports the note to an external `.opennote` file anywhere on the user's computer.
  Future<String?> exportNoteToFile(NoteDocument note) async {
    _syncCurrentNote();
    return _storageService.exportNoteToFile(note);
  }

  /// Imports an `.opennote` or `.json` file from the user's computer into the library.
  Future<bool> importNoteFromFile() async {
    await flushAutoSave();
    final imported = await _storageService.importNoteFromFile();
    if (imported == null) return false;

    // Ensure unique ID in case of ID collision
    String uniqueId = imported.id;
    if (_notes.any((n) => n.id == uniqueId)) {
      uniqueId = 'imported_${DateTime.now().millisecondsSinceEpoch}';
    }
    final doc = imported.clone(newId: uniqueId);

    _notes.insert(0, doc);
    await _storageService.saveNote(doc.id, doc.toJson());
    setCurrentNote(doc);
    return true;
  }
}
