# OpenNote - Canvas Layout, Infinite Pasteboard & Gesture Disambiguation

## 1. Overview & Architectural Motivation

In traditional note-taking apps, canvases are either:
1. **Strictly Paged:** Hard rectangular boundaries where anything written 1 pixel outside is lost or clipped.
2. **Infinite Void:** Unbounded spaces where users easily get lost, zooming out until notes become microscopic specks in an empty screen.

OpenNote solves this through a **Hybrid Anchored Pasteboard**:
- Multi-page documents have clear, familiar page sheets ($600 \times 850\,\text{pt}$).
- Around each page sheet is an expandable **pasteboard margin** allowing scratch notes, diagrams, and reference images to sit outside the page margins without breaking the document hierarchy.
- Smooth navigation cues (e.g. live zoom reset, off-screen "Back to Page" pill) ensure the user never gets lost.

---

## 2. Geometry & Spatial Metrics

All canvas dimensions and multi-page layout metrics are defined in [`AppConstants`](file:///d:/flutter-dev/projects/open_note/lib/core/constants/app_constants.dart):

```dart
class AppConstants {
  static const Size defaultPageSize = Size(600, 850);
  static const double pageHeaderHeight = 32.0;
  static const double pageGap = 28.0;

  /// Pitch (center-to-center / origin-to-origin vertical distance) between consecutive pages
  static double get pagePitch =>
      defaultPageSize.height + pageGap + pageHeaderHeight; // 910.0
}
```

### 2.1 Multi-Page Pitch Formula
In a multi-page note, Page $k$ (0-indexed) has its local canvas origin at:
$$Y_{\text{origin}}(k) = k \cdot \text{AppConstants.pagePitch}$$

### 2.2 Pasteboard Buffering & Anchoring
- **Top Boundary Anchor ($y \le 40\,\text{px}$):** The transformation controller clamps negative vertical translation to $40\,\text{px}$. Users can never accidentally scroll miles into negative void space above Page 1.
- **Horizontal Pasteboard Buffer ($450\,\text{px}$):** The viewport allows panning up to $450\,\text{px}$ left and right of the note sheet for side annotations and scratchpads.
- **Off-Screen Page Pill:** When the note sheet translates completely outside the visible viewport, a floating "Back to Page" pill appears. Tapping it smoothly animates the canvas matrix back to center the active page.
- **Live Zoom % Pill:** Displays the active scale percentage (50% to 300%) with a single tap to reset to 100% and auto-center.

---

## 3. Gesture Disambiguation Pipeline

The canvas layer processes complex, simultaneous interactions: touch inking, stylus inking, multi-touch pinch-to-zoom, text selection, image resizing, and lasso selection.

To eliminate gesture conflicts, gestures follow a strict disambiguation pipeline:

```
Pointer Down Event
       │
       ▼
Is Stylus Active? ──────► [Yes] ──► Palm Rejection: Discard Touch Events
       │ [No]
       ▼
Active Tool == Pan? ────► [Yes] ──► Allow 1-finger / 2-finger panning
       │ [No]
       ▼
Pointer Count > 1? ─────► [Yes] ──► Multi-touch: Delegate to Pinch-to-Zoom
       │ [No]
       ▼
Hit-test Interactive Handles? (Image resize corner, lasso knob)
       │
      ├─► [Yes] ──► Begin Transform (Image resize / Lasso rotate)
      │
      └─► [No]  ──► Route to Active Tool:
                     • Inking (Pen/Highlighter): Update live stroke overlay
                     • Text: Record touch-down pos; defer spawn to PointerUp
                     • Lasso: Trace selection polygon
                     • Eraser: Slice intersecting strokes
```

### 3.1 Stylus vs. Touch Discrimination & Palm Rejection
- When a `PointerDeviceKind.stylus` or `invertedStylus` event is received, `CanvasController` sets `_isStylusActive = true` and updates `_lastStylusTime`.
- Any simultaneous touch events (`PointerDeviceKind.touch`) from the side of the palm resting on the glass are rejected immediately and not dispatched to drawing or selection routines.
- `invertedStylus` events automatically route to eraser logic regardless of the active toolbar selection.

### 3.2 Deferred Tap vs. Drag in Text Mode
When the Text tool (`ToolType.text`) is active:
- A user may touch down to pinch-to-zoom or drag-scroll.
- If a text box was spawned immediately on `onPointerDown`, pinch-to-zoom would accidentally create text boxes and pop up the on-screen soft keyboard.
- **Solution:** `onPointerDown` records `_textTouchDownPos`. During `onPointerMove`, it accumulates drag distance. Only on `onPointerUp`, if total drag distance $< 10.0\,\text{px}$ and `!_isMultiTouch`, is a new `NoteTextBox` spawned or focused.

### 3.3 Active Transform Overlay Suppression
When an interactive transform is occurring (dragging an image, resizing a text box, or rotating a lasso selection):
- Floating contextual toolbars are hidden while `controller.isTransforming == true`.
- This prevents pointer cancellation, touch interception, and layout thrashing as fingers sweep across the screen.

---

## 4. Pasteboard Hit-Testing for Mixed Media

Images and text boxes can be moved freely outside the standard $600 \times 850$ sheet:
- Canvas hit-testing in `NoteCanvas` calculates board coordinates:
  $$\text{boardX} = \frac{\text{localX} - T_x}{\text{scale}},\quad \text{boardY} = \frac{\text{localY} - T_y}{\text{scale}}$$
- Hit-testing for images, text boxes, and lasso bounds operates over the entire board plane ($-\infty < x, y < \infty$), not restricted to $[0, W] \times [0, H]$.
- Corner handles and bounding boxes render with constant screen-pixel size regardless of the canvas zoom factor by dividing handle radii by `controller.scale`.
