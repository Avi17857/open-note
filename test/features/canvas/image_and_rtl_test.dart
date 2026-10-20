import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/controllers/rich_text_editing_controller.dart';
import 'package:open_note/features/canvas/models/note_image.dart';
import 'package:open_note/features/canvas/models/note_text_box.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/presentation/note_canvas.dart';
import 'package:open_note/features/canvas/presentation/widgets/note_image_widget.dart';
import 'package:open_note/features/canvas/presentation/widgets/text_box_widget.dart';
import 'package:open_note/features/notebook/models/note_page.dart';

// Helper to generate a minimal 1x1 transparent PNG image for tests
Uint8List createSamplePngBytes() {
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);
}

void main() {
  group('RTL Language & Direction Tests', () {
    test('NoteTextBox.isRtlText correctly identifies RTL scripts', () {
      expect(NoteTextBox.isRtlText('مرحبا بك'), isTrue); // Arabic
      expect(NoteTextBox.isRtlText('שלום עולם'), isTrue); // Hebrew
      expect(NoteTextBox.isRtlText('سلام دنیا'), isTrue); // Persian
      expect(NoteTextBox.isRtlText('Hello World'), isFalse); // English LTR
      expect(NoteTextBox.isRtlText('12345'), isFalse); // Numbers
      expect(NoteTextBox.isRtlText(''), isFalse); // Empty
      expect(NoteTextBox.isRtlText('English with عربي word'), isTrue); // Mixed
    });

    test('NoteTextBox serializes and deserializes textDirection correctly', () {
      final boxRtl = NoteTextBox(
        id: 'box_rtl',
        position: const Offset(50, 50),
        text: 'مرحبا',
        textDirection: TextDirection.rtl,
      );

      final jsonRtl = boxRtl.toJson();
      expect(jsonRtl['textDirection'], 'rtl');

      final restoredRtl = NoteTextBox.fromJson(jsonRtl);
      expect(restoredRtl.textDirection, TextDirection.rtl);
      expect(restoredRtl.effectiveTextDirection, TextDirection.rtl);

      final boxAuto = NoteTextBox(
        id: 'box_auto',
        position: const Offset(50, 50),
        text: 'مرحبا',
      );
      final jsonAuto = boxAuto.toJson();
      expect(jsonAuto.containsKey('textDirection'), isFalse);

      final restoredAuto = NoteTextBox.fromJson(jsonAuto);
      expect(restoredAuto.textDirection, isNull);
      expect(restoredAuto.effectiveTextDirection, TextDirection.rtl);
    });

    test('CanvasController toggles text direction between LTR and RTL', () {
      final controller = CanvasController();
      controller.setTool(ToolType.text);

      final box = controller.addTextBox(const Offset(60, 60), text: 'Hello');
      expect(controller.isCurrentTextRtl, isFalse);

      controller.toggleTextDirection();
      expect(controller.isCurrentTextRtl, isTrue);
      expect(box.textDirection, TextDirection.rtl);

      controller.toggleTextDirection();
      expect(controller.isCurrentTextRtl, isFalse);
      expect(box.textDirection, TextDirection.ltr);
    });

    testWidgets('TextBoxWidget renders with RTL text direction and right alignment for Arabic', (tester) async {
      final controller = CanvasController();
      controller.setTool(ToolType.text);

      final box = NoteTextBox(
        id: 'box_arabic',
        position: const Offset(100, 100),
        width: 300,
        text: 'مرحبا بكم في التطبيق',
      );
      final richController = RichTextEditingController(text: box.text);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TextBoxWidget(
                  textBox: box,
                  controller: controller,
                  isSelected: true,
                  richController: richController,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.textDirection, TextDirection.rtl);
      expect(textField.textAlign, TextAlign.right);
    });

    testWidgets('TextBoxWidget provides left resize handle for natural RTL resizing', (tester) async {
      final controller = CanvasController();
      controller.setTool(ToolType.text);

      final box = NoteTextBox(
        id: 'box_rtl_resize',
        position: const Offset(200, 100),
        width: 300,
        text: 'نص عربي',
        textDirection: TextDirection.rtl,
      );
      final richController = RichTextEditingController(text: box.text);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TextBoxWidget(
                  textBox: box,
                  controller: controller,
                  isSelected: true,
                  richController: richController,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final leftHandleFinder = find.byKey(const Key('text_box_resize_handle_left'));
      expect(leftHandleFinder, findsOneWidget);

      final rightHandleFinder = find.byKey(const Key('text_box_resize_handle'));
      expect(rightHandleFinder, findsOneWidget);
    });
  });

  group('NoteImage Model & Serialization Tests', () {
    test('NoteImage serializes and deserializes bytes to base64 correctly', () {
      final sampleBytes = createSamplePngBytes();
      final image = NoteImage(
        id: 'img_test_1',
        position: const Offset(120, 180),
        width: 320,
        height: 240,
        bytes: sampleBytes,
        name: 'diagram.png',
      );

      final json = image.toJson();
      expect(json['id'], 'img_test_1');
      expect(json['x'], 120.0);
      expect(json['y'], 180.0);
      expect(json['width'], 320.0);
      expect(json['height'], 240.0);
      expect(json['name'], 'diagram.png');
      expect(json['data'], isNotEmpty);

      final restored = NoteImage.fromJson(json);
      expect(restored.id, image.id);
      expect(restored.position, image.position);
      expect(restored.width, image.width);
      expect(restored.height, image.height);
      expect(restored.name, image.name);
      expect(restored.bytes, image.bytes);
      expect(restored.bounds, Rect.fromLTWH(120, 180, 320, 240));
    });

    test('NotePage serializes and clones images list properly', () {
      final sampleBytes = createSamplePngBytes();
      final page = NotePage(
        id: 'page_1',
        pageNumber: 1,
        images: [
          NoteImage(
            id: 'img_1',
            position: const Offset(40, 60),
            width: 200,
            height: 150,
            bytes: sampleBytes,
          ),
        ],
      );

      final cloned = page.clone();
      expect(cloned.images.length, 1);
      expect(cloned.images.first.id, 'img_1');

      final json = page.toJson();
      final restored = NotePage.fromJson(json);
      expect(restored.images.length, 1);
      expect(restored.images.first.id, 'img_1');
      expect(restored.images.first.bytes, sampleBytes);
    });
  });

  group('CanvasController Image Operations & Undo/Redo', () {
    test('addImage adds image, selects it, and supports undo/redo', () async {
      final controller = CanvasController();
      final sampleBytes = createSamplePngBytes();

      expect(controller.images.isEmpty, isTrue);

      final img = await controller.addImage(
        sampleBytes,
        position: const Offset(80, 100),
        width: 300,
        height: 200,
      );

      expect(controller.images.length, 1);
      expect(controller.selectedImageId, img.id);
      expect(controller.selectedImage?.id, img.id);
      expect(controller.activeTool, ToolType.lasso);

      // Undo image insertion
      controller.undo();
      expect(controller.images.isEmpty, isTrue);

      // Redo image insertion
      controller.redo();
      expect(controller.images.length, 1);
      expect(controller.images.first.id, img.id);
    });

    test('updateImagePosition and updateImageSize modify active image', () async {
      final controller = CanvasController();
      final sampleBytes = createSamplePngBytes();

      final img = await controller.addImage(
        sampleBytes,
        position: const Offset(50, 50),
        width: 200,
        height: 150,
      );

      controller.updateImagePosition(img.id, const Offset(120, 140));
      expect(controller.selectedImage?.position, const Offset(120, 140));

      controller.updateImageSize(img.id, 400, 300);
      expect(controller.selectedImage?.width, 400);
      expect(controller.selectedImage?.height, 300);
    });

    test('bringImageToFront and sendImageToBack reorder layers', () async {
      final controller = CanvasController();
      final sampleBytes = createSamplePngBytes();

      final img1 = await controller.addImage(sampleBytes, width: 100, height: 100);
      final img2 = await controller.addImage(sampleBytes, width: 100, height: 100);

      expect(controller.images.map((i) => i.id).toList(), [img1.id, img2.id]);

      controller.sendImageToBack(img2.id);
      expect(controller.images.map((i) => i.id).toList(), [img2.id, img1.id]);

      controller.bringImageToFront(img2.id);
      expect(controller.images.map((i) => i.id).toList(), [img1.id, img2.id]);
    });

    test('deleteImage removes image and records undo history', () async {
      final controller = CanvasController();
      final sampleBytes = createSamplePngBytes();

      final img = await controller.addImage(sampleBytes, width: 100, height: 100);
      expect(controller.images.length, 1);

      controller.deleteImage(img.id);
      expect(controller.images.isEmpty, isTrue);
      expect(controller.selectedImageId, isNull);

      controller.undo();
      expect(controller.images.length, 1);
      expect(controller.images.first.id, img.id);
    });
  });

  group('NoteImageWidget & NoteCanvas Integration', () {
    testWidgets('NoteImageWidget displays image and shows handles when selected in text mode', (tester) async {
      final controller = CanvasController();
      controller.setTool(ToolType.text);

      final sampleBytes = createSamplePngBytes();
      final img = NoteImage(
        id: 'test_img_widget',
        position: const Offset(40, 50),
        width: 250,
        height: 180,
        bytes: sampleBytes,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                NoteImageWidget(
                  image: img,
                  controller: controller,
                  isSelected: true,
                  pageIndex: 0,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.flip_to_front_rounded), findsOneWidget);
      expect(find.byIcon(Icons.flip_to_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('NoteCanvas renders inserted image on page', (tester) async {
      final controller = CanvasController();
      controller.setTool(ToolType.text);
      final sampleBytes = createSamplePngBytes();

      await controller.addImage(
        sampleBytes,
        position: const Offset(100, 100),
        width: 200,
        height: 150,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCanvas(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NoteImageWidget), findsOneWidget);
    });

    testWidgets('Tapping delete button on NoteImageWidget inside NoteCanvas deletes image', (tester) async {
      final controller = CanvasController();
      controller.setTool(ToolType.text);
      final sampleBytes = createSamplePngBytes();

      await controller.addImage(
        sampleBytes,
        position: const Offset(100, 100),
        width: 200,
        height: 150,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCanvas(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.images.length, 1);
      expect(controller.selectedImageId, isNotNull);

      // Verify the delete icon button is visible
      final deleteBtnFinder = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteBtnFinder, findsOneWidget);

      // Tap the delete button
      await tester.tap(deleteBtnFinder);
      await tester.pumpAndSettle();

      // Check if image was deleted
      expect(controller.images.isEmpty, isTrue, reason: 'Image should be deleted when tapping delete button');
    });

    testWidgets('Dragging corner resize handle resizes image on NoteCanvas', (tester) async {
      final controller = CanvasController();
      controller.setTool(ToolType.lasso);
      final sampleBytes = createSamplePngBytes();

      final img = await controller.addImage(
        sampleBytes,
        position: const Offset(100, 100),
        width: 200,
        height: 150,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCanvas(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialWidth = img.width;
      final initialHeight = img.height;

      // Find bottom-right handle and drag it
      final bottomRightHandle = find.byKey(const Key('image_corner_handle_bottomRight'));
      expect(bottomRightHandle, findsOneWidget);

      // Drag the bottom-right handle downwards and rightwards by 60px
      final gesture = await tester.startGesture(tester.getCenter(bottomRightHandle));
      await gesture.moveBy(const Offset(30, 30));
      await gesture.moveBy(const Offset(30, 30));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.images.first.width, greaterThan(initialWidth));
      expect(controller.images.first.height, greaterThan(initialHeight));
    });

    testWidgets('Tapping image in lasso mode selects it', (tester) async {
      final controller = CanvasController();
      final sampleBytes = createSamplePngBytes();

      final img = await controller.addImage(
        sampleBytes,
        position: const Offset(100, 100),
        width: 200,
        height: 150,
      );

      // Deselect image and switch to lasso
      controller.selectImage(null);
      controller.setTool(ToolType.lasso);
      expect(controller.selectedImageId, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCanvas(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the image container
      final imgWidget = find.byType(NoteImageWidget);
      expect(imgWidget, findsOneWidget);

      await tester.tap(imgWidget);
      await tester.pumpAndSettle();

      expect(controller.selectedImageId, img.id);
    });

    testWidgets('Dragging and resizing image positioned outside page in pasteboard', (tester) async {
      final controller = CanvasController();
      final sampleBytes = createSamplePngBytes();

      // Place image outside the page in the left pasteboard (x = -120)
      final img = await controller.addImage(
        sampleBytes,
        position: const Offset(-120, 150),
        width: 200,
        height: 150,
      );

      expect(controller.selectedImageId, img.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCanvas(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialPos = img.position;
      final initialWidth = img.width;

      // 1. Drag the image from outside the page
      final imgWidget = find.byType(NoteImageWidget);
      expect(imgWidget, findsOneWidget);

      await tester.drag(imgWidget, const Offset(60, 40));
      await tester.pumpAndSettle();

      expect(controller.images.first.position.dx, greaterThan(initialPos.dx));
      expect(controller.images.first.position.dy, greaterThan(initialPos.dy));

      // 2. Resize via corner handle in pasteboard
      final bottomRightHandle = find.byKey(const Key('image_corner_handle_bottomRight'));
      expect(bottomRightHandle, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(bottomRightHandle));
      await gesture.moveBy(const Offset(30, 30));
      await gesture.moveBy(const Offset(30, 30));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.images.first.width, greaterThan(initialWidth));
    });

    testWidgets('Inking tool draws stroke on top of image raster on canvas', (tester) async {
      final controller = CanvasController();
      final sampleBytes = createSamplePngBytes();

      await controller.addImage(
        sampleBytes,
        position: const Offset(100, 100),
        width: 300,
        height: 200,
      );

      // Switch to pen tool
      controller.setTool(ToolType.pen);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCanvas(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.selectedImageId, isNull);

      // Draw stroke across the image
      final gesture = await tester.startGesture(const Offset(200, 200));
      await gesture.moveBy(const Offset(50, 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.strokes.isNotEmpty, isTrue, reason: 'Stroke should be drawn on top of the image');
    });
  });
}
