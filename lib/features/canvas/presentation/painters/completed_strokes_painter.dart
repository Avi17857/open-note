import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';

class CompletedStrokesPainter extends CustomPainter {
  final List<Stroke> strokes;

  CompletedStrokesPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final isHighlighter = stroke.toolType == ToolType.highlighter;
      final paintColor = isHighlighter && stroke.color.a >= 1.0
          ? stroke.color.withValues(alpha: 0.38)
          : stroke.color;

      final paint = Paint()
        ..color = paintColor
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = isHighlighter ? StrokeCap.square : StrokeCap.round
        ..strokeJoin = isHighlighter ? StrokeJoin.bevel : StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(
          stroke.points.first,
          stroke.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CompletedStrokesPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
