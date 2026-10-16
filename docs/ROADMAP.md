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
- [ ] **Dual-Layer Painter:**
  - Background layer for finished strokes.
  - Foreground layer for the single stroke currently being drawn (eliminates pointer-lag).
- [ ] **Pen Toolkit:**
  - Pen types: Ballpoint pen, Fountain pen, and Semi-transparent Highlighter.
  - Stroke width adjustment (slider & presets: 1pt, 2pt, 4pt, 8pt).
  - Color palette presets + custom hex color picker.
- [ ] **Stylus & Palm Rejection:**
  - Differentiate `PointerDeviceKind.stylus` from touch gestures.
  - Support stylus eraser button and inverted stylus tail.

---

## Milestone 2: Eraser & Canvas Manipulation
- [ ] **Stroke Eraser:** Tap or swipe across any stroke to delete the entire stroke.
- [ ] **Area / Precision Eraser:** Erase only the touched segments of lines with variable eraser radius.
- [ ] **Undo / Redo Stack:** Efficient command-pattern history stack for strokes and erasures.
- [ ] **Selection / Lasso Tool:** Select drawn strokes to move, resize, or delete.

---

## Milestone 3: Page Templates & Canvas Sizing
- [ ] **Paper Backgrounds:**
  - Blank / Plain
  - Ruled / Lined (custom line spacing)
  - Grid / Graph paper
  - Dot grid
- [ ] **Canvas Modes:**
  - Standard Paged Mode (fixed A4/Letter dimensions with vertical page-scrolling).
  - Infinite Canvas Mode (panning and two-finger pinch-to-zoom).

---

## Milestone 4: OneNote Hierarchy & Navigation
- [ ] **Hierarchy Structure:**
  - `Notebook` contains multiple `Section`s.
  - `Section` contains multiple `NotePage`s.
- [ ] **OneNote-Style Navigation:**
  - Collapsible navigation drawer showing Notebooks and Sections.
  - Vertical tab / page list sidebar for switching pages rapidly.
  - Add, rename, reorder, and delete pages/sections.

---

## Milestone 5: Mixed Media & Typing
- [ ] **Text Integration:** Floating typed text boxes anywhere on the page (integrating Fleather).
- [ ] **Image Insertion:** Insert images, reposition, and draw annotations over them.
- [ ] **PDF Annotation:** Import multi-page PDF documents as background pages and annotate with pen.

---

## Milestone 6: Storage, Export & Sync
- [ ] **Robust File Format:** Structured JSON / zipped package format storing vector stroke coordinates and metadata.
- [ ] **Auto-Save & Background Flushing:** Debounced background saves so drawing never drops frames.
- [ ] **Export Options:** Export to PDF, PNG, and vector SVG.
