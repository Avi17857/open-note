import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';
import 'package:open_note/features/canvas/services/lasso_service.dart';

void main() {
  group('LassoService Tests', () {
    final squarePolygon = [
      const Offset(10, 10),
      const Offset(100, 10),
      const Offset(100, 100),
      const Offset(10, 100),
    ];

    test('isPointInPolygon correctly identifies inside and outside points', () {
      expect(
        LassoService.isPointInPolygon(const Offset(50, 50), squarePolygon),
        isTrue,
      );
      expect(
        LassoService.isPointInPolygon(const Offset(5, 5), squarePolygon),
        isFalse,
      );
      expect(
        LassoService.isPointInPolygon(const Offset(150, 50), squarePolygon),
        isFalse,
      );
      expect(
        LassoService.isPointInPolygon(const Offset(50, 150), squarePolygon),
        isFalse,
      );
    });

    test('doSegmentsIntersect detects cross intersection', () {
      expect(
        LassoService.doSegmentsIntersect(
          const Offset(0, 0),
          const Offset(10, 10),
          const Offset(0, 10),
          const Offset(10, 0),
        ),
        isTrue,
      );

      expect(
        LassoService.doSegmentsIntersect(
          const Offset(0, 0),
          const Offset(10, 0),
          const Offset(0, 10),
          const Offset(10, 10),
        ),
        isFalse,
      );
    });

    test('findSelectedStrokes selects strokes fully enclosed by polygon', () {
      final insideStroke = Stroke(
        points: const [
          StrokePoint(30, 30),
          StrokePoint(70, 70),
        ],
      );
      final outsideStroke = Stroke(
        points: const [
          StrokePoint(200, 200),
          StrokePoint(250, 250),
        ],
      );

      final selected = LassoService.findSelectedStrokes(
        [insideStroke, outsideStroke],
        squarePolygon,
      );

      expect(selected.length, 1);
      expect(selected.first, insideStroke);
    });

    test('findSelectedStrokes selects strokes cutting across polygon edge', () {
      final crossingStroke = Stroke(
        points: const [
          StrokePoint(0, 50),
          StrokePoint(150, 50),
        ],
      );

      final selected = LassoService.findSelectedStrokes(
        [crossingStroke],
        squarePolygon,
      );

      expect(selected.length, 1);
    });

    test('computeSelectionBounds unions stroke bounds with padding', () {
      final stroke1 = Stroke(
        points: const [StrokePoint(10, 10), StrokePoint(50, 50)],
        strokeWidth: 2.0,
      );
      final stroke2 = Stroke(
        points: const [StrokePoint(60, 60), StrokePoint(100, 100)],
        strokeWidth: 2.0,
      );

      final bounds = LassoService.computeSelectionBounds(
        [stroke1, stroke2],
        padding: 5.0,
      );

      expect(bounds, isNotNull);
      expect(bounds!.left, lessThan(10.0));
      expect(bounds.right, greaterThan(100.0));
      expect(bounds.top, lessThan(10.0));
      expect(bounds.bottom, greaterThan(100.0));
    });

    test('translateStrokes offsets all points', () {
      final stroke = Stroke(
        points: const [StrokePoint(10, 20), StrokePoint(30, 40)],
      );

      final moved = LassoService.translateStrokes(
        [stroke],
        const Offset(15, -5),
      );

      expect(moved.first.points[0].dx, 25.0);
      expect(moved.first.points[0].dy, 15.0);
      expect(moved.first.points[1].dx, 45.0);
      expect(moved.first.points[1].dy, 35.0);
    });

    test('scaleStrokes scales points from initial to target bounds', () {
      const initial = Rect.fromLTWH(0, 0, 100, 100);
      const target = Rect.fromLTWH(0, 0, 200, 200);

      final stroke = Stroke(
        points: const [StrokePoint(50, 50)],
      );

      final scaled = LassoService.scaleStrokes([stroke], initial, target);
      expect(scaled.first.points.first.dx, 100.0);
      expect(scaled.first.points.first.dy, 100.0);
    });

    test('hitTestHandle identifies corners, inside, and outside', () {
      const bounds = Rect.fromLTWH(100, 100, 200, 200);

      expect(
        LassoService.hitTestHandle(const Offset(100, 100), bounds),
        LassoHandle.topLeft,
      );
      expect(
        LassoService.hitTestHandle(const Offset(300, 100), bounds),
        LassoHandle.topRight,
      );
      expect(
        LassoService.hitTestHandle(const Offset(100, 300), bounds),
        LassoHandle.bottomLeft,
      );
      expect(
        LassoService.hitTestHandle(const Offset(300, 300), bounds),
        LassoHandle.bottomRight,
      );
      expect(
        LassoService.hitTestHandle(const Offset(200, 200), bounds),
        LassoHandle.move,
      );
      expect(
        LassoService.hitTestHandle(const Offset(500, 500), bounds),
        LassoHandle.none,
      );
    });

    test('findTopmostStrokeAtPoint selects topmost visible stroke among overlapping strokes', () {
      final bottomStroke = Stroke(
        points: const [StrokePoint(50, 50), StrokePoint(150, 50)],
        strokeWidth: 6.0,
      );
      final topStroke = Stroke(
        points: const [StrokePoint(100, 20), StrokePoint(100, 120)],
        strokeWidth: 6.0,
      );

      final strokes = [bottomStroke, topStroke];

      // Tap on the intersection (100, 50): should select topStroke!
      final hitAtIntersection = LassoService.findTopmostStrokeAtPoint(
        strokes,
        const Offset(100, 50),
      );
      expect(hitAtIntersection, topStroke);

      // Tap on the exposed left wing of bottomStroke (60, 50): should select bottomStroke!
      final hitAtExposed = LassoService.findTopmostStrokeAtPoint(
        strokes,
        const Offset(60, 50),
      );
      expect(hitAtExposed, bottomStroke);

      // Tap away at (300, 300): returns null
      final hitMiss = LassoService.findTopmostStrokeAtPoint(
        strokes,
        const Offset(300, 300),
      );
      expect(hitMiss, isNull);
    });

    test('findTopmostStrokeAtPoint detects tap inside closed hand-drawn shape', () {
      final closedBox = Stroke(
        points: const [
          StrokePoint(100, 100),
          StrokePoint(200, 100),
          StrokePoint(200, 200),
          StrokePoint(100, 200),
          StrokePoint(102, 101), // Closed loop back near start
        ],
        strokeWidth: 4.0,
      );

      // Tap inside the center of the box at (150, 150)
      final hitInside = LassoService.findTopmostStrokeAtPoint(
        [closedBox],
        const Offset(150, 150),
      );
      expect(hitInside, closedBox);
    });

    test('computeDuplicateOffset produces smart non-overlapping placement for shapes and lines', () {
      // 1. Compact shape: places side-by-side
      const compactBounds = Rect.fromLTWH(50, 50, 100, 80);
      final sideBySide = LassoService.computeDuplicateOffset(
        compactBounds,
        pageWidth: 600,
        pageHeight: 850,
      );
      expect(sideBySide.dx, compactBounds.width + 16.0);
      expect(sideBySide.dy, 0.0);

      // 2. Compact shape near right edge: stacks below
      const rightEdgeBounds = Rect.fromLTWH(500, 50, 80, 80);
      final stackedBelow = LassoService.computeDuplicateOffset(
        rightEdgeBounds,
        pageWidth: 600,
        pageHeight: 850,
      );
      expect(stackedBelow.dx, 0.0);
      expect(stackedBelow.dy, rightEdgeBounds.height + 16.0);

      // 3. Horizontal line (or broken line): duplicates parallel below it
      const lineBounds = Rect.fromLTWH(50, 100, 300, 10);
      final lineOffset = LassoService.computeDuplicateOffset(
        lineBounds,
        pageWidth: 600,
        pageHeight: 850,
      );
      expect(lineOffset.dx, 0.0);
      expect(lineOffset.dy, greaterThanOrEqualTo(28.0));

      // 4. Vertical line: duplicates parallel to the right
      const vertBounds = Rect.fromLTWH(100, 50, 10, 300);
      final vertOffset = LassoService.computeDuplicateOffset(
        vertBounds,
        pageWidth: 600,
        pageHeight: 850,
      );
      expect(vertOffset.dx, greaterThanOrEqualTo(28.0));
      expect(vertOffset.dy, 0.0);
    });

    test('rotateStrokes correctly rotates stroke points around pivot', () {
      final stroke = Stroke(
        points: const [
          StrokePoint(100, 50),
          StrokePoint(100, 150),
        ],
        strokeWidth: 4.0,
      );

      // Rotate 90 degrees (pi / 2) clockwise around pivot (100, 100)
      // (100, 50) -> relative (0, -50) -> rotated (50, 0) -> (150, 100)
      // (100, 150) -> relative (0, 50) -> rotated (-50, 0) -> (50, 100)
      final rotated = LassoService.rotateStrokes(
        [stroke],
        const Offset(100, 100),
        pi / 2,
      );

      expect(rotated.length, 1);
      expect(rotated.first.points.first.dx, closeTo(150.0, 0.01));
      expect(rotated.first.points.first.dy, closeTo(100.0, 0.01));
      expect(rotated.first.points.last.dx, closeTo(50.0, 0.01));
      expect(rotated.first.points.last.dy, closeTo(100.0, 0.01));

      // Rotating by 0 radians returns the original list
      final unrotated = LassoService.rotateStrokes(
        [stroke],
        const Offset(100, 100),
        0.0,
      );
      expect(identical(unrotated, [stroke]), isFalse);
      expect(unrotated.first.points.first.dx, 100.0);
      expect(unrotated.first.points.first.dy, 50.0);
    });

    test('getRotationHandlePosition places stem above bounds center', () {
      const bounds = Rect.fromLTWH(100, 100, 200, 150);
      final handlePos = LassoService.getRotationHandlePosition(bounds, stemLength: 26.0);
      expect(handlePos.dx, 200.0); // Center X = 100 + 100
      expect(handlePos.dy, 100.0 - 26.0); // Top - stemLength = 74.0
    });

    test('hitTestHandle detects LassoHandle.rotate', () {
      const bounds = Rect.fromLTWH(100, 100, 200, 150);
      final rotatePos = LassoService.getRotationHandlePosition(bounds);

      // Hit directly on rotation knob
      final hit = LassoService.hitTestHandle(rotatePos, bounds);
      expect(hit, LassoHandle.rotate);

      // Hit within touch radius of rotation knob
      final hitNear = LassoService.hitTestHandle(rotatePos.translate(5, -5), bounds);
      expect(hitNear, LassoHandle.rotate);
    });

    test('calculateTransformedBounds preserves bounds on rotate handle', () {
      const initial = Rect.fromLTWH(50, 50, 100, 100);
      final result = LassoService.calculateTransformedBounds(
        initial,
        LassoHandle.rotate,
        const Offset(25, 25),
      );
      expect(result, initial);
    });
  });
}

