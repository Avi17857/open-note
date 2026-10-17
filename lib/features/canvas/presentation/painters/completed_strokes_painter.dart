import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/services/stroke_renderer.dart';

class CompletedStrokesPainter extends CustomPainter {
  final List<Stroke> strokes;

  CompletedStrokesPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      StrokeRenderer.drawStroke(
        canvas: canvas,
        points: stroke.points,
        color: stroke.color,
        strokeWidth: stroke.strokeWidth,
        toolType: stroke.toolType,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CompletedStrokesPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
