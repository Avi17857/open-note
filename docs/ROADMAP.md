# OpenNote - Product Roadmap

OpenNote bridges the gap between the fluid inking experience of **Samsung Notes** and the organizational power of **Microsoft OneNote**.

---

## Architecture Milestone 0: Foundation & Refactoring (Completed)
- [x] Fix existing compilation and import errors on `refactor` branch.
- [x] Split monolithic [`NoteCanvas.dart`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/presentation/note_canvas.dart) into:
  - `Stroke` & `StrokePoint` data models.
  - `CanvasController` (drawing state, active tool, line collection).
  - `EraserService` (bounding box & line-segment intersection math).
  - `NoteCanvas` view (gesture capture + `RepaintBoundary` rendering).
- [x] Clean up redundant folders and establish the `lib/features/` structure.

---

## Milestone 1: Samsung Notes Inking Experience
- [x] **Dual-Layer Painter:** *(Documented in [`docs/architecture/inking_engine.md`](file:///d:/flutter-dev/projects/open_note/docs/architecture/inking_engine.md))*
  - Background layer for finished strokes (`RepaintBoundary` GPU texture cache).
  - Foreground layer for the single stroke currently being drawn (`ActiveStrokePainter` with zero pointer-lag).
- [x] **Pen Toolkit:**
  - [x] Semi-transparent Highlighter with chisel square caps & auto-translucency.
  - [x] Stroke width adjustment (toolbar button, quick preset chips & fine-tuning slider).
  - [x] Tool-specific memory (independent pen vs. highlighter width and palettes).
  - [x] Pen types: Ballpoint vs. Fountain pen (pressure-based tapering).
  - [x] Custom hex/HSV color wheel picker.
- [x] **Stylus & Palm Rejection:**
  - [x] Differentiate `PointerDeviceKind.stylus` from touch gestures (palm rejection).
  - [x] Support stylus eraser button and inverted stylus tail.

---

## Milestone 2: Eraser & Canvas Manipulation
- [x] **Stroke Eraser:** Tap or swipe across any stroke to delete the entire stroke.
- [x] **Area / Precision Eraser:** Erase only the touched segments of lines with variable eraser radius.
- [x] **Undo / Redo Stack:** Efficient command-pattern history stack for strokes and erasures.
- [x] **Selection / Lasso Tool:** Freeform lasso and single-tap selection with bounding box, move, 4 corner resize handles, freeform rotation handle (with tactile 15° angle snapping), 90° quick rotate, smart duplicate offset, recoloring, deletion, and full undo/redo history.

---

## Milestone 3: Freeform Rich Text Engine
*(Documented in [`docs/architecture/rich_text_engine.md`](file:///d:/flutter-dev/projects/open_note/docs/architecture/rich_text_engine.md))*
- [x] **Attributed-Span Model:**
  - `RichTextSpan` and `NoteTextBox` models with JSON serialization/deserialization.
  - Native `RichTextEditingController` with boundary slicing and real-time formatting.
- [x] **Classic Formatting Toolbar:**
  - Inline toggles: Bold, Italic, Underline, Strikethrough.
  - Heading selector: Body, H1, H2, H3.
  - Text color and background highlighter picker.
- [x] **Right-to-Left (RTL) Language Support:**
  - Automatic bidirectional script detection for Arabic, Hebrew, Persian, and Urdu.
  - Native RTL text direction and right-alignment with dual left/right resize handles.
  - One-tap LTR / RTL toggle button in the docked text formatting bar.
- [x] **Images & Clipboard Integration:**
  - Native clipboard image paste (`Ctrl+V` / `Cmd+V`) via `super_clipboard`.
  - Image file upload picker (`file_picker`) from desktop/mobile.
  - Interactive image manipulation: 4-corner aspect ratio resizing, canvas dragging, layer reordering (Bring to Front / Send to Back), and deletion.
  - Dual-layer inking: pen, fountain pen, and highlighter strokes draw seamlessly *over* placed images for handwritten annotation.
- [x] **Canvas Text Container:**
  - `T` (Text) tool on main toolbar: tap canvas to spawn a new text box.
  - Borderless editing with subtle drag-handles to move and resize anywhere on the page.
  - Native soft-keyboard and Samsung S-Pen handwriting-to-text integration.

---

## Milestone 4: Page Templates & Canvas Sizing
- [ ] **Paper Backgrounds:**
  - Blank / Plain
  - Ruled / Lined (custom line spacing)
  - Grid / Graph paper
  - Dot grid
- [ ] **Canvas Modes:**
  - Standard Paged Mode (fixed A4/Letter dimensions with vertical page-scrolling).
  - Infinite Canvas Mode (panning and two-finger pinch-to-zoom).
- [x] **Canvas Navigation & Orientation:**
  - OneNote-style top boundary anchor ($y \le 40\text{px}$) preventing endless scrolling into void space above Page 1.
  - Horizontal pasteboard buffer ($450\text{px}$) keeping notes anchored without wandering off-screen.
  - Dynamic "Back to Page" floating indicator pill when active page scrolls out of the viewport with smooth animated glide.
  - Live zoom % pill with one-tap reset to 100% and auto-centering.

---

## Milestone 5: OneNote Hierarchy & Navigation
- [ ] **Hierarchy Structure:**
  - `Notebook` contains multiple `Section`s.
  - `Section` contains multiple `NotePage`s.
- [ ] **OneNote-Style Navigation:**
  - Collapsible navigation drawer showing Notebooks and Sections.
  - Vertical tab / page list sidebar for switching pages rapidly.
  - Add, rename, reorder, and delete pages/sections.

---

## Milestone 6: STEM Tools & Mixed Media
- [ ] **LaTeX Equations:** Inline math formula chips rendered via `WidgetSpan`.
- [ ] **Syntax-Highlighted Code Blocks:** Formatted blocks with language highlighting and copy button.
- [ ] **Collapsible Study Toggles:** Active-recall question/answer toggles for students.
- [ ] **Image Insertion:** Insert images, reposition, and annotate with pen.
- [ ] **PDF Annotation:** Import multi-page PDF documents as background pages and annotate with pen.

---

## Milestone 7: Storage, Export & Sync
- [ ] **Robust File Format:** Structured JSON / zipped package format storing vector stroke coordinates and text box spans.
- [ ] **Auto-Save & Background Flushing:** Debounced background saves so drawing never drops frames.
- [ ] **Export Options:** Export to PDF, PNG, and vector SVG.
