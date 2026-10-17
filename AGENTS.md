# OpenNote - Agent Guidelines & Architecture

## Project Overview
OpenNote is a cross-platform Flutter note-taking application designed to combine the **precision inking experience of Samsung Notes** with the **hierarchical organization of Microsoft OneNote**.

- **Inking & Canvas (Samsung Notes inspiration):** Low-latency stylus and touch drawing, pressure-aware strokes, stroke/area erasers, pen tool switching, customizable colors/thickness, and lined/grid page templates.
- **Organization (OneNote inspiration):** Hierarchical structure (Notebooks → Sections → Pages), multi-page notes, quick drawer/tab navigation, and expandable canvas.

---

## Architecture Principles: Feature-First Structure

To avoid monolithic widgets and bloated files, the codebase follows a **Feature-First** modular structure:

```
lib/
├── core/                     # Shared primitives, styling, utilities
│   ├── theme/                # Colors, palette presets, typography
│   ├── utils/                # Geometry helpers, file I/O utils
│   └── constants/            # App-wide defaults (canvas sizes, limits)
├── features/
│   ├── canvas/               # Inking & drawing engine
│   │   ├── models/           # Stroke, StrokePoint, ToolType, CanvasPage
│   │   ├── controllers/      # CanvasController / ChangeNotifier for drawing state
│   │   ├── presentation/     # NoteCanvas widget, CustomPainters, Toolbar
│   │   └── services/         # Eraser collision math, smoothing algorithms
│   ├── notebook/             # OneNote-style hierarchy & navigation
│   │   ├── models/           # Notebook, Section, NotePage, NoteDocument
│   │   ├── controllers/      # NotebookController (active note, page switching)
│   │   └── presentation/     # NotebookDrawer, PageListView, SectionTabs
│   └── storage/              # Persistence layer
│       └── note_storage_service.dart # File saving/loading (JSON / binary)
└── main.dart
```

---

## State Management & Coding Rules

1. **Decouple UI from Business & Math Logic:**
   - Widgets (`presentation/`) should only render UI and dispatch user gestures to controllers.
   - Eraser collision detection, stroke point smoothing, and math must live in pure Dart helper classes or services, never directly inside a widget's `setState()`.
   - File I/O and disk persistence must live in `storage/` services, not in widget lifecycles.

2. **Canvas Performance Rules:**
   - Always wrap canvas drawing in `RepaintBoundary` to prevent full-screen repaints.
   - Active drawing stroke (in-progress line) should be painted on an overlay painter separate from already-committed strokes to avoid redrawing all completed lines on every pointer move event.
   - Keep `paint(Canvas canvas, Size size)` lightweight: allocate no heavy objects (Paint, Path, Rect) inside the paint loop unless strictly needed. Pre-compute styles.

3. **Dart & Flutter Standards:**
   - Use Dart 3 features (records, pattern matching, switch expressions) idiomatically.
   - Maintain null safety without using `!` force-unwraps unless guaranteed.
   - Keep files small and single-purpose (< 200 lines where practical).
   - Package imports must use `package:open_note/...` without `lib/` in the path.

4. **Stylus vs. Touch Discrimination:**
   - Support `PointerDeviceKind.stylus` and `invertedStylus` (stylus eraser button/tail) with palm rejection for touch if stylus is active.

5. **Gesture Disambiguation & Overlay Layering (`Listener` vs. `GestureDetector`):**
   - **Stack & Arena Hit-Testing Precedence:** Overlay widgets placed on top of the canvas `Listener` (e.g., floating toolbars, contextual popups) will intercept hit-tests if they use opaque `GestureDetector`s or absorbing material containers.
   - **Zero Hit-Target Overlap:** Never place floating contextual toolbars where their hit-test rectangle overlaps canvas interaction handles (e.g., rotation knobs, corner resize handles). By default, position contextual toolbars on the opposite edge (e.g., below `bounds.bottom + 14` instead of above the rotation stem).
   - **Hide Overlays During Active Transforms:** Always hide contextual toolbars while any interactive transform is in progress (`controller.isTransforming`). This prevents touch interception, layout thrashing, and pointer cancellation as fingers or styluses sweep across the screen.
   - **Handle Priority in Gesture Dispatch:** In `CanvasController.onPointerDown`, explicit handle hit-testing (rotation knob, resize corners) must execute *before* toolbar bounding checks or fallback deselect/select logic.

---

## Key Documentation References
- **Product Roadmap & Feature Backlog:** Refer to [`docs/ROADMAP.md`](file:///d:/flutter-dev/projects/open_note/docs/ROADMAP.md) for milestones and task status.
- **Inking Engine Technical Architecture:** Refer to [`docs/architecture/inking_engine.md`](file:///d:/flutter-dev/projects/open_note/docs/architecture/inking_engine.md) for detailed explanations of dual-layer rendering, vector retention, undo/redo mechanics, and collision math.
- **Rich Text Engine Technical Architecture:** Refer to [`docs/architecture/rich_text_engine.md`](file:///d:/flutter-dev/projects/open_note/docs/architecture/rich_text_engine.md) for detailed explanations of the attributed-span text model, JSON serialization, boundary slicing, and canvas integration.
