import 'package:open_note/features/canvas/models/stroke.dart';

class NotePage {
  final String id;
  final int pageNumber;
  List<Stroke> strokes;

  NotePage({
    required this.id,
    required this.pageNumber,
    List<Stroke>? strokes,
  }) : strokes = strokes ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pageNumber': pageNumber,
      'strokes': strokes.map((s) => s.toJson()).toList(),
    };
  }

  factory NotePage.fromJson(Map<String, dynamic> json) {
    final rawStrokes = (json['strokes'] as List<dynamic>?) ?? [];
    return NotePage(
      id: json['id'] as String? ?? 'page_1',
      pageNumber: json['pageNumber'] as int? ?? 1,
      strokes: rawStrokes
          .map((s) => Stroke.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
