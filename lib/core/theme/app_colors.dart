import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFC414E7);
  static const Color primaryDark = Color(0xFF8E09A8);
  static const Color primaryLight = Color(0xFFEA80FC);

  // Light Mode Canvas
  static const Color canvasBackground = Colors.white;
  static const Color canvasBorder = Color(0xFFE0E0E0);
  static const Color canvasShadow = Color(0x1F000000);
  static const Color pasteboardBackground = Color(0xFFF3F3F5);

  static const Color ruledLine = Color(0xFFE1F5FE);
  static const Color gridLine = Color(0xFFEEEEEE);

  // Dark Mode Canvas
  static const Color canvasBackgroundDark = Color(0xFF1E1E24);
  static const Color canvasBorderDark = Color(0xFF33333E);
  static const Color canvasShadowDark = Color(0x66000000);
  static const Color pasteboardBackgroundDark = Color(0xFF121215);

  static const Color ruledLineDark = Color(0xFF2C2C38);
  static const Color gridLineDark = Color(0xFF282834);
  static const Color toolbarDark = Color(0xFF22222A);

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
