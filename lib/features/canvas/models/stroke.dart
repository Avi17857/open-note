import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';

class Stroke {
  final List<StrokePoint> points;
  final Color color;
  final double strokeWidth;
  final ToolType toolType;
  Rect? _cachedBounds;

  Stroke({
    required this.points,
    this.color = Colors.black,
    this.strokeWidth = 3.5,
    this.toolType = ToolType.pen,
  });

  Rect get bounds {
    if (_cachedBounds != null) return _cachedBounds!;
    if (points.isEmpty) {
      _cachedBounds = Rect.zero;
      return _cachedBounds!;
    }

    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    // Expand bounding box by half stroke width
    final padding = strokeWidth / 2;
    _cachedBounds = Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
    return _cachedBounds!;
  }

  /// Simplifies points along the stroke to reduce memory and speed up rendering
  static List<StrokePoint> compressPoints(
    List<StrokePoint> rawPoints, {
    double minDistance = 1.0,
  }) {
    if (rawPoints.length < 3) return List.from(rawPoints);

    final List<StrokePoint> compressed = [rawPoints.first];
    StrokePoint lastAdded = rawPoints.first;

    for (int i = 1; i < rawPoints.length - 1; i++) {
      final current = rawPoints[i];
      final distance = (current - lastAdded).distance;
      if (distance >= minDistance) {
        compressed.add(current);
        lastAdded = current;
      }
    }

    compressed.add(rawPoints.last);
    return compressed;
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
      'toolType': toolType.name,
      'points': points.map((p) => p.toJson()).toList(),
    };
  }

  factory Stroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List<dynamic>?) ?? [];
    final points = rawPoints.map((item) {
      final map = item as Map<String, dynamic>;
      return StrokePoint.fromJson(map);
    }).toList();

    return Stroke(
      points: points,
      color: Color(json['color'] as int? ?? Colors.black.toARGB32()),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.5,
      toolType: ToolType.values.firstWhere(
        (t) => t.name == json['toolType'],
        orElse: () => ToolType.pen,
      ),
    );
  }
}
