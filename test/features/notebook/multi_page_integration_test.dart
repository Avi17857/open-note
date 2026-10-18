import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/notebook/controllers/notebook_controller.dart';
import 'package:open_note/features/notebook/models/note_document.dart';
import 'package:open_note/features/notebook/models/note_page.dart';

void main() {
  group('Multi-Page CanvasController & Text Box Isolation Tests', () {
    late CanvasController controller;

    setUp(() {
      controller = CanvasController();
    });

    test('Initial canvas controller has exactly 1 page', () {
      expect(controller.pages.length, equals(1));
      expect(controller.activePageIndex, equals(0));
      expect(controller.activePage.strokes, isEmpty);
      expect(controller.activePage.textBoxes, isEmpty);
    });

    test('Text box created on page 1 is strictly isolated to page 1', () {
      // 1. Create text box on Page 1 (index 0)
      controller.setTool(ToolType.text);
      controller.addTextBox(const Offset(100, 150), text: 'Page 1 Note');
      expect(controller.pages[0].textBoxes.length, equals(1));
      expect(controller.textBoxes.length, equals(1));

      // 2. Add Page 2
      final page2 = controller.addPage();
      expect(controller.pages.length, equals(2));
      expect(controller.activePageIndex, equals(1));
      expect(page2.textBoxes, isEmpty);
      expect(controller.textBoxes, isEmpty); // Active page (page 2) has no text boxes!

      // Verify Page 1 still holds its text box untouched
      expect(controller.pages[0].textBoxes.length, equals(1));

      // 3. Add text box on Page 2
      controller.addTextBox(const Offset(200, 300), text: 'Page 2 Note');
      expect(controller.pages[1].textBoxes.length, equals(1));
      expect(controller.textBoxes.length, equals(1));

      // Page 1 and Page 2 have separate, isolated text boxes
      expect(controller.pages[0].textBoxes.first.id,
          isNot(equals(controller.pages[1].textBoxes.first.id)));

      // 4. Switch back to Page 1
      controller.setActivePage(0);
      expect(controller.activePageIndex, equals(0));
      expect(controller.textBoxes.length, equals(1));
      expect(controller.textBoxes.first.position, equals(const Offset(100, 150)));
    });

    test('Strokes drawn on separate pages remain isolated', () {
      // Draw on page 1
      controller.setTool(ToolType.pen);
      controller.onPointerDown(const Offset(10, 10));
      controller.onPointerMove(const Offset(20, 20));
      controller.onPointerUp(const Offset(20, 20));
      expect(controller.pages[0].strokes.length, equals(1));

      // Add page 2
      controller.addPage();
      expect(controller.activePageIndex, equals(1));
      expect(controller.pages[1].strokes, isEmpty);

      // Draw on page 2
      controller.onPointerDown(const Offset(50, 50));
      controller.onPointerMove(const Offset(60, 60));
      controller.onPointerUp(const Offset(60, 60));
      expect(controller.pages[1].strokes.length, equals(1));

      // Page 0 still has only its 1 stroke
      expect(controller.pages[0].strokes.length, equals(1));
    });

    test('Multi-page undo and redo restores page count and active page index', () {
      expect(controller.pages.length, equals(1));

      controller.addPage();
      expect(controller.pages.length, equals(2));
      expect(controller.activePageIndex, equals(1));

      // Undo adding page
      controller.undo();
      expect(controller.pages.length, equals(1));
      expect(controller.activePageIndex, equals(0));

      // Redo adding page
      controller.redo();
      expect(controller.pages.length, equals(2));
      expect(controller.activePageIndex, equals(1));
    });

    test('Deleting a page re-indexes remaining pages and bounds activePageIndex', () {
      controller.addPage(); // Page 2
      controller.addPage(); // Page 3
      expect(controller.pages.length, equals(3));
      expect(controller.activePageIndex, equals(2));

      controller.deletePage(1); // Delete middle page
      expect(controller.pages.length, equals(2));
      expect(controller.pages[0].pageNumber, equals(1));
      expect(controller.pages[1].pageNumber, equals(2));

      // Active index should stay within bounds
      expect(controller.activePageIndex, equals(1));
    });
  });

  group('NotebookController Multi-Page Synchronization Tests', () {
    late CanvasController canvasController;
    late NotebookController notebookController;

    setUp(() {
      canvasController = CanvasController();
      notebookController =
          NotebookController(canvasController: canvasController);
    });

    tearDown(() {
      notebookController.dispose();
      canvasController.dispose();
    });

    test('NotebookController tracks page additions from CanvasController', () {
      expect(notebookController.currentNote.pages.length, equals(1));

      canvasController.addPage();
      expect(notebookController.currentNote.pages.length, equals(2));
      expect(notebookController.currentPageIndex, equals(1));
    });

    test('NotebookController addPage delegates to CanvasController', () {
      notebookController.addPage();
      expect(canvasController.pages.length, equals(2));
      expect(notebookController.currentNote.pages.length, equals(2));
    });

    test('Loading a note with multiple pages updates canvas controller', () {
      final multiPageDoc = NoteDocument(
        id: 'doc_123',
        title: 'Multi Page Note',
        pages: [
          NotePage(
            id: 'p1',
            pageNumber: 1,
            strokes: [
              Stroke(
                points: [const StrokePoint(10, 10)],
                color: const Color(0xFF000000),
                strokeWidth: 2.0,
                toolType: ToolType.pen,
              ),
            ],
          ),
          NotePage(
            id: 'p2',
            pageNumber: 2,
            strokes: [],
          ),
        ],
      );

      notebookController.setCurrentNote(multiPageDoc);
      expect(canvasController.pages.length, equals(2));
      expect(canvasController.pages[0].strokes.length, equals(1));
      expect(canvasController.pages[1].strokes, isEmpty);
    });
  });

  group('Cross-Page Selection & Dragging Tests', () {
    late CanvasController controller;

    setUp(() {
      controller = CanvasController();
      // Start with 2 pages
      controller.addPage();
      controller.setActivePage(0);
    });

    test('Dragging lasso-selected stroke from Page 0 to Page 1 transfers stroke with offset', () {
      // 1. Draw a stroke on Page 0 at (100, 100)
      controller.setTool(ToolType.pen);
      controller.onPointerDown(const Offset(100, 100));
      controller.onPointerMove(const Offset(120, 120));
      controller.onPointerUp(const Offset(120, 120));

      expect(controller.pages[0].strokes.length, equals(1));
      expect(controller.pages[1].strokes.length, equals(0));

      // 2. Select the stroke with single-tap in lasso mode
      controller.setTool(ToolType.lasso);
      controller.onPointerDown(const Offset(110, 110));
      controller.onPointerUp(const Offset(110, 110));
      expect(controller.hasSelection, isTrue);

      // 3. Move the selection down by 910px (the exact page pitch) onto Page 1
      controller.onPointerDown(const Offset(110, 110));
      controller.onPointerMove(const Offset(110, 1020)); // delta = +910
      controller.onPointerUp(const Offset(110, 1020));

      // Stroke should now be on Page 1, removed from Page 0!
      expect(controller.pages[0].strokes, isEmpty);
      expect(controller.pages[1].strokes.length, equals(1));
      expect(controller.activePageIndex, equals(1));
      expect(controller.hasSelection, isTrue);

      // Stroke point on Page 1 should be shifted: 100 + (910 - 910) = 100
      expect(controller.pages[1].strokes.first.points.first.dy, closeTo(100, 1.0));

      // 4. Undo restores stroke to Page 0
      controller.undo();
      expect(controller.pages[0].strokes.length, equals(1));
      expect(controller.pages[1].strokes, isEmpty);
      expect(controller.activePageIndex, equals(0));

      // 5. Redo moves stroke back to Page 1
      controller.redo();
      expect(controller.pages[0].strokes, isEmpty);
      expect(controller.pages[1].strokes.length, equals(1));
      expect(controller.activePageIndex, equals(1));
    });

    test('Dragging text box from Page 0 to Page 1 transfers text box and shifts position', () {
      // 1. Add text box on Page 0 at (50, 100)
      controller.setTool(ToolType.text);
      final box = controller.addTextBox(const Offset(50, 100), text: 'Movable Note');
      expect(controller.pages[0].textBoxes.length, equals(1));
      expect(controller.pages[1].textBoxes, isEmpty);

      // 2. Drag text box down into Page 1 coordinates (e.g. y = 1010)
      controller.beginTextBoxTransform();
      controller.updateTextBoxPosition(box.id, const Offset(50, 1010));
      controller.transferTextBoxIfNeeded(box.id);
      controller.commitTextBoxTransform();

      expect(controller.pages[0].textBoxes, isEmpty);
      expect(controller.pages[1].textBoxes.length, equals(1));
      expect(controller.activePageIndex, equals(1));
      expect(controller.pages[1].textBoxes.first.position.dy, closeTo(100, 1.0));

      // 3. Undo restores text box to Page 0
      controller.undo();
      expect(controller.pages[0].textBoxes.length, equals(1));
      expect(controller.pages[1].textBoxes, isEmpty);
      expect(controller.activePageIndex, equals(0));
    });

    test('Strokes and text boxes dragged into horizontal margins remain preserved', () {
      // Add text box in the right margin (x = 650 > 600)
      controller.setTool(ToolType.text);
      controller.addTextBox(const Offset(650, 100), text: 'Margin Note');
      expect(controller.pages[0].textBoxes.length, equals(1));
      expect(controller.pages[0].textBoxes.first.position.dx, equals(650));

      // Draw stroke in the left margin (x = -40)
      controller.setTool(ToolType.pen);
      controller.onPointerDown(const Offset(-40, 100));
      controller.onPointerMove(const Offset(-30, 120));
      controller.onPointerUp(const Offset(-30, 120));
      expect(controller.pages[0].strokes.length, equals(1));
      expect(controller.pages[0].strokes.first.points.first.dx, equals(-40));
    });

    test('Dragging lasso-selected stroke Page 0 -> Page 1 -> Page 0 round-trip restores to Page 0; deleting Page 1 does not affect Page 0', () {
      // 1. Draw a stroke on Page 0 at (100, 100)
      controller.setTool(ToolType.pen);
      controller.onPointerDown(const Offset(100, 100));
      controller.onPointerMove(const Offset(120, 120));
      controller.onPointerUp(const Offset(120, 120));

      expect(controller.pages[0].strokes.length, equals(1));
      expect(controller.pages[1].strokes.length, equals(0));

      // 2. Select the stroke with single-tap in lasso mode
      controller.setTool(ToolType.lasso);
      controller.onPointerDown(const Offset(110, 110));
      controller.onPointerUp(const Offset(110, 110));
      expect(controller.hasSelection, isTrue);

      // 3. Move selection down by 910px onto Page 1
      controller.onPointerDown(const Offset(110, 110));
      controller.onPointerMove(const Offset(110, 1020)); // delta = +910
      controller.onPointerUp(const Offset(110, 1020));

      expect(controller.pages[0].strokes, isEmpty);
      expect(controller.pages[1].strokes.length, equals(1));
      expect(controller.activePageIndex, equals(1));
      expect(controller.hasSelection, isTrue);

      // 4. Move selection BACK up from Page 1 to Page 0 (delta = -910)
      controller.onPointerDown(const Offset(110, 110));
      controller.onPointerMove(const Offset(110, -800)); // delta = -910
      controller.onPointerUp(const Offset(110, -800));

      // Stroke should now be BACK on Page 0, and Page 1 should be completely EMPTY
      expect(controller.pages[0].strokes.length, equals(1));
      expect(controller.pages[1].strokes, isEmpty);
      expect(controller.activePageIndex, equals(0));
      expect(controller.hasSelection, isTrue);
      expect(controller.pages[0].strokes.first.points.first.dy, closeTo(100, 1.0));

      // 5. Delete Page 2 (index 1)
      controller.deletePage(1);
      expect(controller.pages.length, equals(1));
      expect(controller.pages[0].strokes.length, equals(1)); // Page 0 still has the stroke intact!

      // 6. Stroke on Page 0 can be re-selected and deleted without being stuck
      controller.deselect();
      expect(controller.hasSelection, isFalse);

      controller.onPointerDown(const Offset(110, 110));
      controller.onPointerUp(const Offset(110, 110));
      expect(controller.hasSelection, isTrue);

      controller.deleteSelection();
      expect(controller.pages[0].strokes, isEmpty);
    });

    test('Dragging text box Page 0 -> Page 1 -> Page 0 round-trip restores to Page 0; deleting Page 1 preserves it', () {
      // 1. Add text box on Page 0
      controller.setTool(ToolType.text);
      final box = controller.addTextBox(const Offset(80, 120), text: 'Round Trip Note');
      expect(controller.pages[0].textBoxes.length, equals(1));
      expect(controller.pages[1].textBoxes, isEmpty);

      // 2. Drag text box down into Page 1 (y = 1030)
      controller.beginTextBoxTransform();
      controller.updateTextBoxPosition(box.id, const Offset(80, 1030));
      controller.transferTextBoxIfNeeded(box.id);
      controller.commitTextBoxTransform();

      expect(controller.pages[0].textBoxes, isEmpty);
      expect(controller.pages[1].textBoxes.length, equals(1));
      expect(controller.activePageIndex, equals(1));

      // 3. Drag text box BACK up to Page 0 (y = 120 on Page 1 is local, moving to -790 brings it back to 120 on Page 0)
      controller.beginTextBoxTransform();
      controller.updateTextBoxPosition(box.id, const Offset(80, -790));
      controller.transferTextBoxIfNeeded(box.id);
      controller.commitTextBoxTransform();

      expect(controller.pages[0].textBoxes.length, equals(1));
      expect(controller.pages[1].textBoxes, isEmpty);
      expect(controller.activePageIndex, equals(0));
      expect(controller.pages[0].textBoxes.first.position.dy, closeTo(120, 1.0));

      // 4. Delete Page 1
      controller.deletePage(1);
      expect(controller.pages.length, equals(1));
      expect(controller.pages[0].textBoxes.length, equals(1));
      expect(controller.pages[0].textBoxes.first.text, equals('Round Trip Note'));
    });
  });
}
