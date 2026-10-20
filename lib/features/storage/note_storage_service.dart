import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_note/features/notebook/models/note_document.dart';

/// Service managing persistent local note storage, library cataloging,
/// and external file export/import.
class NoteStorageService {
  static const String _noteFileExtension = '.opennote';
  static const String _webIndexKey = 'opennote_notes_index';
  static const String _webDocPrefix = 'opennote_doc_';

  // In-memory fallback for unit testing environments where SharedPreferences or path_provider may be mocked.
  final Map<String, Map<String, dynamic>> _memoryCache = {};

  /// Returns the persistent directory where notes are saved on native platforms.
  Future<Directory> _getNotesDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${docsDir.path}/notes');
    if (!await notesDir.exists()) {
      await notesDir.create(recursive: true);
    }
    return notesDir;
  }

  /// Loads all saved note documents from local storage, sorted by last updated descending.
  Future<List<NoteDocument>> loadAllNotes() async {
    if (kIsWeb) {
      return _loadAllNotesWeb();
    }
    return _loadAllNotesNative();
  }

  Future<List<NoteDocument>> _loadAllNotesNative() async {
    try {
      final notesDir = await _getNotesDirectory();
      if (!await notesDir.exists()) return [];

      final entities = notesDir.listSync();
      final List<NoteDocument> loaded = [];

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith(_noteFileExtension)) {
          try {
            final jsonString = await entity.readAsString();
            final map = jsonDecode(jsonString) as Map<String, dynamic>;
            final doc = NoteDocument.fromJson(map);
            if (!doc.isDeleted) {
              loaded.add(doc);
            }
          } catch (e) {
            debugPrint('Failed to load note at ${entity.path}: $e');
          }
        }
      }

      loaded.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return loaded;
    } catch (e) {
      debugPrint('Error listing notes directory: $e');
      // If path_provider throws (e.g. unit test runner without native channels), fallback to memory cache
      final memList = _memoryCache.values
          .map((m) => NoteDocument.fromJson(m))
          .where((d) => !d.isDeleted)
          .toList();
      memList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return memList;
    }
  }

  Future<List<NoteDocument>> _loadAllNotesWeb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_webIndexKey) ?? [];
      final List<NoteDocument> loaded = [];

      for (final id in ids) {
        final jsonStr = prefs.getString('$_webDocPrefix$id');
        if (jsonStr != null) {
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            final doc = NoteDocument.fromJson(map);
            if (!doc.isDeleted) {
              loaded.add(doc);
            }
          } catch (_) {}
        }
      }

      loaded.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return loaded;
    } catch (_) {
      final memList = _memoryCache.values
          .map((m) => NoteDocument.fromJson(m))
          .where((d) => !d.isDeleted)
          .toList();
      memList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return memList;
    }
  }

  /// Saves a note document to local storage by ID and JSON map.
  Future<void> saveNote(String noteId, Map<String, dynamic> data) async {
    _memoryCache[noteId] = data;

    if (kIsWeb) {
      await _saveNoteWeb(noteId, data);
      return;
    }
    await _saveNoteNative(noteId, data);
  }

  /// Convenience method to save a [NoteDocument] directly.
  Future<void> saveDocument(NoteDocument document) async {
    await saveNote(document.id, document.toJson());
  }

  Future<void> _saveNoteNative(String noteId, Map<String, dynamic> data) async {
    try {
      final notesDir = await _getNotesDirectory();
      final file = File('${notesDir.path}/$noteId$_noteFileExtension');
      final jsonString = jsonEncode(data);
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Native save note error (falling back to memory): $e');
    }
  }

  Future<void> _saveNoteWeb(String noteId, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_webIndexKey) ?? [];
      if (!ids.contains(noteId)) {
        ids.add(noteId);
        await prefs.setStringList(_webIndexKey, ids);
      }
      await prefs.setString('$_webDocPrefix$noteId', jsonEncode(data));
    } catch (_) {}
  }

  /// Loads a specific note document by ID.
  Future<Map<String, dynamic>?> loadNote(String noteId) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = prefs.getString('$_webDocPrefix$noteId');
        if (jsonStr != null) {
          return jsonDecode(jsonStr) as Map<String, dynamic>;
        }
      } catch (_) {}
      return _memoryCache[noteId];
    }

    try {
      final notesDir = await _getNotesDirectory();
      final file = File('${notesDir.path}/$noteId$_noteFileExtension');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
    } catch (_) {}

    return _memoryCache[noteId];
  }

  /// Loads a specific [NoteDocument] by ID.
  Future<NoteDocument?> loadDocument(String noteId) async {
    final map = await loadNote(noteId);
    if (map == null) return null;
    return NoteDocument.fromJson(map);
  }

  /// Deletes a note document from local storage.
  Future<void> deleteNote(String noteId) async {
    _memoryCache.remove(noteId);

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final ids = prefs.getStringList(_webIndexKey) ?? [];
        ids.remove(noteId);
        await prefs.setStringList(_webIndexKey, ids);
        await prefs.remove('$_webDocPrefix$noteId');
      } catch (_) {}
      return;
    }

    try {
      final notesDir = await _getNotesDirectory();
      final file = File('${notesDir.path}/$noteId$_noteFileExtension');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Exports an individual note to a user-chosen file path on their computer.
  Future<String?> exportNoteToFile(NoteDocument note) async {
    final sanitizedTitle = note.title.trim().replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_',
        );
    final fileName =
        '${sanitizedTitle.isEmpty ? 'Untitled' : sanitizedTitle}$_noteFileExtension';
    final jsonString = jsonEncode(note.toJson());

    final selectedPath = await FilePicker.saveFile(
      dialogTitle: 'Export Note As',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['opennote', 'json'],
      bytes: Uint8List.fromList(utf8.encode(jsonString)),
    );

    if (selectedPath != null && !kIsWeb) {
      final file = File(selectedPath);
      await file.writeAsString(jsonString);
    }
    return selectedPath;
  }

  /// Prompts user to pick an `.opennote` or `.json` file from their computer and parses it.
  Future<NoteDocument?> importNoteFromFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Open / Import Note File',
      type: FileType.custom,
      allowedExtensions: ['opennote', 'json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;

    String? jsonContent;
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      jsonContent = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      jsonContent = await File(file.path!).readAsString();
    }

    if (jsonContent == null) return null;
    final map = jsonDecode(jsonContent) as Map<String, dynamic>;
    return NoteDocument.fromJson(map);
  }
}
