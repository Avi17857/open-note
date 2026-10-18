import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/models/rich_text_span.dart';

/// A native [TextEditingController] that manages non-destructive attributed formatting spans.
///
/// Features:
/// - Elementary boundary slicing algorithm producing disjoint styled [TextSpan]s.
/// - Automatic span adjustment on typing, pasting, and backspacing.
/// - Rich formatting toggles: Bold, Italic, Underline, Strikethrough, Headings, and Colors.
/// - Active typing style persistence for collapsed cursor typing.
class RichTextEditingController extends TextEditingController {
  List<RichTextSpan> _spans = [];
  String _previousText = '';

  // Active styling for the next inserted characters when cursor is collapsed
  bool? _pendingBold;
  bool? _pendingItalic;
  bool? _pendingUnderline;
  bool? _pendingStrikethrough;
  Color? _pendingColor;
  Color? _pendingHighlightColor;
  HeadingLevel? _pendingHeading;

  RichTextEditingController({
    super.text,
    List<RichTextSpan>? spans,
  }) {
    _spans = spans != null ? List.from(spans) : [];
    _previousText = text;
  }

  List<RichTextSpan> get spans => List.unmodifiable(_spans);

  set spans(List<RichTextSpan> newSpans) {
    _spans = List.from(newSpans);
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = _previousText;
    final newText = newValue.text;

    if (oldText != newText) {
      _adjustSpansOnTextChange(oldText, newText, selection);
      _previousText = newText;
    }

    super.value = newValue;
  }

  /// Automatically shifts and resizes span intervals when text is inserted or deleted.
  void _adjustSpansOnTextChange(
    String oldText,
    String newText,
    TextSelection oldSelection,
  ) {
    if (_spans.isEmpty && _hasNoPendingStyles) return;

    final oldLen = oldText.length;
    final newLen = newText.length;

    // Detect common prefix
    int prefixLen = 0;
    while (prefixLen < oldLen &&
        prefixLen < newLen &&
        oldText.codeUnitAt(prefixLen) == newText.codeUnitAt(prefixLen)) {
      prefixLen++;
    }

    // Detect common suffix (bounded by prefix)
    int suffixLen = 0;
    while (suffixLen < (oldLen - prefixLen) &&
        suffixLen < (newLen - prefixLen) &&
        oldText.codeUnitAt(oldLen - 1 - suffixLen) ==
            newText.codeUnitAt(newLen - 1 - suffixLen)) {
      suffixLen++;
    }

    final deletedStart = prefixLen;
    final deletedEnd = oldLen - suffixLen;
    final deletedCount = deletedEnd - deletedStart;
    final insertedCount = newLen - prefixLen - suffixLen;

    final List<RichTextSpan> updatedSpans = [];

    for (final span in _spans) {
      int start = span.start;
      int end = span.end;

      // 1. Text deletion handling
      if (deletedCount > 0) {
        if (start >= deletedEnd) {
          // Span is completely after deleted range -> shift backward
          start -= deletedCount;
          end -= deletedCount;
        } else if (end <= deletedStart) {
          // Span is completely before deleted range -> unchanged
        } else {
          // Span overlaps deleted range -> contract it
          if (start > deletedStart) start = deletedStart;
          final overlap = min<int>(span.end, deletedEnd) - max<int>(span.start, deletedStart);
          end -= overlap;
        }
      }

      // 2. Text insertion handling
      if (insertedCount > 0) {
        final insertPos = deletedStart;
        if (start > insertPos) {
          // Span starts after insertion point -> shift forward
          start += insertedCount;
          end += insertedCount;
        } else if (start <= insertPos && end >= insertPos) {
          // Span encloses insertion point -> expand span
          end += insertedCount;
        }
      }

      // Clamp to valid text range and only keep non-empty spans
      start = start.clamp(0, newLen);
      end = end.clamp(0, newLen);
      if (start < end) {
        updatedSpans.add(span.copyWith(start: start, end: end));
      }
    }

    // If text was inserted and pending styles were queued, create a new span for inserted range
    if (insertedCount > 0 && !_hasNoPendingStyles) {
      final insertStart = deletedStart;
      final insertEnd = deletedStart + insertedCount;
      updatedSpans.add(RichTextSpan(
        start: insertStart,
        end: insertEnd,
        bold: _pendingBold ?? false,
        italic: _pendingItalic ?? false,
        underline: _pendingUnderline ?? false,
        strikethrough: _pendingStrikethrough ?? false,
        color: _pendingColor,
        highlightColor: _pendingHighlightColor,
        heading: _pendingHeading ?? HeadingLevel.none,
      ));
      _clearPendingStyles();
    }

    _spans = updatedSpans;
  }

  bool get _hasNoPendingStyles =>
      _pendingBold == null &&
      _pendingItalic == null &&
      _pendingUnderline == null &&
      _pendingStrikethrough == null &&
      _pendingColor == null &&
      _pendingHighlightColor == null &&
      _pendingHeading == null;

  void _clearPendingStyles() {
    _pendingBold = null;
    _pendingItalic = null;
    _pendingUnderline = null;
    _pendingStrikethrough = null;
    _pendingColor = null;
    _pendingHighlightColor = null;
    _pendingHeading = null;
  }

  // ===========================================================================
  // Boundary Slicing & Rendering Algorithm
  // ===========================================================================

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    if (_spans.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    // 1. Collect all boundary points: {0, text.length} U {start, end for each span}
    final Set<int> boundarySet = {0, text.length};
    for (final s in _spans) {
      if (s.start >= 0 && s.start <= text.length) boundarySet.add(s.start);
      if (s.end >= 0 && s.end <= text.length) boundarySet.add(s.end);
    }

    final List<int> boundaries = boundarySet.toList()..sort();
    final List<TextSpan> children = [];

    // 2. Iterate each elementary disjoint slice [b_i, b_{i+1}]
    for (int i = 0; i < boundaries.length - 1; i++) {
      final segStart = boundaries[i];
      final segEnd = boundaries[i + 1];
      if (segStart >= segEnd) continue;

      final segText = text.substring(segStart, segEnd);

      // Find all spans covering this slice
      bool isBold = false;
      bool isItalic = false;
      bool isUnderline = false;
      bool isStrikethrough = false;
      Color? segColor;
      Color? segHighlight;
      HeadingLevel segHeading = HeadingLevel.none;
      double? segFontSize;

      for (final s in _spans) {
        if (s.start <= segStart && s.end >= segEnd) {
          if (s.bold) isBold = true;
          if (s.italic) isItalic = true;
          if (s.underline) isUnderline = true;
          if (s.strikethrough) isStrikethrough = true;
          if (s.color != null) segColor = s.color;
          if (s.highlightColor != null) segHighlight = s.highlightColor;
          if (s.heading != HeadingLevel.none) segHeading = s.heading;
          if (s.fontSize != null) segFontSize = s.fontSize;
        }
      }

      final sliceSpan = RichTextSpan(
        start: segStart,
        end: segEnd,
        bold: isBold,
        italic: isItalic,
        underline: isUnderline,
        strikethrough: isStrikethrough,
        color: segColor,
        highlightColor: segHighlight,
        heading: segHeading,
        fontSize: segFontSize,
      );

      children.add(TextSpan(
        text: segText,
        style: sliceSpan.toTextStyle(baseStyle: style),
      ));
    }

    return TextSpan(children: children);
  }

  // ===========================================================================
  // Rich Text Formatting Action API
  // ===========================================================================

  bool get isSelectionBold => _checkSelectionAttribute((s) => s.bold);
  bool get isSelectionItalic => _checkSelectionAttribute((s) => s.italic);
  bool get isSelectionUnderline => _checkSelectionAttribute((s) => s.underline);
  bool get isSelectionStrikethrough =>
      _checkSelectionAttribute((s) => s.strikethrough);

  HeadingLevel get currentHeading {
    if (selection.isCollapsed) {
      // Find heading at cursor
      final cursor = selection.baseOffset;
      for (final s in _spans) {
        if (s.contains(cursor) && s.heading != HeadingLevel.none) {
          return s.heading;
        }
      }
      return HeadingLevel.none;
    }
    for (final s in _spans) {
      if (s.overlaps(selection.start, selection.end) &&
          s.heading != HeadingLevel.none) {
        return s.heading;
      }
    }
    return HeadingLevel.none;
  }

  bool _checkSelectionAttribute(bool Function(RichTextSpan) check) {
    if (selection.isCollapsed) {
      final cursor = selection.baseOffset;
      for (final s in _spans) {
        if (s.contains(cursor) && check(s)) return true;
      }
      return false;
    }
    final relevant = _spans.where(
      (s) => s.overlaps(selection.start, selection.end),
    );
    return relevant.isNotEmpty && relevant.every(check);
  }

  void toggleBold() {
    if (selection.isCollapsed) {
      _pendingBold = !(_pendingBold ?? isSelectionBold);
      notifyListeners();
      return;
    }
    final makeBold = !isSelectionBold;
    _applyAttribute(
      selection.start,
      selection.end,
      (s) => s.copyWith(bold: makeBold),
      addIfMissing: makeBold
          ? (start, end) => RichTextSpan(start: start, end: end, bold: true)
          : null,
    );
  }

  void toggleItalic() {
    if (selection.isCollapsed) {
      _pendingItalic = !(_pendingItalic ?? isSelectionItalic);
      notifyListeners();
      return;
    }
    final makeItalic = !isSelectionItalic;
    _applyAttribute(
      selection.start,
      selection.end,
      (s) => s.copyWith(italic: makeItalic),
      addIfMissing: makeItalic
          ? (start, end) => RichTextSpan(start: start, end: end, italic: true)
          : null,
    );
  }

  void toggleUnderline() {
    if (selection.isCollapsed) {
      _pendingUnderline = !(_pendingUnderline ?? isSelectionUnderline);
      notifyListeners();
      return;
    }
    final makeUnderline = !isSelectionUnderline;
    _applyAttribute(
      selection.start,
      selection.end,
      (s) => s.copyWith(underline: makeUnderline),
      addIfMissing: makeUnderline
          ? (start, end) =>
              RichTextSpan(start: start, end: end, underline: true)
          : null,
    );
  }

  void toggleStrikethrough() {
    if (selection.isCollapsed) {
      _pendingStrikethrough =
          !(_pendingStrikethrough ?? isSelectionStrikethrough);
      notifyListeners();
      return;
    }
    final makeStrikethrough = !isSelectionStrikethrough;
    _applyAttribute(
      selection.start,
      selection.end,
      (s) => s.copyWith(strikethrough: makeStrikethrough),
      addIfMissing: makeStrikethrough
          ? (start, end) =>
              RichTextSpan(start: start, end: end, strikethrough: true)
          : null,
    );
  }

  void setHeading(HeadingLevel level) {
    if (selection.isCollapsed) {
      // Apply heading to current paragraph/line
      final cursor = selection.baseOffset.clamp(0, text.length);
      final lineStart = text.lastIndexOf('\n', max(0, cursor - 1)) + 1;
      final nextNewline = text.indexOf('\n', cursor);
      final lineEnd = nextNewline == -1 ? text.length : nextNewline;

      if (lineStart < lineEnd) {
        _applyHeadingRange(lineStart, lineEnd, level);
      } else {
        _pendingHeading = level;
      }
      notifyListeners();
      return;
    }

    _applyHeadingRange(selection.start, selection.end, level);
  }

  void _applyHeadingRange(int start, int end, HeadingLevel level) {
    _applyAttribute(
      start,
      end,
      (s) => s.copyWith(heading: level),
      addIfMissing: level != HeadingLevel.none
          ? (s, e) => RichTextSpan(start: s, end: e, heading: level)
          : null,
    );
  }

  void setTextColor(Color color) {
    if (selection.isCollapsed) {
      _pendingColor = color;
      notifyListeners();
      return;
    }
    _applyAttribute(
      selection.start,
      selection.end,
      (s) => s.copyWith(color: color),
      addIfMissing: (s, e) => RichTextSpan(start: s, end: e, color: color),
    );
  }

  void setTextHighlight(Color? color) {
    if (selection.isCollapsed) {
      _pendingHighlightColor = color;
      notifyListeners();
      return;
    }
    _applyAttribute(
      selection.start,
      selection.end,
      (s) => s.copyWith(highlightColor: color),
      addIfMissing: color != null
          ? (s, e) => RichTextSpan(start: s, end: e, highlightColor: color)
          : null,
    );
  }

  /// Slices existing spans along [start, end] and modifies covered portions with [modifier].
  void _applyAttribute(
    int start,
    int end,
    RichTextSpan Function(RichTextSpan) modifier, {
    RichTextSpan Function(int start, int end)? addIfMissing,
  }) {
    if (start >= end) return;

    final List<RichTextSpan> result = [];
    bool coveredAny = false;

    for (final s in _spans) {
      if (!s.overlaps(start, end)) {
        result.add(s);
        continue;
      }

      coveredAny = true;
      // Pre-overlap portion
      if (s.start < start) {
        result.add(s.copyWith(end: start));
      }

      // Overlapping portion (modified)
      final overlapStart = max(s.start, start);
      final overlapEnd = min(s.end, end);
      if (overlapStart < overlapEnd) {
        final modified = modifier(s.copyWith(start: overlapStart, end: overlapEnd));
        result.add(modified);
      }

      // Post-overlap portion
      if (s.end > end) {
        result.add(s.copyWith(start: end));
      }
    }

    if (!coveredAny && addIfMissing != null) {
      result.add(addIfMissing(start, end));
    }

    _spans = result;
    notifyListeners();
  }
}
