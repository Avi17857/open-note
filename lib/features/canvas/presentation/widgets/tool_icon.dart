import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';

/// Renders a modern, recognizable tool icon inspired by OneNote and Samsung Notes.
///
/// For erasers, draws an unmistakable angled rubber block:
/// - Stroke Eraser: eraser block with an erased ink stroke gap.
/// - Area Eraser: eraser block with a precision circular radius target.
class ToolIcon extends StatelessWidget {
  final ToolType tool;
  final double size;
  final Color? color;
  final bool isSelected;
  final bool isDarkMode;

  const ToolIcon({
    super.key,
    required this.tool,
    this.size = 20,
    this.color,
    this.isSelected = false,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (isSelected
            ? Colors.white
            : (isDarkMode ? Colors.white70 : Colors.black87));

    if (tool.isEraser) {
      return EraserIconWidget(
        isStroke: tool == ToolType.strokeEraser,
        size: size,
        color: effectiveColor,
        isSelected: isSelected,
        isDarkMode: isDarkMode,
      );
    }

    return Icon(
      tool.icon,
      size: size,
      color: effectiveColor,
    );
  }
}

/// Custom-painted iconic eraser block (pink rubber tip + sleeve + stroke/target).
class EraserIconWidget extends StatelessWidget {
  final bool isStroke;
  final double size;
  final Color color;
  final bool isSelected;
  final bool isDarkMode;

  const EraserIconWidget({
    super.key,
    required this.isStroke,
    this.size = 20,
    required this.color,
    this.isSelected = false,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: EraserIconPainter(
          isStroke: isStroke,
          primaryColor: color,
          isSelected: isSelected,
          isDarkMode: isDarkMode,
        ),
      ),
    );
  }
}

class EraserIconPainter extends CustomPainter {
  final bool isStroke;
  final Color primaryColor;
  final bool isSelected;
  final bool isDarkMode;

  EraserIconPainter({
    required this.isStroke,
    required this.primaryColor,
    required this.isSelected,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Angled rubber eraser body
    canvas.save();
    canvas.translate(w * 0.46, h * 0.42);
    canvas.rotate(-0.55); // ~ -31 degrees

    final eraserW = w * 0.38;
    final eraserH = h * 0.60;
    final halfW = eraserW / 2;
    final halfH = eraserH / 2;

    final bodyRect = Rect.fromCenter(
      center: Offset.zero,
      width: eraserW,
      height: eraserH,
    );

    // Tip: pink rubber (bottom half)
    final tipRect = Rect.fromLTRB(-halfW, 0, halfW, halfH);
    final tipPaint = Paint()
      ..color = const Color(0xFFFF6584)
      ..style = PaintingStyle.fill;
    final tipRRect = RRect.fromRectAndCorners(
      tipRect,
      bottomLeft: Radius.circular(eraserW * 0.28),
      bottomRight: Radius.circular(eraserW * 0.28),
    );
    canvas.drawRRect(tipRRect, tipPaint);

    // Sleeve / top body: white/cream body (top half)
    final sleeveRect = Rect.fromLTRB(-halfW, -halfH, halfW, 0);
    final sleevePaint = Paint()
      ..color = isDarkMode ? const Color(0xFFE2E2EC) : const Color(0xFFF4F4FA)
      ..style = PaintingStyle.fill;
    final sleeveRRect = RRect.fromRectAndCorners(
      sleeveRect,
      topLeft: Radius.circular(eraserW * 0.28),
      topRight: Radius.circular(eraserW * 0.28),
    );
    canvas.drawRRect(sleeveRRect, sleevePaint);

    // Decorative band in the middle
    final bandPaint = Paint()
      ..color = const Color(0xFF3F51B5)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(-halfW, -halfH * 0.28, eraserW, halfH * 0.28),
      bandPaint,
    );

    // Eraser perimeter outline
    final outlinePaint = Paint()
      ..color = isSelected
          ? Colors.white
          : (isDarkMode ? Colors.white70 : const Color(0xFF2C2C34))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fullRRect = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(eraserW * 0.28),
    );
    canvas.drawRRect(fullRRect, outlinePaint);

    canvas.restore();

    // Secondary indicator to disambiguate Stroke vs Area
    if (isStroke) {
      // Stroke Eraser: Ink stroke with an erased cut gap
      final strokePaint = Paint()
        ..color = isSelected
            ? Colors.white
            : (isDarkMode ? const Color(0xFF80D8FF) : const Color(0xFF0091EA))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;

      // Left segment of stroke
      final p1 = Path()
        ..moveTo(w * 0.08, h * 0.88)
        ..quadraticBezierTo(w * 0.22, h * 0.94, w * 0.35, h * 0.88);
      canvas.drawPath(p1, strokePaint);

      // Wipe sparkles at cut
      final wipePaint = Paint()
        ..color = isSelected
            ? Colors.white70
            : (isDarkMode ? Colors.white60 : Colors.black54)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(w * 0.42, h * 0.84),
        Offset(w * 0.46, h * 0.92),
        wipePaint,
      );
      canvas.drawLine(
        Offset(w * 0.50, h * 0.84),
        Offset(w * 0.54, h * 0.92),
        wipePaint,
      );

      // Right segment of stroke
      final p2 = Path()
        ..moveTo(w * 0.62, h * 0.88)
        ..quadraticBezierTo(w * 0.78, h * 0.82, w * 0.92, h * 0.88);
      canvas.drawPath(p2, strokePaint);
    } else {
      // Area Eraser: Precision radius ring at the contact area
      final ringPaint = Paint()
        ..color = isSelected
            ? Colors.white
            : (isDarkMode ? const Color(0xFFFFB74D) : const Color(0xFFF57C00))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;

      final center = Offset(w * 0.74, h * 0.78);
      final radius = w * 0.18;
      canvas.drawCircle(center, radius, ringPaint);

      final dotPaint = Paint()
        ..color = ringPaint.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 1.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant EraserIconPainter oldDelegate) {
    return oldDelegate.isStroke != isStroke ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
