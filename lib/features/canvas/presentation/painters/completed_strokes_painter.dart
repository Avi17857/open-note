import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/services/stroke_renderer.dart';

enum StrokeLayer {
  highlightersOnly,
  pensOnly,
  all,
}

class CompletedStrokesPainter extends CustomPainter {
  final List<Stroke> strokes;
  final StrokeLayer layer;

  CompletedStrokesPainter(this.strokes, {this.layer = StrokeLayer.all});

  @override
  void paint(Canvas canvas, Size size) {
    if (layer == StrokeLayer.highlightersOnly) {
      for (final stroke in strokes) {
        if (stroke.toolType == ToolType.highlighter) {
          _drawStroke(canvas, stroke);
        }
      }
    } else if (layer == StrokeLayer.pensOnly) {
      for (final stroke in strokes) {
        if (stroke.toolType != ToolType.highlighter) {
          _drawStroke(canvas, stroke);
        }
      }
    } else {
      // Pass 1: Highlighters behind
      for (final stroke in strokes) {
        if (stroke.toolType == ToolType.highlighter) {
          _drawStroke(canvas, stroke);
        }
      }
      // Pass 2: Pens on top
      for (final stroke in strokes) {
        if (stroke.toolType != ToolType.highlighter) {
          _drawStroke(canvas, stroke);
        }
      }
    }
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    StrokeRenderer.drawStroke(
      canvas: canvas,
      points: stroke.points,
      color: stroke.color,
      strokeWidth: stroke.strokeWidth,
      toolType: stroke.toolType,
    );
  }

  @override
  bool shouldRepaint(covariant CompletedStrokesPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.strokes.length != strokes.length ||
        oldDelegate.layer != layer;
  }
}
