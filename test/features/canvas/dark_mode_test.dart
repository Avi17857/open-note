import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/rich_text_span.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/presentation/painters/completed_strokes_painter.dart';
import 'package:open_note/features/canvas/presentation/painters/page_background_painter.dart';
import 'package:open_note/features/canvas/presentation/note_canvas.dart';

void main() {
  group('Smart Dark Mode Unit & Inversion Tests', () {
    late CanvasController controller;

    setUp(() {
      controller = CanvasController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('CanvasController initializes with dark mode disabled', () {
      expect(controller.isDarkMode, isFalse);
    });

    test('toggleDarkMode and setDarkMode update state and notify listeners', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.toggleDarkMode();
      expect(controller.isDarkMode, isTrue);
      expect(notifyCount, equals(1));

      controller.toggleDarkMode();
      expect(controller.isDarkMode, isFalse);
      expect(notifyCount, equals(2));

      controller.setDarkMode(true);
      expect(controller.isDarkMode, isTrue);
      expect(notifyCount, equals(3));

      // Redundant set does not notify
      controller.setDarkMode(true);
      expect(notifyCount, equals(3));
    });

    test('isNearBlack accurately detects black and neutral dark grays', () {
      expect(CanvasController.isNearBlack(Colors.black), isTrue);
      expect(CanvasController.isNearBlack(const Color(0xFF000000)), isTrue);
      expect(CanvasController.isNearBlack(const Color(0xFF111111)), isTrue);
      expect(CanvasController.isNearBlack(const Color(0xFF222222)), isTrue);

      // Chromatic colors must NEVER be classified as near-black
      expect(CanvasController.isNearBlack(const Color(0xFF1976D2)), isFalse); // Blue
      expect(CanvasController.isNearBlack(const Color(0xFFD32F2F)), isFalse); // Red
      expect(CanvasController.isNearBlack(const Color(0xFF388E3C)), isFalse); // Green
      expect(CanvasController.isNearBlack(const Color(0xFF7B1FA2)), isFalse); // Purple
      expect(CanvasController.isNearBlack(const Color(0x66FFEB3B)), isFalse); // Highlighter
    });

    test('getDisplayStrokeColor dynamically inverts only near-black in dark mode', () {
      // Light Mode: Colors unchanged
      controller.setDarkMode(false);
      expect(controller.getDisplayStrokeColor(Colors.black), equals(Colors.black));
      expect(controller.getDisplayStrokeColor(Colors.blue), equals(Colors.blue));

      // Dark Mode: Near-black inverts to white, chromatic colors preserved
      controller.setDarkMode(true);
      expect(controller.getDisplayStrokeColor(Colors.black), equals(Colors.white));
      expect(controller.getDisplayStrokeColor(const Color(0xFF111111)), equals(Colors.white));
      expect(controller.getDisplayStrokeColor(Colors.blue), equals(Colors.blue));
      expect(controller.getDisplayStrokeColor(Colors.red), equals(Colors.red));
    });

    test('CompletedStrokesPainter shouldRepaint triggers when isDarkMode changes', () {
      final strokes = [
        Stroke(
          points: [
            const StrokePoint(10, 10),
            const StrokePoint(20, 20),
          ],
          color: Colors.black,
          strokeWidth: 3.0,
          toolType: ToolType.pen,
        ),
      ];

      final lightPainter = CompletedStrokesPainter(strokes, isDarkMode: false);
      final darkPainter = CompletedStrokesPainter(strokes, isDarkMode: true);

      expect(darkPainter.shouldRepaint(lightPainter), isTrue);
    });

    test('PageBackgroundPainter shouldRepaint triggers when isDarkMode changes', () {
      final lightPainter = PageBackgroundPainter(template: PageTemplate.ruled, isDarkMode: false);
      final darkPainter = PageBackgroundPainter(template: PageTemplate.ruled, isDarkMode: true);

      expect(darkPainter.shouldRepaint(lightPainter), isTrue);
    });

    test('RichTextSpan toTextStyle inverts near-black colors in dark mode', () {
      const spanDefault = RichTextSpan(start: 0, end: 5);
      const spanBlack = RichTextSpan(start: 0, end: 5, color: Colors.black);
      const spanBlue = RichTextSpan(start: 0, end: 5, color: Colors.blue);

      // Light mode
      final lightStyle = spanBlack.toTextStyle(isDarkMode: false);
      expect(lightStyle.color, equals(Colors.black));

      // Dark mode: black inverts to white, blue stays blue
      final darkStyle = spanBlack.toTextStyle(isDarkMode: true);
      expect(darkStyle.color, equals(Colors.white));

      final darkBlueStyle = spanBlue.toTextStyle(isDarkMode: true);
      expect(darkBlueStyle.color, equals(Colors.blue));

      // Default span (null color) inherits base style
      const baseDark = TextStyle(color: Colors.white);
      final darkDefaultStyle = spanDefault.toTextStyle(baseStyle: baseDark, isDarkMode: true);
      expect(darkDefaultStyle.color, equals(Colors.white));

      // Underline and strikethrough decorationColor verification
      const spanUnderline = RichTextSpan(start: 0, end: 5, underline: true);
      const spanStrike = RichTextSpan(start: 0, end: 5, strikethrough: true, color: Colors.blue);

      final lightUnderlineStyle = spanUnderline.toTextStyle(isDarkMode: false);
      expect(lightUnderlineStyle.decoration, equals(TextDecoration.underline));
      expect(lightUnderlineStyle.decorationColor, equals(Colors.black87));

      final darkUnderlineStyle = spanUnderline.toTextStyle(isDarkMode: true);
      expect(darkUnderlineStyle.decoration, equals(TextDecoration.underline));
      expect(darkUnderlineStyle.decorationColor, equals(Colors.white));

      final darkStrikeStyle = spanStrike.toTextStyle(isDarkMode: true);
      expect(darkStrikeStyle.decoration, equals(TextDecoration.lineThrough));
      expect(darkStrikeStyle.decorationColor, equals(Colors.blue));
    });

    testWidgets('NoteCanvas updates theme background when dark mode toggles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCanvas(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially in light mode
      expect(controller.isDarkMode, isFalse);

      // Toggle to dark mode
      controller.toggleDarkMode();
      await tester.pumpAndSettle();

      expect(controller.isDarkMode, isTrue);

      // Toggle back to light mode
      controller.toggleDarkMode();
      await tester.pumpAndSettle();

      expect(controller.isDarkMode, isFalse);
    });
  });
}
