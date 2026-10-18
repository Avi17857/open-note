import 'package:open_note/features/canvas/models/note_text_box.dart';
import 'package:open_note/features/canvas/models/stroke.dart';

class NotePage {
  final String id;
  final int pageNumber;
  List<Stroke> strokes;
  List<NoteTextBox> textBoxes;

  NotePage({
    required this.id,
    required this.pageNumber,
    List<Stroke>? strokes,
    List<NoteTextBox>? textBoxes,
  })  : strokes = strokes ?? [],
        textBoxes = textBoxes ?? [];

  NotePage clone() {
    return NotePage(
      id: id,
      pageNumber: pageNumber,
      strokes: List.from(strokes),
      textBoxes: textBoxes.map((b) => b.copyWith()).toList(),
    );
  }

  NotePage copyWith({
    String? id,
    int? pageNumber,
    List<Stroke>? strokes,
    List<NoteTextBox>? textBoxes,
  }) {
    return NotePage(
      id: id ?? this.id,
      pageNumber: pageNumber ?? this.pageNumber,
      strokes: strokes ?? List.from(this.strokes),
      textBoxes: textBoxes ?? this.textBoxes.map((b) => b.copyWith()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pageNumber': pageNumber,
      'strokes': strokes.map((s) => s.toJson()).toList(),
      'textBoxes': textBoxes.map((tb) => tb.toJson()).toList(),
    };
  }

  factory NotePage.fromJson(Map<String, dynamic> json) {
    final rawStrokes = (json['strokes'] as List<dynamic>?) ?? [];
    final rawTextBoxes = (json['textBoxes'] as List<dynamic>?) ?? [];
    return NotePage(
      id: json['id'] as String? ?? 'page_1',
      pageNumber: json['pageNumber'] as int? ?? 1,
      strokes: rawStrokes
          .map((s) => Stroke.fromJson(s as Map<String, dynamic>))
          .toList(),
      textBoxes: rawTextBoxes
          .map((tb) => NoteTextBox.fromJson(tb as Map<String, dynamic>))
          .toList(),
    );
  }
}
