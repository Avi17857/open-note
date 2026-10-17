import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';

class ActiveStrokePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final ToolType toolType;

  ActiveStrokePainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.toolType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paintColor = toolType == ToolType.highlighter && color.a >= 1.0
        ? color.withValues(alpha: 0.38)
        : color;

    final paint = Paint()
      ..color = paintColor
      ..strokeWidth = strokeWidth
      ..strokeCap = toolType == ToolType.highlighter
          ? StrokeCap.square
          : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      canvas.drawCircle(
        points.first,
        strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ActiveStrokePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
