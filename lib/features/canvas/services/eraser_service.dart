import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';

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

  /// Slices [stroke] with an eraser circle at [center] of [radius].
  /// Returns a list of surviving [Stroke] fragments.
  /// If the stroke does not intersect the circle, returns `[stroke]`.
  /// If the stroke is completely erased, returns an empty list.
  static List<Stroke> sliceStroke(
    Stroke stroke,
    Offset center,
    double radius,
  ) {
    if (stroke.points.isEmpty) return [];

    // 1. Broad-phase bounding box check
    final expandedBounds = stroke.bounds.inflate(radius);
    if (!expandedBounds.contains(center)) {
      return [stroke];
    }

    // 2. Single-point stroke (dot) check
    if (stroke.points.length == 1) {
      if ((stroke.points.first - center).distance <= radius) {
        return [];
      } else {
        return [stroke];
      }
    }

    // 3. Narrow-phase segment-by-segment slicing
    final List<List<StrokePoint>> survivingRuns = [];
    List<StrokePoint> currentRun = [];

    final points = stroke.points;
    final r2 = radius * radius;

    bool isInside(Offset p) {
      final dx = p.dx - center.dx;
      final dy = p.dy - center.dy;
      return (dx * dx + dy * dy) <= r2;
    }

    // Process first point
    if (!isInside(points.first)) {
      currentRun.add(points.first);
    }

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final p1Inside = isInside(p1);
      final p2Inside = isInside(p2);

      final intersections =
          _findSegmentCircleIntersections(p1, p2, center, radius);

      if (!p1Inside && !p2Inside) {
        if (intersections.isEmpty) {
          currentRun.add(p2);
        } else if (intersections.length == 2) {
          // Piercing: exits outside -> enters circle -> exits circle -> outside
          final q1 = intersections[0];
          final q2 = intersections[1];

          currentRun.add(q1);
          if (currentRun.length > 1) {
            survivingRuns.add(currentRun);
          }

          currentRun = [q2, p2];
        } else {
          currentRun.add(p2);
        }
      } else if (!p1Inside && p2Inside) {
        // Entering circle
        if (intersections.isNotEmpty) {
          currentRun.add(intersections.first);
        }
        if (currentRun.length > 1) {
          survivingRuns.add(currentRun);
        }
        currentRun = [];
      } else if (p1Inside && !p2Inside) {
        // Exiting circle
        if (intersections.isNotEmpty) {
          currentRun = [intersections.last, p2];
        } else {
          currentRun = [p2];
        }
      } else {
        // Both inside circle: completely erased
      }
    }

    if (currentRun.length > 1) {
      survivingRuns.add(currentRun);
    }

    if (survivingRuns.isEmpty) {
      return [];
    }

    return survivingRuns
        .where((run) => run.isNotEmpty)
        .map(
          (run) => Stroke(
            points: Stroke.compressPoints(run),
            color: stroke.color,
            strokeWidth: stroke.strokeWidth,
            toolType: stroke.toolType,
          ),
        )
        .toList();
  }

  /// Calculates quadratic roots for segment P1->P2 intersecting circle at [center] with [radius].
  static List<StrokePoint> _findSegmentCircleIntersections(
    StrokePoint p1,
    StrokePoint p2,
    Offset center,
    double radius,
  ) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final fx = p1.dx - center.dx;
    final fy = p1.dy - center.dy;

    final a = dx * dx + dy * dy;
    if (a == 0) return [];

    final b = 2 * (fx * dx + fy * dy);
    final c = (fx * fx + fy * fy) - radius * radius;

    final discriminant = b * b - 4 * a * c;
    if (discriminant < 0) return [];

    final sqrtDisc = math.sqrt(discriminant);
    final t1 = (-b - sqrtDisc) / (2 * a);
    final t2 = (-b + sqrtDisc) / (2 * a);

    final List<StrokePoint> results = [];
    final sortedT = [t1, t2]..sort();

    for (final t in sortedT) {
      if (t >= 0.0 && t <= 1.0) {
        final qx = p1.dx + t * dx;
        final qy = p1.dy + t * dy;
        final qPressure = p1.pressure + t * (p2.pressure - p1.pressure);
        results.add(StrokePoint(qx, qy, pressure: qPressure));
      }
    }

    return results;
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
