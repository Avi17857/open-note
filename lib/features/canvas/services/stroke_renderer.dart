import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';

class StrokeRenderer {
  StrokeRenderer._();

  static void drawStroke({
    required Canvas canvas,
    required List<StrokePoint> points,
    required Color color,
    required double strokeWidth,
    required ToolType toolType,
  }) {
    if (points.isEmpty) return;

    if (toolType == ToolType.fountainPen) {
      _drawFountainStroke(canvas, points, color, strokeWidth);
      return;
    }

    final isHighlighter = toolType == ToolType.highlighter;
    final paintColor = isHighlighter && color.a >= 1.0
        ? color.withValues(alpha: 0.38)
        : color;

    final paint = Paint()
      ..color = paintColor
      ..strokeWidth = strokeWidth
      ..strokeCap = isHighlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = isHighlighter ? StrokeJoin.bevel : StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      canvas.drawCircle(
        points.first,
        strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  static void _drawFountainStroke(
    Canvas canvas,
    List<StrokePoint> points,
    Color color,
    double baseWidth,
  ) {
    if (points.length == 1) {
      final r = baseWidth * (0.25 + 0.9 * points.first.pressure) / 2;
      canvas.drawCircle(
        points.first,
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      return;
    }

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final r1 = baseWidth * (0.25 + 0.9 * p1.pressure) / 2;
      final r2 = baseWidth * (0.25 + 0.9 * p2.pressure) / 2;

      final diff = p2 - p1;
      final dist = diff.distance;
      if (dist < 0.1) continue;

      final normal = Offset(-diff.dy / dist, diff.dx / dist);

      final p1a = p1 + normal * r1;
      final p1b = p1 - normal * r1;
      final p2a = p2 + normal * r2;
      final p2b = p2 - normal * r2;

      final path = Path()
        ..moveTo(p1a.dx, p1a.dy)
        ..lineTo(p2a.dx, p2a.dy)
        ..lineTo(p2b.dx, p2b.dy)
        ..lineTo(p1b.dx, p1b.dy)
        ..close();

      canvas.drawPath(path, fillPaint);
      canvas.drawCircle(p1, r1, fillPaint);
      canvas.drawCircle(p2, r2, fillPaint);
    }
  }
}
