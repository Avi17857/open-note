import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/controllers/rich_text_editing_controller.dart';
import 'package:open_note/features/canvas/models/note_text_box.dart';
import 'package:open_note/features/canvas/models/rich_text_span.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/presentation/note_canvas.dart';
import 'package:open_note/features/canvas/presentation/widgets/text_box_widget.dart';

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
      canvasController.onPointerUp(const Offset(120, 200));
      expect(canvasController.textBoxes.length, 1);
      final createdBox = canvasController.textBoxes.first;
      expect(createdBox.position.dx, 120.0);
      expect(createdBox.position.dy, 200.0);
      expect(canvasController.activeTextBoxId, createdBox.id);

      // Tapping inside the existing box keeps it focused
      canvasController.onPointerDown(const Offset(130, 210));
      canvasController.onPointerUp(const Offset(130, 210));
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
      canvasController.onPointerUp(const Offset(100, 100));
      expect(canvasController.textBoxes.length, 1);
      final emptyBoxId = canvasController.textBoxes.first.id;

      // Click elsewhere to add a new box without typing in the first one
      canvasController.onPointerDown(const Offset(300, 300));
      canvasController.onPointerUp(const Offset(300, 300));
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

    test('CanvasController formatting methods apply to active rich text controller', () {
      final box = canvasController.addTextBox(const Offset(50, 50), text: 'Lecture Notes');
      final richCtrl = RichTextEditingController(text: box.text);
      canvasController.setActiveRichTextController(richCtrl);

      // A. When no text is selected: setting style sets typing style but does NOT alter existing text spans
      canvasController.setHeading(HeadingLevel.h1);
      expect(richCtrl.currentHeading, HeadingLevel.h1);
      expect(richCtrl.spans, isEmpty); // Existing text is untouched!

      canvasController.setTextColor(Colors.red);
      expect(richCtrl.currentTextColor, Colors.red);
      expect(richCtrl.spans, isEmpty); // Existing text is untouched!

      canvasController.setTextHighlight(Colors.yellow);
      expect(richCtrl.currentHighlightColor, Colors.yellow);
      expect(richCtrl.spans, isEmpty); // Existing text is untouched!

      canvasController.toggleBold();
      expect(richCtrl.isSelectionBold, isTrue);
      expect(richCtrl.spans, isEmpty); // Existing text is untouched!

      // B. When text IS selected: setting style applies to highlighted text
      richCtrl.selection = const TextSelection(baseOffset: 0, extentOffset: 7); // "Lecture"
      canvasController.setHeading(HeadingLevel.h2);
      canvasController.setTextColor(Colors.blue);
      expect(richCtrl.spans.isNotEmpty, isTrue);
      expect(richCtrl.spans.first.heading, HeadingLevel.h2);
      expect(richCtrl.spans.first.color, Colors.blue);
    });

    test('Attribute slicing fills gaps across multiple words', () {
      final richCtrl = RichTextEditingController(
        text: 'The quick brown fox',
        spans: [
          // "quick" (4..9) is bold
          const RichTextSpan(start: 4, end: 9, bold: true),
        ],
      );

      // Select entire text (0..19) and make italic
      richCtrl.selection = const TextSelection(baseOffset: 0, extentOffset: 19);
      richCtrl.toggleItalic();

      // All parts: [0, 4], [4, 9], [9, 19] should be italic!
      expect(richCtrl.spans.length, 3);
      expect(richCtrl.spans[0].italic, isTrue); // "The "
      expect(richCtrl.spans[1].italic, isTrue); // "quick"
      expect(richCtrl.spans[1].bold, isTrue);
      expect(richCtrl.spans[2].italic, isTrue); // " brown fox"
    });
  });

  group('NoteCanvas Text Box Pasteboard & Expansion Widget Tests', () {
    testWidgets('Text box can be dragged to pasteboard outside page and dragged back', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = CanvasController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCanvas(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Add a text box on the canvas page at (80, 100)
      controller.setTool(ToolType.text);
      final box = controller.addTextBox(const Offset(80, 100), text: 'Movable Pasteboard Note');
      await tester.pumpAndSettle();

      expect(find.byType(TextBoxWidget), findsOneWidget);

      // Drag the text box far out into the left pasteboard (x = -150)
      controller.updateTextBoxPosition(box.id, const Offset(-150, 100));
      await tester.pumpAndSettle();

      expect(box.position.dx, -150.0);

      // In the pasteboard, the full-height resize handle is interactive!
      final resizeHandle = find.byKey(const Key('text_box_resize_handle'));
      expect(resizeHandle, findsOneWidget);

      // Resize the box by dragging the resize handle
      final center = tester.getCenter(resizeHandle);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: center);
      await tester.pump();
      await gesture.down(center);
      await tester.pump();
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      await gesture.up();
      await gesture.removePointer();
      await tester.pumpAndSettle();

      expect(controller.textBoxes.first.width, greaterThanOrEqualTo(370.0));

      // Drag box back from pasteboard onto the page using the drag handle
      final dragHandle = find.byKey(const Key('text_box_drag_handle'));
      expect(dragHandle, findsOneWidget);
      final dragCenter = tester.getCenter(dragHandle);
      final moveGesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await moveGesture.addPointer(location: dragCenter);
      await tester.pump();
      await moveGesture.down(dragCenter);
      await tester.pump();
      await moveGesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await moveGesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await moveGesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await moveGesture.up();
      await moveGesture.removePointer();
      await tester.pumpAndSettle();

      expect(controller.textBoxes.first.position.dx, greaterThanOrEqualTo(0.0));
      expect(controller.textBoxes.length, 1);
    });

    testWidgets('Text box does not shift position or change text field position when focused vs unfocused', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = CanvasController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCanvas(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setTool(ToolType.text);
      final box = controller.addTextBox(const Offset(120, 150), text: 'Exact Alignment Note\nSecond line');
      await tester.pumpAndSettle();

      // Focused state
      expect(controller.activeTextBoxId, box.id);
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final focusedTopLeft = tester.getTopLeft(textFieldFinder);
      final focusedSize = tester.getSize(textFieldFinder);

      // Unfocus the text box
      controller.unfocusActiveTextBox();
      await tester.pumpAndSettle();

      expect(controller.activeTextBoxId, isNull);
      final unfocusedTopLeft = tester.getTopLeft(textFieldFinder);
      final unfocusedSize = tester.getSize(textFieldFinder);

      // Verify ZERO pixel shift or size change!
      expect(unfocusedTopLeft.dx, focusedTopLeft.dx);
      expect(unfocusedTopLeft.dy, focusedTopLeft.dy);
      expect(unfocusedSize.width, focusedSize.width);
      expect(unfocusedSize.height, focusedSize.height);
    });

    test('Typing after setting heading or color without selection applies style to newly typed text without modifying previous text', () {
      final richCtrl = RichTextEditingController(text: 'Normal text ');
      expect(richCtrl.spans, isEmpty);

      // Switch to Heading 1 without selecting anything (collapsed cursor at end)
      richCtrl.selection = const TextSelection.collapsed(offset: 12);
      richCtrl.setHeading(HeadingLevel.h1);

      // Existing text remains untouched!
      expect(richCtrl.spans, isEmpty);
      expect(richCtrl.currentHeading, HeadingLevel.h1);

      // Type "H1 Title"
      richCtrl.value = const TextEditingValue(
        text: 'Normal text H1 Title',
        selection: TextSelection.collapsed(offset: 20),
      );

      // Only the newly typed text (12..20) has HeadingLevel.h1!
      expect(richCtrl.spans.length, 1);
      expect(richCtrl.spans.first.start, 12);
      expect(richCtrl.spans.first.end, 20);
      expect(richCtrl.spans.first.heading, HeadingLevel.h1);
    });

    testWidgets('Text boxes are only selectable and focusable when in text tool mode', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = CanvasController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCanvas(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setTool(ToolType.text);
      final box = controller.addTextBox(const Offset(100, 100), text: 'Tool Exclusivity Note');
      await tester.pumpAndSettle();

      expect(controller.activeTextBoxId, box.id);
      expect(find.byKey(const Key('text_box_drag_handle')), findsOneWidget);

      // Switch to pen tool: text box must unfocus immediately and hide handles
      controller.setTool(ToolType.pen);
      await tester.pumpAndSettle();

      expect(controller.activeTextBoxId, isNull);
      expect(find.byKey(const Key('text_box_drag_handle')), findsNothing);

      // Tap over the text box in pen mode: should ink over the text box without focusing it
      final boxCenter = tester.getCenter(find.byType(TextField));
      await tester.tapAt(boxCenter);
      await tester.pumpAndSettle();

      expect(controller.activeTextBoxId, isNull);
      expect(controller.strokes.isNotEmpty, isTrue);

      // Switch to lasso tool: tapping text box should not focus it
      controller.setTool(ToolType.lasso);
      await tester.pumpAndSettle();

      await tester.tapAt(boxCenter);
      await tester.pumpAndSettle();

      expect(controller.activeTextBoxId, isNull);
      expect(find.byKey(const Key('text_box_drag_handle')), findsNothing);

      // Switch back to text tool: tapping selects/focuses the text box
      controller.setTool(ToolType.text);
      await tester.pumpAndSettle();

      await tester.tapAt(boxCenter);
      await tester.pumpAndSettle();

      expect(controller.activeTextBoxId, box.id);
      expect(find.byKey(const Key('text_box_drag_handle')), findsOneWidget);
    });

    testWidgets('Pinch to zoom in text mode does not spawn a text box or focus', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = CanvasController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCanvas(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setTool(ToolType.text);
      expect(controller.textBoxes, isEmpty);

      // Simulate 2-finger touch pinch-to-zoom
      final finger1 = await tester.createGesture(kind: PointerDeviceKind.touch);
      final finger2 = await tester.createGesture(kind: PointerDeviceKind.touch);

      // Finger 1 down
      await finger1.down(const Offset(400, 400));
      await tester.pump(const Duration(milliseconds: 20));

      // Finger 2 down (multi-touch pinch begins)
      await finger2.down(const Offset(600, 400));
      await tester.pump(const Duration(milliseconds: 20));

      // Both fingers move outward to pinch zoom
      await finger1.moveTo(const Offset(300, 400));
      await finger2.moveTo(const Offset(700, 400));
      await tester.pumpAndSettle();

      // Lift both fingers
      await finger1.up();
      await finger2.up();
      await tester.pumpAndSettle();

      // VERIFY: Absolutely NO text box was created and no active text box ID!
      expect(controller.textBoxes, isEmpty);
      expect(controller.activeTextBoxId, isNull);
    });
  });
}
