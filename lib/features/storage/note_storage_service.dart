import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class NoteStorageService {
  static const String _noteFileExtension = '.opennote';
  final Map<String, Map<String, dynamic>> _webMemoryCache = {};

  Future<Directory> _getNotesDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${docsDir.path}/notes');
    if (!await notesDir.exists()) {
      await notesDir.create(recursive: true);
    }
    return notesDir;
  }

  Future<void> saveNote(String noteId, Map<String, dynamic> data) async {
    if (kIsWeb) {
      _webMemoryCache[noteId] = data;
      return;
    }
    final notesDir = await _getNotesDirectory();
    final file = File('${notesDir.path}/$noteId$_noteFileExtension');
    final jsonString = jsonEncode(data);
    await file.writeAsString(jsonString);
  }

  Future<Map<String, dynamic>?> loadNote(String noteId) async {
    if (kIsWeb) {
      return _webMemoryCache[noteId];
    }
    try {
      final notesDir = await _getNotesDirectory();
      final file = File('${notesDir.path}/$noteId$_noteFileExtension');
      if (!await file.exists()) {
        return null;
      }
      final jsonString = await file.readAsString();
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteNote(String noteId) async {
    if (kIsWeb) {
      _webMemoryCache.remove(noteId);
      return;
    }
    final notesDir = await _getNotesDirectory();
    final file = File('${notesDir.path}/$noteId$_noteFileExtension');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
