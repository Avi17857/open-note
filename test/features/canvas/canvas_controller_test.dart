import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    test('Initial state is pen with empty strokes', () {
      expect(controller.activeTool, ToolType.pen);
      expect(controller.strokes, isEmpty);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
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
