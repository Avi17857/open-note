import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('Mouse scroll without Ctrl only scrolls and does not zoom', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
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

    final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final initialMatrix = iv.transformationController!.value.clone();
    final initialScale = initialMatrix.getMaxScaleOnAxis();

    // Send mouse scroll event downwards (scrollDelta.dy = 100)
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(500, 400),
        scrollDelta: Offset(0, 100),
      ),
    );
    await tester.pumpAndSettle();

    final afterMatrix = iv.transformationController!.value.clone();
    final afterScale = afterMatrix.getMaxScaleOnAxis();

    // Scale must remain exactly the same (no zoom!)
    expect(afterScale, equals(initialScale));
    // Y translation must have scrolled by -100
    expect(afterMatrix.storage[13], equals(initialMatrix.storage[13] - 100));
  });

  testWidgets('Mouse scroll with Ctrl zooms in and out', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
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

    final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final initialScale = iv.transformationController!.value.getMaxScaleOnAxis();

    // Press Control key down
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    // Scroll up with Ctrl (scrollDelta.dy = -100) -> Zoom In
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(500, 400),
        scrollDelta: Offset(0, -100),
      ),
    );
    await tester.pumpAndSettle();

    final zoomedInScale = iv.transformationController!.value.getMaxScaleOnAxis();
    expect(zoomedInScale, greaterThan(initialScale));

    // Release Control key
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  });

  testWidgets('PointerScaleEvent triggers zoom (web & trackpad pinch/ctrl+wheel signal)', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
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

    final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final initialScale = iv.transformationController!.value.getMaxScaleOnAxis();

    // Send PointerScaleEvent with scale = 1.25 (zoom in)
    await tester.sendEventToBinding(
      const PointerScaleEvent(
        position: Offset(500, 400),
        scale: 1.25,
      ),
    );
    await tester.pumpAndSettle();

    final zoomedInScale = iv.transformationController!.value.getMaxScaleOnAxis();
    expect(zoomedInScale, greaterThan(initialScale));
  });
}
