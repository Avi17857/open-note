import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/rich_text_span.dart';

/// An independent, movable, and resizable rich text block container on the canvas.
class NoteTextBox {
  final String id;
  Offset position;
  double width;
  double? height;
  String text;
  List<RichTextSpan> spans;

  NoteTextBox({
    required this.id,
    required this.position,
    this.width = 300.0,
    this.height,
    this.text = '',
    List<RichTextSpan>? spans,
  }) : spans = spans ?? [];

  /// Minimum width allowed when resizing
  static const double minWidth = 120.0;

  /// Approximate visual bounding box of the text container.
  Rect get bounds => Rect.fromLTWH(
        position.dx,
        position.dy,
        width,
        height ?? 44.0,
      );

  NoteTextBox copyWith({
    String? id,
    Offset? position,
    double? width,
    double? height,
    String? text,
    List<RichTextSpan>? spans,
  }) {
    return NoteTextBox(
      id: id ?? this.id,
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      text: text ?? this.text,
      spans: spans != null
          ? List.from(spans)
          : this.spans.map((s) => s.copyWith()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': position.dx,
      'y': position.dy,
      'width': width,
      if (height != null) 'height': height,
      'text': text,
      'spans': spans.map((s) => s.toJson()).toList(),
    };
  }

  factory NoteTextBox.fromJson(Map<String, dynamic> json) {
    final rawSpans = (json['spans'] as List<dynamic>?) ?? [];
    return NoteTextBox(
      id: json['id'] as String? ?? 'box_${DateTime.now().millisecondsSinceEpoch}',
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0.0,
        (json['y'] as num?)?.toDouble() ?? 0.0,
      ),
      width: (json['width'] as num?)?.toDouble() ?? 300.0,
      height: (json['height'] as num?)?.toDouble(),
      text: json['text'] as String? ?? '',
      spans: rawSpans
          .map((s) => RichTextSpan.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
