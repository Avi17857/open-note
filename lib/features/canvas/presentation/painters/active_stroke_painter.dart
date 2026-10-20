import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/services/stroke_renderer.dart';

class ActiveStrokePainter extends CustomPainter {
  final List<StrokePoint> points;
  final Color color;
  final double strokeWidth;
  final ToolType toolType;
  final bool isDarkMode;

  ActiveStrokePainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.toolType,
    this.isDarkMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final effectiveColor =
        isDarkMode && CanvasController.isNearBlack(color)
            ? Colors.white
            : color;

    StrokeRenderer.drawStroke(
      canvas: canvas,
      points: points,
      color: effectiveColor,
      strokeWidth: strokeWidth,
      toolType: toolType,
    );
  }

  @override
  bool shouldRepaint(covariant ActiveStrokePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.toolType != toolType ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
