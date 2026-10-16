import 'package:flutter/material.dart';
import 'package:open_note/core/theme/app_colors.dart';

enum PageTemplate {
  blank,
  ruled,
  grid,
}

class PageBackgroundPainter extends CustomPainter {
  final PageTemplate template;
  final double lineSpacing;

  PageBackgroundPainter({
    this.template = PageTemplate.ruled,
    this.lineSpacing = 32.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (template == PageTemplate.blank) return;

    final linePaint = Paint()
      ..color = template == PageTemplate.ruled
          ? AppColors.ruledLine
          : AppColors.gridLine
      ..strokeWidth = 1.0;

    // Draw horizontal lines
    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Draw vertical lines if grid
    if (template == PageTemplate.grid) {
      for (double x = lineSpacing; x < size.width; x += lineSpacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PageBackgroundPainter oldDelegate) {
    return oldDelegate.template != template ||
        oldDelegate.lineSpacing != lineSpacing;
  }
}
