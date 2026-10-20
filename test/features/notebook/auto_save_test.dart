import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/notebook/controllers/notebook_controller.dart';
import 'package:open_note/features/notebook/models/note_document.dart';
import 'package:open_note/features/storage/note_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CanvasController canvasController;
  late NoteStorageService storageService;
  late NotebookController notebookController;

  setUp(() async {
    canvasController = CanvasController();
    storageService = NoteStorageService();
    notebookController = NotebookController(
      canvasController: canvasController,
      storageService: storageService,
    );
    await notebookController.loadLibraryFuture;
  });

  tearDown(() {
    notebookController.dispose();
    canvasController.dispose();
  });

  group('NotebookController Auto-Save & Storage Tests', () {
    test('Initializes with active note and saved status', () {
      expect(notebookController.currentNote, isNotNull);
      expect(notebookController.saveStatus, equals(SaveStatus.saved));
      expect(notebookController.notes.isNotEmpty, isTrue);
    });

    test('Canvas content modification sets saveStatus to hasUnsavedChanges', () {
      expect(notebookController.saveStatus, equals(SaveStatus.saved));

      canvasController.markContentChanged();
      canvasController.notifyListeners();

      expect(notebookController.saveStatus, equals(SaveStatus.hasUnsavedChanges));
    });

    test('flushAutoSave immediately persists pending changes and resets status to saved', () async {
      notebookController.updateNoteTitle('Updated Project Title');
      expect(notebookController.saveStatus, equals(SaveStatus.hasUnsavedChanges));

      await notebookController.flushAutoSave();

      expect(notebookController.saveStatus, equals(SaveStatus.saved));
      final loaded = await storageService.loadDocument(notebookController.currentNote.id);
      expect(loaded, isNotNull);
      expect(loaded!.title, equals('Updated Project Title'));
    });

    test('duplicateNote creates a distinct clone and saves to library', () async {
      final initialCount = notebookController.notes.length;
      final original = notebookController.currentNote;
      original.title = 'Original Note';

      await notebookController.duplicateNote(original);

      expect(notebookController.notes.length, equals(initialCount + 1));
      final copy = notebookController.notes.first;
      expect(copy.id, isNot(equals(original.id)));
      expect(copy.title, equals('Original Note (Copy)'));

      final loadedCopy = await storageService.loadDocument(copy.id);
      expect(loadedCopy, isNotNull);
    });

    test('renameNote updates title on non-active note', () async {
      final otherDoc = NoteDocument(
        id: 'other_note',
        title: 'Old Title',
      );
      await storageService.saveDocument(otherDoc);
      notebookController.createNewNote(title: 'Another Note');

      await notebookController.renameNote('other_note', 'Brand New Title');

      final loaded = await storageService.loadDocument('other_note');
      expect(loaded, isNotNull);
      expect(loaded!.title, equals('Brand New Title'));
    });

    test('deleteNote removes note from library and switches current note', () async {
      notebookController.createNewNote(title: 'Note 1');
      notebookController.createNewNote(title: 'Note 2');

      final note2Id = notebookController.currentNote.id;
      expect(notebookController.notes.length, greaterThanOrEqualTo(2));

      await notebookController.deleteNote(note2Id);

      expect(notebookController.notes.any((n) => n.id == note2Id), isFalse);
      expect(notebookController.currentNote.id, isNot(equals(note2Id)));
    });
  });
}
