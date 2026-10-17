import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/stroke.dart';

enum LassoHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
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

  /// Tests which handle of [bounds] was hit by [pointer], if any.
  static LassoHandle hitTestHandle(
    Offset pointer,
    Rect bounds, {
    double handleRadius = 20.0,
  }) {
    final effectiveRadius = min(
      handleRadius,
      min(bounds.width, bounds.height) / 2.2,
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
    if (bounds.contains(pointer)) {
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

      case LassoHandle.none:
        return initial;
    }
  }
}
