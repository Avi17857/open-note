# OpenNote - Rich Text Engine Architecture

## 1. Overview & Architectural Motivation

OpenNote combines the fluid inking of **Samsung Notes** with the freeform canvas typography of **Microsoft OneNote**. For students and professionals, typed text is a first-class citizen alongside inking: lecture notes require rapid typing, headings, bulleted lists, and formula annotations.

### Why a Custom Native Engine over Third-Party Packages (Fleather / Quill)?
Previous iterations evaluated `fleather` and Quill-based engines, which introduced severe friction:
1. **Delta Model Rigidity:** Quill's operation trees (`insert`, `retain`, `delete`) are built for traditional linear word processors. In an interactive canvas with zoom/pan matrices, Quill handles misalign and fight gesture arenas.
2. **Gesture & Focus Clashes:** Rigid scrollables and selection handles inside Quill fight `InteractiveViewer` and stylus palm rejection.
3. **Device Feature Loss:** Heavy wrapper editors often break Samsung S-Pen handwriting-to-text directly over `TextField`s.

By building a **Native Attributed-Span Engine** directly on Flutter's `TextEditingController` and `TextSpan` primitives:
- Native soft keyboards, autocorrect, spellcheck, and S-Pen handwriting input work with 100% fidelity.
- Text boxes sit natively inside canvas coordinates with zero matrix drift.
- The document format is plain, human-readable text with lightweight span attributes that easily serialize to JSON, Markdown, or PDF.

---

## 2. Data Models & JSON Serialization

### 2.1 The Span Model (`RichTextSpan`)
Formatting is modeled as non-destructive attributed ranges over a plain UTF-16 string:

```dart
class RichTextSpan {
  final int start;
  final int end;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final double? fontSize;
  final Color? color;
  final Color? highlightColor;
  final HeadingLevel heading; // none, h1, h2, h3

  const RichTextSpan({
    required this.start,
    required this.end,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.fontSize,
    this.color,
    this.highlightColor,
    this.heading = HeadingLevel.none,
  });
}
```

### 2.2 The Container Model (`NoteTextBox`)
Each text block on the canvas represents an independent, movable container:

```dart
class NoteTextBox {
  final String id;
  Offset position;
  double width;
  double? height;
  String text;
  List<RichTextSpan> spans;

  NoteTextBox({
    required this.id,
    required this.position,
    this.width = 320.0,
    this.height,
    this.text = '',
    List<RichTextSpan>? spans,
  }) : spans = spans ?? [];
}
```

### 2.3 Serialization Schema (JSON)
Saved notes store text boxes alongside vector strokes in a clean, human-readable structure:

```json
{
  "textBoxes": [
    {
      "id": "box_1729158400",
      "x": 80.0,
      "y": 140.0,
      "width": 400.0,
      "text": "Cellular Respiration\nGlycolysis occurs in the cytoplasm.",
      "spans": [
        {
          "start": 0,
          "end": 20,
          "heading": "h1",
          "bold": true,
          "color": "#1A237E"
        },
        {
          "start": 21,
          "end": 31,
          "bold": true,
          "color": "#2E7D32"
        },
        {
          "start": 46,
          "end": 55,
          "italic": true,
          "highlight": "#FFF59D"
        }
      ]
    }
  ]
}
```

---

## 3. Core Engine Mechanics: `RichTextEditingController`

Flutter's `TextEditingController` provides an overridable method:
`TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing})`

### 3.1 Span Slicing Algorithm
Because user spans can overlap (e.g. word 1-5 is bold, word 3-8 is colored blue), the controller slices the text into **elementary disjoint segments** at every boundary point:

$$\text{Boundaries} = \{0, \text{text.length}\} \cup \bigcup_{s \in \text{spans}} \{s.\text{start}, s.\text{end}\}$$

1. Sort all unique boundaries in ascending order: $b_0 < b_1 < b_2 < \dots < b_n$.
2. For each segment $[b_i, b_{i+1}]$:
   - Extract the substring `text.substring(b_i, b_{i+1})`.
   - Collect all active `RichTextSpan`s covering that range.
   - Compose the combined `TextStyle` (merging bold, italic, heading size, and colors).
   - Produce a child `TextSpan`.
3. Return `TextSpan(children: childSpans)`.

### 3.2 Cursor & Edit Handling
When the user types or deletes characters at cursor position $k$:
- **Text Insertion of length $\Delta$:**
  - For spans starting after $k$: `start += Δ`, `end += Δ`.
  - For spans containing $k$: `end += Δ` (expanding the active style).
- **Text Deletion of range $[k_1, k_2]$:**
  - Spans within the deleted range contract or are removed when `start >= end`.
  - Spans after the deleted range shift backward by $k_2 - k_1$.

---

## 4. Canvas Integration & UI Architecture

### 4.1 Layer Placement in Canvas Stack
In [`NoteCanvas`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/presentation/note_canvas.dart), text boxes reside in the interactive layer:
1. **Layer 1:** Page Background (ruled / grid templates).
2. **Layer 2:** Completed Highlighters.
3. **Layer 3:** Active Highlighter.
4. **Layer 4:** Completed Pen Inks.
5. **Layer 5:** **Text Box Layer** (interactive editable containers with move/resize handles).
6. **Layer 6:** Active Pen / Fountain Pen.

*Note: Inks can be drawn directly over or around text boxes, just like in OneNote.*

### 4.2 Floating Contextual Formatting Bar
When a `NoteTextBox` gains focus:
- A compact, non-intrusive toolbar appears directly above the text box (or docked to the main toolbar).
- Quick action toggles:
  - **Heading:** Body / H1 / H2 / H3.
  - **Inline Styles:** Bold (`B`), Italic (`I`), Underline (`U`), Strikethrough (`S`).
  - **Colors:** Text Color picker & Highlighter background marker.
  - **Box Actions:** Drag-handle to reposition, Width-handle to resize, Delete box.

---

## 5. Roadmap for Advanced Student Tools

- **Phase 1 (Foundation):** `RichTextSpan`, `RichTextEditingController`, and movable `NoteTextBox` on canvas with JSON saving/loading.
- **Phase 2 (Paragraphs & Lists):** Bullet points (`•`), numbered lists (`1.`), and interactive checkboxes (`[ ]` / `[x]`).
- **Phase 3 (STEM Capabilities):**
  - **LaTeX Equations:** Inline formula chips rendered via `WidgetSpan`.
  - **Code Blocks:** Monospace blocks with language syntax highlighting and a quick-copy button.
  - **Collapsible Study Toggles:** Notion-style fold/unfold toggles for active recall quiz study.
