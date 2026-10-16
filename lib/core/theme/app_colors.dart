import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFC414E7);
  static const Color primaryDark = Color(0xFF8E09A8);
  static const Color primaryLight = Color(0xFFEA80FC);

  static const Color canvasBackground = Colors.white;
  static const Color canvasBorder = Color(0xFFE0E0E0);
  static const Color canvasShadow = Color(0x1F000000);

  static const Color ruledLine = Color(0xFFE1F5FE);
  static const Color gridLine = Color(0xFFEEEEEE);

  // Pen presets
  static const List<Color> penPalette = [
    Colors.black,
    Color(0xFF1976D2), // Blue
    Color(0xFFD32F2F), // Red
    Color(0xFF388E3C), // Green
    Color(0xFF7B1FA2), // Purple
    Color(0xFFF57C00), // Orange
  ];

  // Highlighter presets (translucent)
  static const List<Color> highlighterPalette = [
    Color(0x66FFEB3B), // Yellow
    Color(0x664CAF50), // Green
    Color(0x6603A9F4), // Light Blue
    Color(0x66E91E63), // Pink
    Color(0x66FF9800), // Orange
  ];
}
