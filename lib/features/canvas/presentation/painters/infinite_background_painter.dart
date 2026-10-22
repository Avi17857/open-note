import 'package:flutter/material.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/presentation/painters/page_background_painter.dart';

/// Paints an unbounded paper background with seamless ruled or grid lines
/// covering the currently visible viewport scene bounds.
///
/// Efficiently computes the line indices covering [visibleBounds] to achieve
/// constant-time O(1) rendering at 60/120 FPS regardless of canvas zoom or pan depth.
class InfiniteBackgroundPainter extends CustomPainter {
  final PageTemplate template;
  final double lineSpacing;
  final bool isDarkMode;
  final Rect visibleBounds;

  InfiniteBackgroundPainter({
    this.template = PageTemplate.ruled,
    this.lineSpacing = 32.0,
    this.isDarkMode = false,
    required this.visibleBounds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw solid paper background fill
    final backgroundPaint = Paint()
      ..color = isDarkMode
          ? AppColors.canvasBackgroundDark
          : AppColors.canvasBackground;
    canvas.drawRect(
      visibleBounds.inflate(100.0),
      backgroundPaint,
    );

    if (template == PageTemplate.blank) return;

    final linePaint = Paint()
      ..color = isDarkMode
          ? (template == PageTemplate.ruled
              ? AppColors.ruledLineDark
              : AppColors.gridLineDark)
          : (template == PageTemplate.ruled
              ? AppColors.ruledLine
              : AppColors.gridLine)
      ..strokeWidth = 1.0;

    // Expand bounds slightly to prevent edge aliasing during pan/zoom
    final startY = ((visibleBounds.top - lineSpacing) / lineSpacing).floor() * lineSpacing;
    final endY = ((visibleBounds.bottom + lineSpacing) / lineSpacing).ceil() * lineSpacing;

    final startX = ((visibleBounds.left - lineSpacing) / lineSpacing).floor() * lineSpacing;
    final endX = ((visibleBounds.right + lineSpacing) / lineSpacing).ceil() * lineSpacing;

    final left = visibleBounds.left - 200.0;
    final right = visibleBounds.right + 200.0;
    final top = visibleBounds.top - 200.0;
    final bottom = visibleBounds.bottom + 200.0;

    // 2. Draw horizontal ruled lines
    for (double y = startY; y <= endY; y += lineSpacing) {
      canvas.drawLine(Offset(left, y), Offset(right, y), linePaint);
    }

    // 3. Draw vertical grid lines (if grid template)
    if (template == PageTemplate.grid) {
      for (double x = startX; x <= endX; x += lineSpacing) {
        canvas.drawLine(Offset(x, top), Offset(x, bottom), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant InfiniteBackgroundPainter oldDelegate) {
    return oldDelegate.template != template ||
        oldDelegate.lineSpacing != lineSpacing ||
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.visibleBounds != visibleBounds;
  }
}
