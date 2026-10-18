import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/services/lasso_service.dart';

/// Paints the dashed bounding box and 4 corner resize handles around selected strokes.
class SelectionPainter extends CustomPainter {
  final Rect bounds;
  final double rotationAngle;

  const SelectionPainter({
    required this.bounds,
    this.rotationAngle = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bounds.isEmpty) return;

    canvas.save();
    if (rotationAngle != 0.0) {
      final center = bounds.center;
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotationAngle);
      canvas.translate(-center.dx, -center.dy);
    }

    // 1. Subtle background highlight over selected strokes
    final fillPaint = Paint()
      ..color = const Color(0x0C007AFF)
      ..style = PaintingStyle.fill;
    canvas.drawRect(bounds, fillPaint);

    // 2. Dashed bounding border
    final borderPaint = Paint()
      ..color = const Color(0xFF007AFF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    _drawDashedRect(canvas, bounds, borderPaint, dashLength: 6.0, gap: 4.0);

    // 3. Four corner resize handles
    _drawHandle(canvas, bounds.topLeft);
    _drawHandle(canvas, bounds.topRight);
    _drawHandle(canvas, bounds.bottomLeft);
    _drawHandle(canvas, bounds.bottomRight);

    // 4. Rotation stem and handle
    _drawRotationHandle(canvas, bounds, borderPaint);

    canvas.restore();
  }

  void _drawRotationHandle(Canvas canvas, Rect bounds, Paint borderPaint) {
    final handlePos = LassoService.getRotationHandlePosition(bounds);
    final anchor = bounds.top < 36.0 ? bounds.bottomCenter : bounds.topCenter;

    // Stem line connecting box to rotation knob
    final stemPaint = Paint()
      ..color = const Color(0xFF007AFF)
      ..strokeWidth = 1.5;
    canvas.drawLine(anchor, handlePos, stemPaint);

    // Subtle drop shadow
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(handlePos.translate(0, 1.5), 10.0, shadowPaint);

    // White circular fill
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(handlePos, 10.0, fillPaint);

    // Blue ring border
    canvas.drawCircle(handlePos, 10.0, borderPaint);

    // Curving rotate arrow glyph
    final arcPaint = Paint()
      ..color = const Color(0xFF007AFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: handlePos, radius: 5.5),
      -0.6,
      4.4,
      false,
      arcPaint,
    );
  }

  void _drawHandle(Canvas canvas, Offset center) {
    // Subtle shadow
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawCircle(center.translate(0, 1), 7.5, shadowPaint);

    // White fill
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7.5, fillPaint);

    // Blue ring border
    final borderPaint = Paint()
      ..color = const Color(0xFF007AFF)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 7.5, borderPaint);
  }

  void _drawDashedRect(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    required double dashLength,
    required double gap,
  }) {
    // Top edge
    _drawDashedLine(
      canvas,
      rect.topLeft,
      rect.topRight,
      paint,
      dashLength,
      gap,
    );
    // Right edge
    _drawDashedLine(
      canvas,
      rect.topRight,
      rect.bottomRight,
      paint,
      dashLength,
      gap,
    );
    // Bottom edge
    _drawDashedLine(
      canvas,
      rect.bottomRight,
      rect.bottomLeft,
      paint,
      dashLength,
      gap,
    );
    // Left edge
    _drawDashedLine(
      canvas,
      rect.bottomLeft,
      rect.topLeft,
      paint,
      dashLength,
      gap,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashLength,
    double gap,
  ) {
    final distance = (end - start).distance;
    final direction = (end - start) / distance;
    double current = 0.0;

    while (current < distance) {
      final len = (current + dashLength > distance)
          ? (distance - current)
          : dashLength;
      canvas.drawLine(
        start + direction * current,
        start + direction * (current + len),
        paint,
      );
      current += dashLength + gap;
    }
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) {
    return oldDelegate.bounds != bounds ||
        oldDelegate.rotationAngle != rotationAngle;
  }
}

