import 'dart:typed_data';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/canvas/models/note_image.dart';
import 'package:open_note/features/canvas/models/note_text_box.dart';
import 'package:open_note/features/canvas/models/rich_text_span.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/presentation/painters/page_background_painter.dart';
import 'package:open_note/features/notebook/models/note_document.dart';
import 'package:open_note/features/notebook/models/note_page.dart';
import 'package:open_note/features/storage/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleImageBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  group('PdfExportService Tests', () {
    test('Generates PDF for simple empty document', () async {
      final doc = NoteDocument(
        id: 'doc_1',
        title: 'Empty Note',
        pages: [NotePage(id: 'page_1', pageNumber: 1)],
      );

      final pdfBytes = await PdfExportService.generatePdf(
        document: doc,
        template: PageTemplate.blank,
      );

      expect(pdfBytes, isNotEmpty);
      // Valid PDF starts with %PDF-
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('Generates PDF for multi-page document with ruled template', () async {
      final doc = NoteDocument(
        id: 'doc_2',
        title: 'Multi-Page Note',
        pages: [
          NotePage(id: 'p1', pageNumber: 1),
          NotePage(id: 'p2', pageNumber: 2),
          NotePage(id: 'p3', pageNumber: 3),
        ],
      );

      final pdfBytes = await PdfExportService.generatePdf(
        document: doc,
        template: PageTemplate.ruled,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('Generates PDF with vector strokes (pen, highlighter, fountain pen)', () async {
      final penStroke = Stroke(
        points: [
          StrokePoint(100, 100),
          StrokePoint(150, 120),
          StrokePoint(200, 150),
        ],
        color: material.Colors.blue,
        strokeWidth: 4.0,
        toolType: ToolType.pen,
      );

      final highlighterStroke = Stroke(
        points: [
          StrokePoint(50, 300),
          StrokePoint(250, 300),
        ],
        color: material.Colors.yellow,
        strokeWidth: 20.0,
        toolType: ToolType.highlighter,
      );

      final fountainStroke = Stroke(
        points: [
          StrokePoint(80, 500, pressure: 0.2),
          StrokePoint(120, 520, pressure: 0.8),
          StrokePoint(160, 540, pressure: 0.4),
        ],
        color: material.Colors.deepPurple,
        strokeWidth: 5.0,
        toolType: ToolType.fountainPen,
      );

      final singlePointStroke = Stroke(
        points: [StrokePoint(300, 300)],
        color: material.Colors.red,
        strokeWidth: 6.0,
        toolType: ToolType.pen,
      );

      final doc = NoteDocument(
        id: 'doc_strokes',
        title: 'Inking Test',
        pages: [
          NotePage(
            id: 'p1',
            pageNumber: 1,
            strokes: [
              penStroke,
              highlighterStroke,
              fountainStroke,
              singlePointStroke,
            ],
          ),
        ],
      );

      final pdfBytes = await PdfExportService.generatePdf(
        document: doc,
        template: PageTemplate.grid,
      );

      expect(pdfBytes, isNotEmpty);
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('Generates PDF with raster images and rich text boxes', () async {
      final testImage = NoteImage(
        id: 'img_1',
        position: const material.Offset(50, 80),
        width: 180,
        height: 120,
        bytes: sampleImageBytes,
      );

      final textBox = NoteTextBox(
        id: 'box_1',
        position: const material.Offset(60, 240),
        width: 320,
        text: 'Hello World! Welcome to OpenNote PDF export.',
        spans: const [
          RichTextSpan(
            start: 0,
            end: 12,
            bold: true,
            heading: HeadingLevel.h2,
            color: material.Colors.blue,
          ),
          RichTextSpan(
            start: 13,
            end: 20,
            italic: true,
            underline: true,
          ),
          RichTextSpan(
            start: 21,
            end: 32,
            highlightColor: material.Colors.yellow,
            strikethrough: true,
          ),
        ],
      );

      final doc = NoteDocument(
        id: 'doc_media',
        title: 'Media & Rich Text Note',
        pages: [
          NotePage(
            id: 'p1',
            pageNumber: 1,
            images: [testImage],
            textBoxes: [textBox],
          ),
        ],
      );

      final pdfBytes = await PdfExportService.generatePdf(
        document: doc,
        template: PageTemplate.ruled,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1500));
    });

    test('Infinite canvas mode scales down pasteboard content (shrinkToFit)', () async {
      // Content placed far outside the normal 600x850 page boundary
      final pasteboardStroke = Stroke(
        points: [
          StrokePoint(-200, -100),
          StrokePoint(-150, -80),
        ],
        color: material.Colors.green,
        strokeWidth: 3.0,
      );

      final farRightStroke = Stroke(
        points: [
          StrokePoint(900, 1100),
          StrokePoint(950, 1150),
        ],
        color: material.Colors.orange,
        strokeWidth: 3.0,
      );

      final doc = NoteDocument(
        id: 'doc_infinite',
        title: 'Infinite Canvas Note',
        pages: [
          NotePage(
            id: 'p1',
            pageNumber: 1,
            strokes: [pasteboardStroke, farRightStroke],
          ),
        ],
      );

      // Export with shrinkToFit
      final shrinkPdfBytes = await PdfExportService.generatePdf(
        document: doc,
        mode: PdfExportMode.shrinkToFit,
        template: PageTemplate.ruled,
      );

      // Export with pageBounds
      final standardPdfBytes = await PdfExportService.generatePdf(
        document: doc,
        mode: PdfExportMode.pageBounds,
        template: PageTemplate.ruled,
      );

      expect(shrinkPdfBytes, isNotEmpty);
      expect(standardPdfBytes, isNotEmpty);
      expect(String.fromCharCodes(shrinkPdfBytes.sublist(0, 5)), equals('%PDF-'));
      expect(String.fromCharCodes(standardPdfBytes.sublist(0, 5)), equals('%PDF-'));
    });
  });
}
