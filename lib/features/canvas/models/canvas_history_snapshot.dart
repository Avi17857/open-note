import 'package:open_note/features/canvas/models/note_image.dart';
import 'package:open_note/features/canvas/models/note_text_box.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/notebook/models/note_page.dart';

/// An immutable point-in-time snapshot of the entire multi-page document state
/// used for the unified undo/redo command stack across inking and rich text.
class CanvasHistorySnapshot {
  final List<NotePage> pages;
  final int activePageIndex;

  CanvasHistorySnapshot({
    required List<NotePage> pages,
    this.activePageIndex = 0,
  }) : pages = List.unmodifiable(pages.map((p) => p.clone()).toList());

  /// Convenience getter for backward compatibility with single-page assertions
  List<Stroke> get strokes =>
      pages.isNotEmpty && activePageIndex < pages.length
          ? pages[activePageIndex].strokes
          : const [];

  /// Convenience getter for backward compatibility with single-page assertions
  List<NoteTextBox> get textBoxes =>
      pages.isNotEmpty && activePageIndex < pages.length
          ? pages[activePageIndex].textBoxes
          : const [];

  /// Convenience getter for backward compatibility with single-page assertions
  List<NoteImage> get images =>
      pages.isNotEmpty && activePageIndex < pages.length
          ? pages[activePageIndex].images
          : const [];
}
