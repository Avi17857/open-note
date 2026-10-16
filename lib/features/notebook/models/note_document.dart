import 'package:open_note/features/notebook/models/note_page.dart';

class NoteDocument {
  final String id;
  String title;
  List<NotePage> pages;
  DateTime createdAt;
  DateTime updatedAt;

  NoteDocument({
    required this.id,
    required this.title,
    List<NotePage>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : pages = pages ?? [NotePage(id: 'page_1', pageNumber: 1)],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'pages': pages.map((p) => p.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory NoteDocument.fromJson(Map<String, dynamic> json) {
    final rawPages = (json['pages'] as List<dynamic>?) ?? [];
    return NoteDocument(
      id: json['id'] as String? ?? 'default',
      title: json['title'] as String? ?? 'Untitled Note',
      pages: rawPages
          .map((p) => NotePage.fromJson(p as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }
}
