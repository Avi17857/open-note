import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
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
}
