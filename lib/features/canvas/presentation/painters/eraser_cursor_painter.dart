import 'package:flutter/material.dart';

class EraserCursorPainter extends CustomPainter {
  final Offset position;
  final double radius;
  final bool isAreaEraser;

  const EraserCursorPainter({
    required this.position,
    required this.radius,
    this.isAreaEraser = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Outer boundary ring
    final ringPaint = Paint()
      ..color = isAreaEraser
          ? const Color(0xB3FF9800) // Translucent amber for precision area eraser
          : const Color(0xB3F44336) // Translucent red for stroke eraser
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Soft translucent fill inside eraser radius
    final fillPaint = Paint()
      ..color = isAreaEraser
          ? const Color(0x1AFF9800)
          : const Color(0x1AF44336)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(position, radius, fillPaint);
    canvas.drawCircle(position, radius, ringPaint);

    // Center crosshair / dot
    final centerDotPaint = Paint()
      ..color = ringPaint.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 2.0, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant EraserCursorPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.radius != radius ||
        oldDelegate.isAreaEraser != isAreaEraser;
  }
}
