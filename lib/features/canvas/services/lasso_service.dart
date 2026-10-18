import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/services/eraser_service.dart';

enum LassoHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  rotate,
  move,
  none,
}

/// Pure math and collision service for freeform lasso selection,
/// bounding box calculations, and transformation math.
class LassoService {
  const LassoService._();

  /// Standard ray-casting algorithm to test whether [point] is inside [polygon].
  static bool isPointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;
    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final pi = polygon[i];
      final pj = polygon[j];

      final intersect = ((pi.dy > point.dy) != (pj.dy > point.dy)) &&
          (point.dx <
              (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx);

      if (intersect) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Determines if 2D line segment [p1]-[p2] intersects line segment [p3]-[p4].
  static bool doSegmentsIntersect(
    Offset p1,
    Offset p2,
    Offset p3,
    Offset p4,
  ) {
    double ccw(Offset a, Offset b, Offset c) {
      return (c.dy - a.dy) * (b.dx - a.dx) - (b.dy - a.dy) * (c.dx - a.dx);
    }

    final d1 = ccw(p3, p4, p1);
    final d2 = ccw(p3, p4, p2);
    final d3 = ccw(p1, p2, p3);
    final d4 = ccw(p1, p2, p4);

    return (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)));
  }

  /// Computes the axis-aligned bounding box of a polygon of points.
  static Rect computePolygonBounds(List<Offset> polygon) {
    if (polygon.isEmpty) return Rect.zero;
    double minX = polygon.first.dx;
    double maxX = polygon.first.dx;
    double minY = polygon.first.dy;
    double maxY = polygon.first.dy;

    for (final p in polygon) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Determines whether [stroke] is enclosed by or intersects [polygon].
  static bool isStrokeSelected(
    Stroke stroke,
    List<Offset> polygon,
    Rect polygonBounds,
  ) {
    if (stroke.points.isEmpty || polygon.length < 3) return false;

    // 1. Broad Phase: Bounding box overlap
    if (!stroke.bounds.overlaps(polygonBounds)) {
      return false;
    }

    // 2. Narrow Phase: Any stroke point inside polygon
    for (final pt in stroke.points) {
      if (isPointInPolygon(pt, polygon)) {
        return true;
      }
    }

    // 3. Narrow Phase: Any stroke segment cuts across any polygon edge
    final polyLen = polygon.length;
    for (int i = 0; i < stroke.points.length - 1; i++) {
      final p1 = stroke.points[i];
      final p2 = stroke.points[i + 1];

      for (int j = 0; j < polyLen; j++) {
        final q1 = polygon[j];
        final q2 = polygon[(j + 1) % polyLen];

        if (doSegmentsIntersect(p1, p2, q1, q2)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Identifies all strokes in [strokes] enclosed by or intersecting [polygon].
  static List<Stroke> findSelectedStrokes(
    List<Stroke> strokes,
    List<Offset> polygon,
  ) {
    if (polygon.length < 3 || strokes.isEmpty) return [];
    final polyBounds = computePolygonBounds(polygon);

    final List<Stroke> selected = [];
    for (final stroke in strokes) {
      if (isStrokeSelected(stroke, polygon, polyBounds)) {
        selected.add(stroke);
      }
    }
    return selected;
  }

  /// Computes the union bounding box of [strokes] with optional padding.
  static Rect? computeSelectionBounds(
    Iterable<Stroke> strokes, {
    double padding = 8.0,
  }) {
    if (strokes.isEmpty) return null;

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final stroke in strokes) {
      final b = stroke.bounds;
      if (b.left < minX) minX = b.left;
      if (b.right > maxX) maxX = b.right;
      if (b.top < minY) minY = b.top;
      if (b.bottom > maxY) maxY = b.bottom;
    }

    if (minX.isInfinite) return null;

    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  /// Translates [strokes] by [delta].
  static List<Stroke> translateStrokes(List<Stroke> strokes, Offset delta) {
    return strokes.map((stroke) {
      final updatedPoints = stroke.points.map((p) {
        return p.copyWith(
          dx: p.dx + delta.dx,
          dy: p.dy + delta.dy,
        );
      }).toList();
      return stroke.copyWith(points: updatedPoints);
    }).toList();
  }

  /// Scales [strokes] from [initialBounds] to [targetBounds].
  static List<Stroke> scaleStrokes(
    List<Stroke> strokes,
    Rect initialBounds,
    Rect targetBounds,
  ) {
    final w0 = max(1.0, initialBounds.width);
    final h0 = max(1.0, initialBounds.height);
    final w1 = max(10.0, targetBounds.width);
    final h1 = max(10.0, targetBounds.height);

    return strokes.map((stroke) {
      final updatedPoints = stroke.points.map((p) {
        final relX = (p.dx - initialBounds.left) / w0;
        final relY = (p.dy - initialBounds.top) / h0;
        return p.copyWith(
          dx: targetBounds.left + (relX * w1),
          dy: targetBounds.top + (relY * h1),
        );
      }).toList();
      return stroke.copyWith(points: updatedPoints);
    }).toList();
  }

  /// Computes the position of the rotation handle extending from [bounds].
  /// If the selection is near the top edge of the page (bounds.top < 36),
  /// the stem flips below the selection so it is not clipped off-screen.
  static Offset getRotationHandlePosition(
    Rect bounds, {
    double stemLength = 28.0,
  }) {
    if (bounds.top < 36.0) {
      return Offset(bounds.center.dx, bounds.bottom + stemLength);
    }
    return Offset(bounds.center.dx, bounds.top - stemLength);
  }

  /// Rotates [strokes] around [pivot] by [radians].
  static List<Stroke> rotateStrokes(
    List<Stroke> strokes,
    Offset pivot,
    double radians,
  ) {
    if (radians == 0.0 || strokes.isEmpty) return strokes;

    final cosA = cos(radians);
    final sinA = sin(radians);

    return strokes.map((stroke) {
      final rotatedPoints = stroke.points.map((p) {
        final rx = p.dx - pivot.dx;
        final ry = p.dy - pivot.dy;
        return p.copyWith(
          dx: pivot.dx + (rx * cosA - ry * sinA),
          dy: pivot.dy + (rx * sinA + ry * cosA),
        );
      }).toList();
      return stroke.copyWith(points: rotatedPoints);
    }).toList();
  }

  /// Rotates [point] around [pivot] by [radians].
  static Offset rotatePoint(Offset point, Offset pivot, double radians) {
    if (radians == 0.0) return point;
    final cosA = cos(radians);
    final sinA = sin(radians);
    final rx = point.dx - pivot.dx;
    final ry = point.dy - pivot.dy;
    return Offset(
      pivot.dx + (rx * cosA - ry * sinA),
      pivot.dy + (rx * sinA + ry * cosA),
    );
  }

  /// Un-rotates [point] around [pivot] by [radians] (rotates by -radians).
  static Offset unrotatePoint(Offset point, Offset pivot, double radians) {
    return rotatePoint(point, pivot, -radians);
  }

  /// Computes the axis-aligned enclosing bounds of a [bounds] rectangle
  /// rotated by [radians] around its center (including the rotation knob).
  static Rect computeRotatedEnclosingBounds(Rect bounds, double radians) {
    if (radians == 0.0) return bounds;
    final center = bounds.center;
    final knobPos = getRotationHandlePosition(bounds);
    final corners = [
      rotatePoint(bounds.topLeft, center, radians),
      rotatePoint(bounds.topRight, center, radians),
      rotatePoint(bounds.bottomLeft, center, radians),
      rotatePoint(bounds.bottomRight, center, radians),
      rotatePoint(knobPos, center, radians),
    ];
    return computePolygonBounds(corners);
  }


  /// Tests which handle of [bounds] was hit by [pointer], if any.
  static LassoHandle hitTestHandle(
    Offset pointer,
    Rect bounds, {
    double handleRadius = 26.0,
  }) {
    // 1. Rotation knob extending from selection
    final rotateHandlePos = getRotationHandlePosition(bounds);
    if ((pointer - rotateHandlePos).distance <= handleRadius) {
      return LassoHandle.rotate;
    }

    final effectiveRadius = min(
      handleRadius,
      max(14.0, min(bounds.width, bounds.height) / 2.0),
    );

    if ((pointer - bounds.topLeft).distance <= effectiveRadius) {
      return LassoHandle.topLeft;
    }
    if ((pointer - bounds.topRight).distance <= effectiveRadius) {
      return LassoHandle.topRight;
    }
    if ((pointer - bounds.bottomLeft).distance <= effectiveRadius) {
      return LassoHandle.bottomLeft;
    }
    if ((pointer - bounds.bottomRight).distance <= effectiveRadius) {
      return LassoHandle.bottomRight;
    }
    // Generous touch target for moving selections (especially thin lines)
    final moveTarget = bounds.inflate(12.0);
    if (moveTarget.contains(pointer)) {
      return LassoHandle.move;
    }
    return LassoHandle.none;
  }

  /// Calculates the new bounding box when dragging [handle] by [delta].
  static Rect calculateTransformedBounds(
    Rect initial,
    LassoHandle handle,
    Offset delta, {
    double minSize = 20.0,
  }) {
    switch (handle) {
      case LassoHandle.bottomRight:
        final newRight = max(initial.left + minSize, initial.right + delta.dx);
        final newBottom = max(initial.top + minSize, initial.bottom + delta.dy);
        return Rect.fromLTRB(initial.left, initial.top, newRight, newBottom);

      case LassoHandle.bottomLeft:
        final newLeft = min(initial.right - minSize, initial.left + delta.dx);
        final newBottom = max(initial.top + minSize, initial.bottom + delta.dy);
        return Rect.fromLTRB(newLeft, initial.top, initial.right, newBottom);

      case LassoHandle.topRight:
        final newRight = max(initial.left + minSize, initial.right + delta.dx);
        final newTop = min(initial.bottom - minSize, initial.top + delta.dy);
        return Rect.fromLTRB(initial.left, newTop, newRight, initial.bottom);

      case LassoHandle.topLeft:
        final newLeft = min(initial.right - minSize, initial.left + delta.dx);
        final newTop = min(initial.bottom - minSize, initial.top + delta.dy);
        return Rect.fromLTRB(newLeft, newTop, initial.right, initial.bottom);

      case LassoHandle.move:
        return initial.shift(delta);

      case LassoHandle.rotate:
      case LassoHandle.none:
        return initial;
    }
  }

  /// Tests if [point] hits [stroke], either along its stroke path within [tolerance]
  /// or inside its enclosed boundary if the stroke forms a closed shape.
  static bool hitTestStrokePoint(
    Stroke stroke,
    Offset point, {
    double tolerance = 16.0,
  }) {
    if (stroke.points.isEmpty) return false;

    // 1. Broad-phase bounding box rejection
    final expanded = stroke.bounds.inflate(tolerance);
    if (!expanded.contains(point)) return false;

    // 2. Stroke path distance test
    final strokeRadius = (stroke.strokeWidth / 2.0) + tolerance;
    if (EraserService.hitTestStroke(stroke, point, strokeRadius)) {
      return true;
    }

    // 3. Closed shape interior test (e.g. hand-drawn circle or polygon)
    if (stroke.points.length >= 4) {
      final isClosed = (stroke.points.first - stroke.points.last).distance <=
          (stroke.strokeWidth + 24.0);
      if (isClosed && isPointInPolygon(point, stroke.points)) {
        return true;
      }
    }

    return false;
  }

  /// Identifies the topmost (frontmost/visible) stroke hit by [pointer].
  /// Strokes behind the topmost hit stroke are ignored.
  static Stroke? findTopmostStrokeAtPoint(
    List<Stroke> strokes,
    Offset pointer, {
    double tolerance = 16.0,
  }) {
    // Iterate in reverse (from newest on top to oldest behind)
    for (int i = strokes.length - 1; i >= 0; i--) {
      final stroke = strokes[i];
      if (hitTestStrokePoint(stroke, pointer, tolerance: tolerance)) {
        return stroke;
      }
    }
    return null;
  }

  /// Computes a smart non-overlapping offset for duplicated strokes.
  /// Adapts based on geometry (horizontal lines stack vertically,
  /// vertical lines stack horizontally, compact shapes offset neatly).
  static Offset computeDuplicateOffset(
    Rect bounds, {
    double pageWidth = 600.0,
    double pageHeight = 850.0,
  }) {
    final isHorizontal = bounds.width > 2.0 * bounds.height;
    final isVertical = bounds.height > 2.0 * bounds.width;

    if (isHorizontal) {
      // Horizontal or broken horizontal line: duplicate parallel below (or above if near bottom)
      final stepY = max(28.0, bounds.height + 16.0);
      if (bounds.bottom + stepY <= pageHeight - 30.0) {
        return Offset(0, stepY);
      } else {
        return Offset(0, -stepY);
      }
    }

    if (isVertical) {
      // Vertical line: duplicate parallel to the right (or left if near right margin)
      final stepX = max(28.0, bounds.width + 16.0);
      if (bounds.right + stepX <= pageWidth - 30.0) {
        return Offset(stepX, 0);
      } else {
        return Offset(-stepX, 0);
      }
    }

    // Compact shapes (icons, words, circles): try side-by-side
    if (bounds.width <= 140.0 && bounds.height <= 140.0) {
      final stepX = bounds.width + 16.0;
      if (bounds.right + stepX <= pageWidth - 30.0) {
        return Offset(stepX, 0);
      }
      final stepY = bounds.height + 16.0;
      if (bounds.bottom + stepY <= pageHeight - 40.0) {
        return Offset(0, stepY);
      }
    }

    // General shapes: clear predictable diagonal offset guaranteed inside page
    final dx = (bounds.right + 32.0 <= pageWidth - 20.0) ? 32.0 : -32.0;
    final dy = (bounds.bottom + 32.0 <= pageHeight - 40.0) ? 32.0 : -32.0;
    return Offset(dx, dy);
  }
}
