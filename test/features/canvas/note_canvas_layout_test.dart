import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/presentation/note_canvas.dart';

void main() {
  testWidgets('NoteCanvas does not overflow in viewport smaller than page height',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('NoteCanvas handles multiple pages without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = CanvasController();
    controller.addPage();
    controller.addPage(); // 3 pages total
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCanvas(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('NoteCanvas handles gestures far outside pages into pasteboard without dead zones',
      (tester) async {
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

    // 1. Draw a stroke that extends far into the left pasteboard (x = 50 on screen which is negative in scene)
    final gesture = await tester.startGesture(const Offset(50, 200));
    await gesture.moveBy(const Offset(30, 30));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.pages[0].strokes.length, equals(1));
    expect(controller.pages[0].strokes.first.points.isNotEmpty, isTrue);

    // 2. Select the stroke with lasso
    controller.setTool(ToolType.lasso);
    final strokePt = controller.pages[0].strokes.first.points.first;
    // Single tap on stroke
    controller.onPointerDown(Offset(strokePt.dx, strokePt.dy));
    controller.onPointerUp(Offset(strokePt.dx, strokePt.dy));
    await tester.pumpAndSettle();

    expect(controller.hasSelection, isTrue);
  });
}
