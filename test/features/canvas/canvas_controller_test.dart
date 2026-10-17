import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/services/eraser_service.dart';

void main() {
  group('CanvasController Tests', () {
    late CanvasController controller;

    setUp(() {
      controller = CanvasController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial state is pen with default width and empty strokes', () {
      expect(controller.activeTool, ToolType.pen);
      expect(controller.strokes, isEmpty);
      expect(controller.strokeWidth, 3.5);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
    });

    test('Stroke width and color adjust correctly and persist per tool', () {
      // Pen settings
      controller.setStrokeWidth(6.0);
      controller.setColor(Colors.blue);
      expect(controller.strokeWidth, 6.0);
      expect(controller.activeColor, Colors.blue);

      // Switch to highlighter: should use highlighter defaults
      controller.setTool(ToolType.highlighter);
      expect(controller.strokeWidth, 22.0);
      expect(controller.activeColor, AppColors.highlighterPalette.first);

      // Change highlighter width
      controller.setStrokeWidth(30.0);
      expect(controller.strokeWidth, 30.0);

      // Switch back to pen: should restore pen settings
      controller.setTool(ToolType.pen);
      expect(controller.strokeWidth, 6.0);
      expect(controller.activeColor, Colors.blue);
    });

    test('Drawing a stroke adds to strokes and supports undo/redo', () {
      controller.onPointerDown(const Offset(10, 10));
      controller.onPointerMove(const Offset(20, 20));
      controller.onPointerUp(const Offset(30, 30));

      expect(controller.strokes.length, 1);
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.strokes, isEmpty);
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.strokes.length, 1);
    });

    test('Drawing with highlighter creates stroke with translucency', () {
      controller.setTool(ToolType.highlighter);
      controller.onPointerDown(const Offset(10, 10));
      controller.onPointerMove(const Offset(50, 10));
      controller.onPointerUp(const Offset(100, 10));

      expect(controller.strokes.length, 1);
      final stroke = controller.strokes.first;
      expect(stroke.toolType, ToolType.highlighter);
      expect(stroke.color.a, lessThan(1.0)); // Translucent alpha
    });

    test('Eraser hit-test removes intersected stroke', () {
      final stroke = Stroke(
        points: const [Offset(0, 0), Offset(100, 100)],
        strokeWidth: 4.0,
      );
      controller.loadStrokes([stroke]);
      expect(controller.strokes.length, 1);

      controller.setTool(ToolType.strokeEraser);
      // Tap near the middle of the line (50, 50)
      controller.onPointerDown(const Offset(51, 49));

      expect(controller.strokes, isEmpty);
    });
  });

  group('EraserService Tests', () {
    test('Broad phase rejects points far away', () {
      final stroke = Stroke(
        points: const [Offset(0, 0), Offset(10, 10)],
      );
      final hit = EraserService.hitTestStroke(
        stroke,
        const Offset(500, 500),
        10.0,
      );
      expect(hit, isFalse);
    });

    test('Narrow phase hits point on line segment', () {
      final stroke = Stroke(
        points: const [Offset(0, 0), Offset(0, 100)],
      );
      final hit = EraserService.hitTestStroke(
        stroke,
        const Offset(2, 50),
        5.0,
      );
      expect(hit, isTrue);
    });
  });
}
