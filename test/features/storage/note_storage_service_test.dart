import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/notebook/models/note_document.dart';
import 'package:open_note/features/notebook/models/note_page.dart';
import 'package:open_note/features/storage/note_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NoteStorageService storageService;

  setUp(() {
    storageService = NoteStorageService();
  });

  group('NoteStorageService Local Persistence Tests', () {
    test('saveDocument and loadDocument retrieve correct data', () async {
      final doc = NoteDocument(
        id: 'test_note_1',
        title: 'Biology 101',
        pages: [
          NotePage(id: 'p1', pageNumber: 1),
          NotePage(id: 'p2', pageNumber: 2),
        ],
      );

      await storageService.saveDocument(doc);

      final loaded = await storageService.loadDocument('test_note_1');
      expect(loaded, isNotNull);
      expect(loaded!.id, equals('test_note_1'));
      expect(loaded.title, equals('Biology 101'));
      expect(loaded.pages.length, equals(2));
      expect(loaded.version, equals(1));
      expect(loaded.isDeleted, isFalse);
    });

    test('loadAllNotes returns saved notes list', () async {
      final docA = NoteDocument(
        id: 'note_a',
        title: 'Note A',
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final docB = NoteDocument(
        id: 'note_b',
        title: 'Note B',
        updatedAt: DateTime.now(),
      );

      await storageService.saveDocument(docA);
      await storageService.saveDocument(docB);

      final allNotes = await storageService.loadAllNotes();
      expect(allNotes.any((n) => n.id == 'note_a'), isTrue);
      expect(allNotes.any((n) => n.id == 'note_b'), isTrue);

      // Verify sorted by updatedAt descending
      final idxA = allNotes.indexWhere((n) => n.id == 'note_a');
      final idxB = allNotes.indexWhere((n) => n.id == 'note_b');
      expect(idxB, lessThan(idxA));
    });

    test('deleteNote removes document from storage', () async {
      final doc = NoteDocument(
        id: 'to_delete',
        title: 'Temporary Note',
      );

      await storageService.saveDocument(doc);
      expect(await storageService.loadDocument('to_delete'), isNotNull);

      await storageService.deleteNote('to_delete');
      final afterDelete = await storageService.loadDocument('to_delete');
      expect(afterDelete, isNull);
    });
  });
}
