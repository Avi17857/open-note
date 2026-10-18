import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/controllers/rich_text_editing_controller.dart';
import 'package:open_note/features/canvas/models/note_text_box.dart';
import 'package:open_note/features/canvas/models/rich_text_span.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';

void main() {
  group('RichTextSpan & NoteTextBox Serialization', () {
    test('RichTextSpan serializes and deserializes correctly', () {
      final span = RichTextSpan(
        start: 5,
        end: 15,
        bold: true,
        italic: true,
        underline: true,
        strikethrough: false,
        fontSize: 18.0,
        color: const Color(0xFF1A237E),
        highlightColor: const Color(0xFFFFF59D),
        heading: HeadingLevel.h2,
      );

      final json = span.toJson();
      final restored = RichTextSpan.fromJson(json);

      expect(restored.start, span.start);
      expect(restored.end, span.end);
      expect(restored.bold, span.bold);
      expect(restored.italic, span.italic);
      expect(restored.underline, span.underline);
      expect(restored.strikethrough, span.strikethrough);
      expect(restored.fontSize, span.fontSize);
      expect(restored.color?.toARGB32(), span.color?.toARGB32());
      expect(restored.highlightColor?.toARGB32(), span.highlightColor?.toARGB32());
      expect(restored.heading, HeadingLevel.h2);
    });

    test('NoteTextBox serializes and deserializes correctly', () {
      final box = NoteTextBox(
        id: 'box_123',
        position: const Offset(80.0, 140.0),
        width: 350.0,
        height: 120.0,
        text: 'Cellular Respiration',
        spans: [
          const RichTextSpan(start: 0, end: 8, bold: true),
          const RichTextSpan(start: 9, end: 20, italic: true),
        ],
      );

      final json = box.toJson();
      final restored = NoteTextBox.fromJson(json);

      expect(restored.id, 'box_123');
      expect(restored.position.dx, 80.0);
      expect(restored.position.dy, 140.0);
      expect(restored.width, 350.0);
      expect(restored.height, 120.0);
      expect(restored.text, 'Cellular Respiration');
      expect(restored.spans.length, 2);
      expect(restored.spans.first.bold, isTrue);
      expect(restored.spans.last.italic, isTrue);
    });
  });

  group('RichTextEditingController Tests', () {
    testWidgets('Boundary slicing breaks overlapping spans into disjoint TextSpans',
        (WidgetTester tester) async {
      final controller = RichTextEditingController(
        text: 'Hello Wonderful World',
        spans: [
          // "Wonderful" (6..15) is bold
          const RichTextSpan(start: 6, end: 15, bold: true),
          // "World" (16..21) is italic
          const RichTextSpan(start: 16, end: 21, italic: true),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final textSpan = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                expect(textSpan.children, isNotNull);
                expect(textSpan.children!.length, greaterThanOrEqualTo(3));

                // Segment 0: "Hello "
                expect(textSpan.children![0].toPlainText(), 'Hello ');
                expect(textSpan.children![0].style?.fontWeight, isNot(FontWeight.bold));

                // Segment 1: "Wonderful" (bold)
                expect(textSpan.children![1].toPlainText(), 'Wonderful');
                expect(textSpan.children![1].style?.fontWeight, FontWeight.bold);

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });

    test('Typing in the middle expands active span', () {
      final controller = RichTextEditingController(
        text: 'Hello World',
        spans: [
          const RichTextSpan(start: 6, end: 11, bold: true), // "World"
        ],
      );

      // Insert "Big " inside "World" -> "Hello WBig orld"
      controller.value = const TextEditingValue(
        text: 'Hello WBig orld',
        selection: TextSelection.collapsed(offset: 11),
      );

      expect(controller.spans.length, 1);
      // Span expanded from 5 characters (6..11) to 9 characters (6..15)
      expect(controller.spans.first.start, 6);
      expect(controller.spans.first.end, 15);
      expect(controller.spans.first.bold, isTrue);
    });

    test('Deleting text contracts spans and removes fully deleted ones', () {
      final controller = RichTextEditingController(
        text: 'ABC DEF GHI',
        spans: [
          const RichTextSpan(start: 0, end: 3, bold: true), // ABC
          const RichTextSpan(start: 4, end: 7, italic: true), // DEF
          const RichTextSpan(start: 8, end: 11, underline: true), // GHI
        ],
      );

      // Delete " DEF" -> remaining text: "ABC GHI"
      controller.value = const TextEditingValue(
        text: 'ABC GHI',
        selection: TextSelection.collapsed(offset: 3),
      );

      expect(controller.spans.length, 2);
      // First span "ABC" remains 0..3
      expect(controller.spans[0].start, 0);
      expect(controller.spans[0].end, 3);
      expect(controller.spans[0].bold, isTrue);

      // Third span "GHI" shifted from 8..11 to 4..7
      expect(controller.spans[1].start, 4);
      expect(controller.spans[1].end, 7);
      expect(controller.spans[1].underline, isTrue);
    });

    test('Formatting action toggleBold and toggleItalic on text selection', () {
      final controller = RichTextEditingController(text: 'Science Note');

      // Select "Science" (0..7)
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 7);
      expect(controller.isSelectionBold, isFalse);

      // Make bold
      controller.toggleBold();
      expect(controller.isSelectionBold, isTrue);
      expect(controller.spans.first.bold, isTrue);
      expect(controller.spans.first.start, 0);
      expect(controller.spans.first.end, 7);

      // Toggle off
      controller.toggleBold();
      expect(controller.isSelectionBold, isFalse);
    });

    test('Heading level applies appropriate styles', () {
      final controller = RichTextEditingController(text: 'Title of Page\nBody paragraph');

      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 13);
      controller.setHeading(HeadingLevel.h1);

      expect(controller.currentHeading, HeadingLevel.h1);
      expect(controller.spans.first.heading, HeadingLevel.h1);
    });
  });

  group('CanvasController Text Box Integration Tests', () {
    late CanvasController canvasController;

    setUp(() {
      canvasController = CanvasController();
    });

    tearDown(() {
      canvasController.dispose();
    });

    test('addTextBox creates a new text box and supports undo/redo', () {
      final box = canvasController.addTextBox(
        const Offset(100, 150),
        text: 'Initial text',
        width: 320.0,
      );

      expect(canvasController.textBoxes.length, 1);
      expect(canvasController.textBoxes.first.id, box.id);
      expect(canvasController.textBoxes.first.position, const Offset(100, 150));
      expect(canvasController.activeTextBoxId, box.id);
      expect(canvasController.canUndo, isTrue);

      // Undo removes the added box
      canvasController.undo();
      expect(canvasController.textBoxes, isEmpty);
      expect(canvasController.activeTextBoxId, isNull);

      // Redo restores the box
      canvasController.redo();
      expect(canvasController.textBoxes.length, 1);
      expect(canvasController.textBoxes.first.id, box.id);
    });

    test('Tapping canvas with text tool creates new box on empty space and focuses it', () {
      canvasController.setTool(ToolType.text);

      canvasController.onPointerDown(const Offset(120, 200));
      expect(canvasController.textBoxes.length, 1);
      final createdBox = canvasController.textBoxes.first;
      expect(createdBox.position.dx, 120.0);
      expect(createdBox.position.dy, 200.0);
      expect(canvasController.activeTextBoxId, createdBox.id);

      // Tapping inside the existing box keeps it focused
      canvasController.onPointerDown(const Offset(130, 210));
      expect(canvasController.textBoxes.length, 1);
      expect(canvasController.activeTextBoxId, createdBox.id);
    });

    test('Switching to pen tool and tapping outside unfocuses active text box', () {
      final box = canvasController.addTextBox(const Offset(100, 100));
      expect(canvasController.activeTextBoxId, box.id);

      canvasController.setTool(ToolType.pen);
      // Tap far away at (400, 400) with pen
      canvasController.onPointerDown(const Offset(400, 400));
      expect(canvasController.activeTextBoxId, isNull);
    });

    test('deleteTextBox removes box and supports undo', () {
      final box = canvasController.addTextBox(const Offset(100, 100));
      expect(canvasController.textBoxes.length, 1);

      canvasController.deleteTextBox(box.id);
      expect(canvasController.textBoxes, isEmpty);
      expect(canvasController.activeTextBoxId, isNull);
      expect(canvasController.canUndo, isTrue);

      canvasController.undo();
      expect(canvasController.textBoxes.length, 1);
      expect(canvasController.textBoxes.first.id, box.id);
    });

    test('Empty text box is automatically removed when clicking off or switching away', () {
      canvasController.setTool(ToolType.text);
      canvasController.onPointerDown(const Offset(100, 100));
      expect(canvasController.textBoxes.length, 1);
      final emptyBoxId = canvasController.textBoxes.first.id;

      // Click elsewhere to add a new box without typing in the first one
      canvasController.onPointerDown(const Offset(300, 300));
      // First empty box should be gone, only the new box remains
      expect(canvasController.textBoxes.length, 1);
      expect(canvasController.textBoxes.first.id, isNot(equals(emptyBoxId)));

      // Switch to pen tool and click away
      canvasController.setTool(ToolType.pen);
      canvasController.onPointerDown(const Offset(500, 500));
      // Now that we clicked away, the second empty box should also be gone
      expect(canvasController.textBoxes, isEmpty);
      expect(canvasController.activeTextBoxId, isNull);
    });

    test('Non-empty text box is preserved when clicking off or switching tools', () {
      canvasController.setTool(ToolType.text);
      canvasController.addTextBox(const Offset(100, 100), text: 'Important Note');
      expect(canvasController.textBoxes.length, 1);

      // Deselect by switching tool and clicking away
      canvasController.setTool(ToolType.pen);
      canvasController.onPointerDown(const Offset(500, 500));
      expect(canvasController.activeTextBoxId, isNull);

      // Box is preserved because it has text!
      expect(canvasController.textBoxes.length, 1);
      expect(canvasController.textBoxes.first.text, 'Important Note');
    });
  });
}
