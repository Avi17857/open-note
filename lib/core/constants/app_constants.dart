import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const Size defaultPageSize = Size(600, 850);
  static const double defaultStrokeWidth = 3.5;
  static const double defaultEraserRadius = 14.0;
  static const double minScale = 0.5;
  static const double maxScale = 3.0;

  /// Multi-page layout metrics
  static const double pageHeaderHeight = 32.0;
  static const double pageGap = 28.0;

  /// Pitch (center-to-center / origin-to-origin vertical distance) between consecutive page canvases
  static double get pagePitch =>
      defaultPageSize.height + pageGap + pageHeaderHeight; // 910.0
}
