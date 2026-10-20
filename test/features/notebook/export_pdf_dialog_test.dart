import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_note/features/canvas/presentation/painters/page_background_painter.dart';
import 'package:open_note/features/notebook/models/note_document.dart';
import 'package:open_note/features/notebook/models/note_page.dart';
import 'package:open_note/features/notebook/presentation/widgets/export_pdf_dialog.dart';

void main() {
  testWidgets('ExportPdfDialog renders title, pages, options and toggles modes',
      (tester) async {
    final doc = NoteDocument(
      id: 'doc_1',
      title: 'Physics Notes',
      pages: [
        NotePage(id: 'p1', pageNumber: 1),
        NotePage(id: 'p2', pageNumber: 2),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ExportPdfDialog.show(
                    context,
                    document: doc,
                    initialTemplate: PageTemplate.ruled,
                  );
                },
                child: const Text('Open Export Dialog'),
              );
            },
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text('Open Export Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.text('Export Note as PDF'), findsOneWidget);
    expect(find.text('Physics Notes • 2 Pages'), findsOneWidget);
    expect(find.text('Inbound Page Bounds (1:1)'), findsOneWidget);
    expect(find.text('Infinite Canvas (Shrink to Fit)'), findsOneWidget);
    expect(find.text('Page Background'), findsOneWidget);
    expect(find.text('Ruled'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('Blank'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Toggle to Infinite Canvas mode
    await tester.tap(find.text('Infinite Canvas (Shrink to Fit)'));
    await tester.pumpAndSettle();

    // Toggle template to Grid
    await tester.tap(find.text('Grid'));
    await tester.pumpAndSettle();

    // Tap Cancel
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify dialog dismissed
    expect(find.text('Export Note as PDF'), findsNothing);
  });
}
