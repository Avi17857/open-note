import 'package:flutter/material.dart';

/// Paints the in-progress freeform lasso outline while the user draws around strokes.
class LassoPathPainter extends CustomPainter {
  final List<Offset> points;

  LassoPathPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // 1. Translucent fill
    final fillPaint = Paint()
      ..color = const Color(0x18007AFF)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 2. Crisp boundary stroke
    final strokePaint = Paint()
      ..color = const Color(0xFF007AFF)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant LassoPathPainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}
