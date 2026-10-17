# Architecture Decision Record: Digital Inking Engine

**Status:** Accepted  
**Scope:** `lib/features/canvas/`  
**Related Components:** [`CanvasController`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/controllers/canvas_controller.dart), [`NoteCanvas`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/presentation/note_canvas.dart), [`Stroke`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/models/stroke.dart), [`EraserService`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/services/eraser_service.dart)

---

## 1. Context & The Problem

Digital note-taking applications (like Samsung Notes, GoodNotes, and Apple Notes) require ultra-low-latency inking (60Hz–120Hz) so that the digital ink appears directly under the stylus tip without trailing behind.

### The Pitfalls of Common Approaches:

1. **Naive Single-Layer Redraw ($O(N)$ lag):**
   - Redrawing all committed strokes on every pointer move event causes frame drops once a document contains dozens or hundreds of strokes.
2. **Rasterization / "Baking" into Bitmap Images (Rejected):**
   - Converting past strokes into a flat `ui.Image` (PNG/bitmap texture) solves redraw lag, but creates fatal limitations:
     - **Breaks Undo/Redo:** To undo a line, the app would have to store massive full-screen bitmap snapshots in memory for every stroke.
     - **Breaks Stroke Erasing:** The computer loses vector identity and can no longer detect which individual stroke was tapped to delete it.
     - **Pixelation on Zoom:** Raster images blur and lose crispness when zooming in.
     - **Disables Selection & Lasso:** Individual lines cannot be selected, recolored, or moved.

---

## 2. The Decision: Dual-Layer Vector Rendering with GPU Caching

We preserve **100% vector fidelity** while achieving **$O(1)$ live drawing performance** by separating the visual rendering pipeline from data management.

```
                    User Pointer Move (120 Hz)
                                │
                                ▼
         ┌──────────────────────────────────────────────┐
         │          Active Stroke Overlay               │
         │       (ActiveStrokePainter - 120 FPS)        │
         └──────────────────────────────────────────────┘
                                │
                      Pointer Up (Stroke Complete)
                                │
                                ▼
         ┌──────────────────────────────────────────────┐
         │     Background Completed Strokes Layer       │
         │      (RepaintBoundary GPU Texture Cache)     │
         └──────────────────────────────────────────────┘
                                │
         ┌──────────────────────────────────────────────┐
         │             Paper Background                 │
         │           (Ruled, Grid, Plain)               │
         └──────────────────────────────────────────────┘
```

### Key Technical Mechanisms:

### A. Independent Active Stroke Notifier
- In [`CanvasController`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/controllers/canvas_controller.dart), pointer move events **never** invoke `notifyListeners()`.
- Instead, moving the pen updates a dedicated `ValueNotifier<List<Offset>> currentStrokeNotifier`.
- Only the [`ActiveStrokePainter`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/presentation/painters/active_stroke_painter.dart) widget rebuilds during drag. The rest of the widget tree (toolbar, background, completed strokes) remains completely idle.

### B. GPU Layer Caching via `RepaintBoundary`
- In [`NoteCanvas`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/presentation/note_canvas.dart), [`CompletedStrokesPainter`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/presentation/painters/completed_strokes_painter.dart) is wrapped in a `RepaintBoundary`.
- Flutter's rendering pipeline (Skia/Impeller) caches the rasterized display list of completed strokes into GPU memory. 
- As long as `widget.controller.strokes` does not change, Flutter blits the cached GPU texture rather than re-executing `paint()`.

### C. Stroke Commitment on Pointer Up
- When the user lifts the stylus:
  1. Points are compressed using [`Stroke.compressPoints()`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/models/stroke.dart#L44-L61) to remove redundant collinear points.
  2. The completed [`Stroke`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/models/stroke.dart) is appended to `_strokes`.
  3. `currentStrokeNotifier.value = []` clears the active tip overlay.
  4. `notifyListeners()` is fired **once**, instructing the background `RepaintBoundary` to repaint and update its GPU cache.

---

## 3. Undo / Redo Architecture

Because all strokes remain vector objects inside `List<Stroke> _strokes`, undo and redo operate with zero image manipulation:

1. **State Preservation:** Prior to appending a new stroke or erasing strokes, the current list reference is pushed to `_undoStack`.
2. **Undo Action:** Pops the previous stroke list from `_undoStack`, pushes the current list to `_redoStack`, and updates `_strokes`.
3. **Single Repaint:** Calling `notifyListeners()` repaints the background painter **exactly once**.

---

## 4. Eraser Collision Math

To keep the eraser instant even with hundreds of strokes, [`EraserService`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/services/eraser_service.dart) uses a two-phase collision test:

1. **Broad-Phase ($O(1)$ Rejection):**
   - Each [`Stroke`](file:///d:/flutter-dev/projects/open_note/lib/features/canvas/models/stroke.dart) lazily calculates and caches its axis-aligned bounding box `bounds`.
   - If `stroke.bounds.inflate(eraserRadius).contains(pointer)` is false, the stroke is skipped immediately without testing coordinates.
2. **Narrow-Phase (Line Segment Distance):**
   - Computes point-to-segment distance using vector projection:
     $$\text{projection } t = \text{clamp}\left(\frac{(P - V) \cdot (W - V)}{\|W - V\|^2}, 0, 1\right)$$
   - If distance $\le \text{eraserRadius}$, the stroke is marked for removal.

---

## 5. Rules for Future Modifications

1. **Never flatten or convert strokes to a bitmap image (`ui.Image`).** Maintain discrete `Stroke` data models at all times.
2. **Never call `notifyListeners()` on pointer move.** Live coordinates must flow through `currentStrokeNotifier`.
3. **Always preserve `RepaintBoundary` around `CompletedStrokesPainter`.**
