import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/presentation/widgets/drawing_toolbar.dart';
import 'package:open_note/features/canvas/presentation/widgets/tool_icon.dart';

void main() {
  group('ToolIcon & DrawingToolbar Dark Mode Revamp Tests', () {
    late CanvasController controller;

    setUp(() {
      controller = CanvasController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('ToolIcon renders EraserIconWidget for strokeEraser and areaEraser', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ToolIcon(tool: ToolType.strokeEraser, size: 24, isDarkMode: true),
                ToolIcon(tool: ToolType.areaEraser, size: 24, isDarkMode: true),
              ],
            ),
          ),
        ),
      );

      // Both erasers should render the custom EraserIconWidget
      expect(find.byType(EraserIconWidget), findsNWidgets(2));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ToolIcon renders standard rounded icons for drawing tools', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ToolIcon(tool: ToolType.pen, size: 20),
                ToolIcon(tool: ToolType.fountainPen, size: 20),
                ToolIcon(tool: ToolType.highlighter, size: 20),
                ToolIcon(tool: ToolType.text, size: 20),
                ToolIcon(tool: ToolType.lasso, size: 20),
                ToolIcon(tool: ToolType.pan, size: 20),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
      expect(find.byIcon(Icons.history_edu_rounded), findsOneWidget);
      expect(find.byIcon(Icons.highlight_rounded), findsOneWidget);
      expect(find.byIcon(Icons.text_fields_rounded), findsOneWidget);
      expect(find.byIcon(Icons.gesture_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pan_tool_outlined), findsOneWidget);
    });

    testWidgets('DrawingToolbar renders with dark theme and high contrast icons in dark mode', (tester) async {
      controller.setDarkMode(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrawingToolbar(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SegmentedButton exists with all 8 tools
      final segmentedButtonFinder = find.byType(SegmentedButton<ToolType>);
      expect(segmentedButtonFinder, findsOneWidget);

      // Verify erasers render custom EraserIconWidget
      expect(find.byType(EraserIconWidget), findsWidgets);

      // Verify Undo, Redo, and Clear buttons are present
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.redo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Verify Image menu button is present
      expect(find.byKey(const Key('insert_image_button')), findsOneWidget);

      // Switch to strokeEraser and verify eraser settings button shows with high contrast
      controller.setTool(ToolType.strokeEraser);
      await tester.pumpAndSettle();

      expect(find.text('14pt'), findsOneWidget); // default radius is 14.0
    });
  });
}
