import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/stroke.dart';

class EraserService {
  EraserService._();

  /// Tests if an eraser circle at [pointer] with [radius] intersects [stroke].
  static bool hitTestStroke(Stroke stroke, Offset pointer, double radius) {
    if (stroke.points.isEmpty) return false;

    // 1. Broad-phase rejection: check bounding box expanded by radius
    final expandedBounds = stroke.bounds.inflate(radius);
    if (!expandedBounds.contains(pointer)) {
      return false;
    }

    // 2. Single-point stroke check
    if (stroke.points.length == 1) {
      return (stroke.points.first - pointer).distance <= radius;
    }

    // 3. Narrow-phase: line segment collision test
    for (int i = 0; i < stroke.points.length - 1; i++) {
      final p1 = stroke.points[i];
      final p2 = stroke.points[i + 1];

      if (_distanceToSegment(pointer, p1, p2) <= radius) {
        return true;
      }
    }

    return false;
  }

  /// Calculates the shortest distance from point [p] to segment [v]-[w].
  static double _distanceToSegment(Offset p, Offset v, Offset w) {
    final l2 = (v.dx - w.dx) * (v.dx - w.dx) + (v.dy - w.dy) * (v.dy - w.dy);
    if (l2 == 0) return (p - v).distance;

    // Consider the line extending the segment, parameterized as v + t (w - v).
    // We find projection of point p onto the line.
    final t = math.max(
      0.0,
      math.min(
        1.0,
        ((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2,
      ),
    );

    final projection = Offset(
      v.dx + t * (w.dx - v.dx),
      v.dy + t * (w.dy - v.dy),
    );

    return (p - projection).distance;
  }
}
