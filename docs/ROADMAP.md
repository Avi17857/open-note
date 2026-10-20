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
- [ ] **Arbitrary Font Sizing:**
  - Font size picker / stepper in formatting toolbar (10, 12, 14, 16, 18, 20, 24, 28, 32, 48 pt, etc.) to set fine-grained font sizes on selected text spans.

---

## Milestone 4: Page Templates, Dark Mode & Canvas Modes
- [x] **Paper Backgrounds:**
  - Blank / Plain
  - Ruled / Lined (custom line spacing)
  - Grid / Graph paper
- [ ] **Smart Dark Mode (with Invertible Inking & Light-Mode Export):**
  - Full dark theme: note page background turns dark (`#1A1A1A`), with subtle low-contrast ruled and grid lines (`#333333`).
  - Smart ink inversion: black/near-black strokes and default text dynamically invert to white/light on-screen for high contrast, while colored pens and highlighters preserve their hue.
  - Light-Mode Export Guarantee: PDF export automatically exports notes on clean white paper in standard light mode (or user-selectable), preserving ink and print readability.
- [ ] **Canvas Modes:**
  - Standard Paged Mode (fixed A4/Letter dimensions with vertical page-scrolling and page headers).
  - Infinite Canvas Mode for pages (continuous 2D pan/zoom, unbounded grid expansion, and no page breaks).
- [x] **Canvas Navigation & Orientation:**
  - OneNote-style top boundary anchor ($y \le 40\text{px}$) preventing endless scrolling into void space above Page 1.
  - Horizontal pasteboard buffer ($450\text{px}$) keeping notes anchored without wandering off-screen.
  - Dynamic "Back to Page" floating indicator pill when active page scrolls out of the viewport with smooth animated glide.
  - Live zoom % pill with one-tap reset to 100% and auto-centering.

---

## Milestone 5: OneNote Hierarchy, Tabs & Page Manager
- [ ] **Hierarchy Structure:**
  - `Notebook` contains multiple `Section`s.
  - `Section` contains multiple `NoteDocument`s / Notes.
  - Note creation options: choose between **Standard Paged Note** or **Infinite Canvas Note**.
- [ ] **OneNote-Style Navigation & Top Tabs:**
  - Horizontal tab bar at the top of the canvas for rapid switching between open notes/sections.
  - Collapsible navigation drawer showing the complete Notebook tree.
  - Add, rename, reorder, and delete notebooks, sections, and notes.
- [ ] **Page Sorter & Reorganizer (Paged Mode):**
  - Visual grid overview displaying thumbnail previews of all pages in the note.
  - Drag-and-drop to reorder pages.
  - Duplicate, delete, and insert blank pages anywhere in the sequence.
  - One-tap visual page jumping.

---

## Milestone 6: Document Import, STEM Tools & Mixed Media
- [ ] **Document Import (PDF & PowerPoint / PPTX):**
  - Import multi-page PDF documents and PPTX slide decks directly into a note.
  - Single-Page Mode: each PDF page or slide becomes a background note page with full pen/highlighter/text annotation on top, with the option to append or insert blank pages.
  - Canvas Mode: import all slides/pages onto an open 2D canvas with flexible layout.
- [ ] **LaTeX Equations:** Inline math formula chips rendered via `WidgetSpan`.
- [ ] **Syntax-Highlighted Code Blocks:** Formatted blocks with language highlighting and copy button.
- [ ] **Collapsible Study Toggles:** Active-recall question/answer toggles for students.

---

## Milestone 7: Storage, Export & Cloud Sync
- [x] **Robust File Format:** Structured JSON format (`.opennote`) storing vector stroke coordinates, attributed text spans, and base64 embedded images.
- [x] **Local-First Storage & Persistence:**
  - [x] Automatic note library scanning: on application launch, automatically load all saved `.opennote` documents from the device's local notes directory into the notebook navigation drawer.
  - [x] Debounced Auto-Save: automatically saves modified notes to local disk storage ~1.2s after user stops drawing/typing without frame drops.
  - [x] Web Local Storage Persistence: persist notes across browser reloads using local browser storage (`SharedPreferences`).
  - [x] External File Export & Import (`.opennote` / JSON): allow users to explicitly export/save a note file anywhere on their local computer (Documents, Desktop, USB) and import any `.opennote` file via file picker.
- [x] **PDF Document Export:**
  - Standard Inbound Page Bounds mode (1:1 scale matching note page dimensions).
  - Infinite Canvas / Pasteboard mode (shrink-to-fit: computes content bounding box and scales down proportionally to fit the entire canvas on the page).
  - High-fidelity vector stroke rendering: ballpoint pens, pressure-responsive fountain pen ribbons, and translucent highlighters.
  - Multi-layer composite: paper background (blank, ruled lines, grid), raster images, inking strokes over images, and rich text formatting (headings, colors, highlights, LTR/RTL).
  - Cross-platform sharing / download dialog via `Printing.sharePdf`.
- [ ] **Vector & Raster Exports:** Export to PNG image and vector SVG.
- [ ] **Cloud Synchronization Architecture (Future Account Sync):**
  - Repository / Provider abstraction (`NoteRepository`) separating local disk operations from remote cloud sync.
  - Cloud-ready metadata: UUIDs, `updatedAt` timestamps, document versioning, and soft-delete tombstones for conflict resolution.
  - User account cloud backup & multi-device sync (e.g. Supabase, Firebase, or custom backend).
