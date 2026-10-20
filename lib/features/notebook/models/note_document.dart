import 'package:open_note/features/notebook/models/note_page.dart';

class NoteDocument {
  final String id;
  String title;
  List<NotePage> pages;
  DateTime createdAt;
  DateTime updatedAt;
  int version;
  bool isDeleted;

  NoteDocument({
    required this.id,
    required this.title,
    List<NotePage>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
    this.isDeleted = false,
  })  : pages = pages ?? [NotePage(id: 'page_1', pageNumber: 1)],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  NoteDocument clone({String? newId}) {
    return NoteDocument(
      id: newId ?? id,
      title: title,
      pages: pages.map((p) => p.clone()).toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      version: version,
      isDeleted: isDeleted,
    );
  }

  NoteDocument copyWith({
    String? id,
    String? title,
    List<NotePage>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    bool? isDeleted,
  }) {
    return NoteDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      pages: pages ?? this.pages.map((p) => p.clone()).toList(),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'pages': pages.map((p) => p.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'version': version,
      'isDeleted': isDeleted,
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
      version: (json['version'] as num?)?.toInt() ?? 1,
      isDeleted: json['isDeleted'] == true,
    );
  }
}
