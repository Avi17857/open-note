import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';
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

    test('addCustomColor adds to customColors and updates activeColor', () {
      const customTeal = Color(0xFF009688);
      controller.addCustomColor(customTeal);

      expect(controller.customColors.contains(customTeal), isTrue);
      expect(controller.activeColor, customTeal);

      // Adding another color keeps most recent first
      const customPurple = Color(0xFF9C27B0);
      controller.addCustomColor(customPurple);
      expect(controller.customColors.first, customPurple);
      expect(controller.activeColor, customPurple);
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

    test('Drawing with fountain pen records pressure dynamics', () {
      controller.setTool(ToolType.fountainPen);
      controller.onPointerDown(const Offset(10, 10), pressure: 0.3);
      controller.onPointerMove(const Offset(20, 20), pressure: 0.9);
      controller.onPointerUp(const Offset(30, 30), pressure: 0.6);

      expect(controller.strokes.length, 1);
      final stroke = controller.strokes.first;
      expect(stroke.toolType, ToolType.fountainPen);
      expect(stroke.points.any((p) => p.pressure > 0.5), isTrue);
    });

    test('Palm rejection ignores touch events while stylus is active', () {
      // Stylus begins drawing
      controller.onPointerDown(
        const Offset(10, 10),
        kind: PointerDeviceKind.stylus,
      );
      expect(controller.isStylusActive, isTrue);
      expect(controller.isDrawing, isTrue);

      // Palm touches screen: should be rejected
      controller.onPointerDown(
        const Offset(200, 200),
        kind: PointerDeviceKind.touch,
      );
      // Drawing stroke should still be at original point, not jumped to palm
      expect(controller.currentStrokeNotifier.value.first.dx, 10.0);
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

    test('Holding stylus barrel button acts as stroke eraser without changing active pen', () {
      final stroke = Stroke(
        points: const [StrokePoint(0, 0), StrokePoint(100, 100)],
        strokeWidth: 4.0,
      );
      controller.loadStrokes([stroke]);
      expect(controller.strokes.length, 1);
      expect(controller.activeTool, ToolType.pen);

      // Press down near the line with S-Pen button held (kPrimaryStylusButton)
      controller.onPointerDown(
        const Offset(51, 49),
        kind: PointerDeviceKind.stylus,
        buttons: kPrimaryStylusButton,
      );

      // Stroke should be erased
      expect(controller.strokes, isEmpty);
      // Tool should STILL be Pen (not permanently switched to eraser!)
      expect(controller.activeTool, ToolType.pen);
    });

    test('Eraser hit-test removes intersected stroke', () {
      final stroke = Stroke(
        points: const [StrokePoint(0, 0), StrokePoint(100, 100)],
        strokeWidth: 4.0,
      );
      controller.loadStrokes([stroke]);
      expect(controller.strokes.length, 1);

      controller.setTool(ToolType.strokeEraser);
      // Tap near the middle of the line (50, 50)
      controller.onPointerDown(const Offset(51, 49));

      expect(controller.strokes, isEmpty);
    });

    test('Multi-touch gestures cancel in-progress drawing and prevent drawing', () {
      // Finger 1 touches down and starts drawing
      controller.onPointerDown(
        const Offset(10, 10),
        pointer: 1,
        kind: PointerDeviceKind.touch,
      );
      expect(controller.isDrawing, isTrue);
      expect(controller.currentStrokeNotifier.value.isNotEmpty, isTrue);

      // Finger 2 touches down (multi-touch pan / pinch)
      controller.onPointerDown(
        const Offset(50, 50),
        pointer: 2,
        kind: PointerDeviceKind.touch,
      );
      // Drawing should immediately be cancelled and cleared!
      expect(controller.isDrawing, isFalse);
      expect(controller.currentStrokeNotifier.value, isEmpty);
      expect(controller.isMultiTouch, isTrue);

      // Both fingers move (panning)
      controller.onPointerMove(
        const Offset(15, 15),
        pointer: 1,
        kind: PointerDeviceKind.touch,
      );
      controller.onPointerMove(
        const Offset(55, 55),
        pointer: 2,
        kind: PointerDeviceKind.touch,
      );
      expect(controller.currentStrokeNotifier.value, isEmpty);

      // Finger 1 lifts up
      controller.onPointerUp(
        const Offset(15, 15),
        pointer: 1,
        kind: PointerDeviceKind.touch,
      );
      expect(controller.strokes, isEmpty); // No stroke was committed

      // Finger 2 lifts up
      controller.onPointerUp(
        const Offset(55, 55),
        pointer: 2,
        kind: PointerDeviceKind.touch,
      );
      expect(controller.strokes, isEmpty);
      expect(controller.isMultiTouch, isFalse);

      // Next single-finger stroke works normally
      controller.onPointerDown(
        const Offset(10, 10),
        pointer: 3,
        kind: PointerDeviceKind.touch,
      );
      controller.onPointerMove(
        const Offset(20, 20),
        pointer: 3,
        kind: PointerDeviceKind.touch,
      );
      controller.onPointerUp(
        const Offset(30, 30),
        pointer: 3,
        kind: PointerDeviceKind.touch,
      );
      expect(controller.strokes.length, 1);
    });

    test('Multi-touch in eraser mode does not accidentally erase strokes', () {
      final stroke = Stroke(
        points: const [StrokePoint(0, 0), StrokePoint(100, 100)],
        strokeWidth: 4.0,
      );
      controller.loadStrokes([stroke]);
      controller.setTool(ToolType.strokeEraser);

      // Finger 1 touches down on top of the stroke
      controller.onPointerDown(
        const Offset(50, 50),
        pointer: 1,
        kind: PointerDeviceKind.touch,
      );
      // Stroke is NOT erased yet (deferred to avoid accidental erase before finger 2 lands)
      expect(controller.strokes.length, 1);

      // Finger 2 touches down (user is two-finger panning)
      controller.onPointerDown(
        const Offset(80, 80),
        pointer: 2,
        kind: PointerDeviceKind.touch,
      );
      // Both fingers move to pan
      controller.onPointerMove(
        const Offset(55, 55),
        pointer: 1,
        kind: PointerDeviceKind.touch,
      );
      controller.onPointerMove(
        const Offset(85, 85),
        pointer: 2,
        kind: PointerDeviceKind.touch,
      );
      controller.onPointerUp(
        const Offset(55, 55),
        pointer: 1,
        kind: PointerDeviceKind.touch,
      );
      controller.onPointerUp(
        const Offset(85, 85),
        pointer: 2,
        kind: PointerDeviceKind.touch,
      );

      // Stroke is still completely intact!
      expect(controller.strokes.length, 1);
    });

    test('Area eraser splits stroke in the middle and supports undo/redo', () {
      final stroke = Stroke(
        points: const [
          StrokePoint(0, 50),
          StrokePoint(50, 50),
          StrokePoint(100, 50),
        ],
        strokeWidth: 4.0,
      );
      controller.loadStrokes([stroke]);
      expect(controller.strokes.length, 1);

      controller.setTool(ToolType.areaEraser);
      controller.setEraserRadius(10.0);

      // Swipe area eraser across the middle at (50, 50)
      controller.onPointerDown(
        const Offset(50, 50),
        kind: PointerDeviceKind.stylus,
      );

      // The single stroke should be split into 2 surviving sub-strokes!
      expect(controller.strokes.length, 2);
      expect(controller.strokes.first.points.last.dx, lessThan(50.0));
      expect(controller.strokes.last.points.first.dx, greaterThan(50.0));

      // Undo restores the original single stroke
      controller.undo();
      expect(controller.strokes.length, 1);
      expect(controller.strokes.first.points.length, 3);

      // Redo splits it again
      controller.redo();
      expect(controller.strokes.length, 2);
    });

    test('Area eraser multi-point swipe creates only ONE undo history entry', () {
      final stroke = Stroke(
        points: const [
          StrokePoint(0, 50),
          StrokePoint(50, 50),
          StrokePoint(100, 50),
        ],
        strokeWidth: 4.0,
      );
      controller.loadStrokes([stroke], clearHistory: true);
      expect(controller.strokes.length, 1);
      expect(controller.canUndo, isFalse);

      controller.setTool(ToolType.areaEraser);
      controller.setEraserRadius(10.0);

      // Multi-point swipe across the stroke (simulating high sampling rate)
      controller.onPointerDown(const Offset(40, 50));
      controller.onPointerMove(const Offset(45, 50));
      controller.onPointerMove(const Offset(50, 50));
      controller.onPointerMove(const Offset(55, 50));
      controller.onPointerMove(const Offset(60, 50));
      controller.onPointerUp(const Offset(65, 50));

      // The line was split
      expect(controller.strokes.length, 2);
      expect(controller.canUndo, isTrue);

      // Single undo should completely revert the entire swipe gesture!
      controller.undo();

      expect(controller.strokes.length, 1);
      expect(controller.strokes.first.points.length, 3);
      // Ensure there are no leftover micro-undo steps
      expect(controller.canUndo, isFalse);
    });

    test('Stylus barrel button hold-to-erase commits single undo snapshot', () {
      final stroke = Stroke(
        points: const [StrokePoint(0, 0), StrokePoint(100, 100)],
        strokeWidth: 4.0,
      );
      controller.loadStrokes([stroke], clearHistory: true);
      expect(controller.strokes.length, 1);
      expect(controller.canUndo, isFalse);
      expect(controller.activeTool, ToolType.pen);

      // Drag across with barrel button pressed
      controller.onPointerDown(
        const Offset(10, 10),
        kind: PointerDeviceKind.stylus,
        buttons: kPrimaryStylusButton,
      );
      controller.onPointerMove(
        const Offset(50, 50),
        kind: PointerDeviceKind.stylus,
        buttons: kPrimaryStylusButton,
      );
      // Lift stylus where buttons may be 0
      controller.onPointerUp(
        const Offset(50, 50),
        kind: PointerDeviceKind.stylus,
        buttons: 0,
      );

      expect(controller.strokes, isEmpty);
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.strokes.length, 1);
      expect(controller.canUndo, isFalse);
    });
  });

  group('EraserService Tests', () {
    test('Broad phase rejects points far away', () {
      final stroke = Stroke(
        points: const [StrokePoint(0, 0), StrokePoint(10, 10)],
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
        points: const [StrokePoint(0, 0), StrokePoint(0, 100)],
      );
      final hit = EraserService.hitTestStroke(
        stroke,
        const Offset(2, 50),
        5.0,
      );
      expect(hit, isTrue);
    });

    test('sliceStroke splits a line into two pieces when erased in the middle', () {
      final stroke = Stroke(
        points: const [
          StrokePoint(0, 0),
          StrokePoint(100, 0),
        ],
      );

      // Erase at center (50, 0) with radius 10
      final fragments = EraserService.sliceStroke(
        stroke,
        const Offset(50, 0),
        10.0,
      );

      expect(fragments.length, 2);
      // Fragment 1: 0 to 40
      expect(fragments[0].points.first.dx, 0.0);
      expect(fragments[0].points.last.dx, closeTo(40.0, 0.01));

      // Fragment 2: 60 to 100
      expect(fragments[1].points.first.dx, closeTo(60.0, 0.01));
      expect(fragments[1].points.last.dx, 100.0);
    });

    test('sliceStroke clips the end of a line when touched', () {
      final stroke = Stroke(
        points: const [
          StrokePoint(0, 0),
          StrokePoint(100, 0),
        ],
      );

      // Erase at (95, 0) with radius 10 -> clips 85..100
      final fragments = EraserService.sliceStroke(
        stroke,
        const Offset(95, 0),
        10.0,
      );

      expect(fragments.length, 1);
      expect(fragments.first.points.first.dx, 0.0);
      expect(fragments.first.points.last.dx, closeTo(85.0, 0.01));
    });

    test('sliceStroke completely removes a stroke fully enclosed by eraser', () {
      final stroke = Stroke(
        points: const [
          StrokePoint(10, 10),
          StrokePoint(20, 20),
        ],
      );

      // Erase at (15, 15) with huge radius 50 -> fully erased
      final fragments = EraserService.sliceStroke(
        stroke,
        const Offset(15, 15),
        50.0,
      );

      expect(fragments, isEmpty);
    });

    test('sliceStroke leaves stroke untouched when missing', () {
      final stroke = Stroke(
        points: const [
          StrokePoint(0, 0),
          StrokePoint(100, 0),
        ],
      );

      final fragments = EraserService.sliceStroke(
        stroke,
        const Offset(50, 50),
        10.0,
      );

      expect(fragments.length, 1);
      expect(identical(fragments.first, stroke), isTrue);
    });
  });
}
