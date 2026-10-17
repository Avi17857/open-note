import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/services/stroke_renderer.dart';

class ActiveStrokePainter extends CustomPainter {
  final List<StrokePoint> points;
  final Color color;
  final double strokeWidth;
  final ToolType toolType;

  ActiveStrokePainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.toolType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    StrokeRenderer.drawStroke(
      canvas: canvas,
      points: points,
      color: color,
      strokeWidth: strokeWidth,
      toolType: toolType,
    );
  }

  @override
  bool shouldRepaint(covariant ActiveStrokePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.toolType != toolType;
  }
}
