# OpenNote - PDF Export Engine Architecture

## 1. Overview & Architectural Motivation

OpenNote allows users to export multi-page notes to standard PDF documents. Digital notes in OpenNote are not simple text documents—they are mixed-media canvases composed of:
1. Background paper templates (Blank, Ruled, Grid).
2. Raster images (`NoteImage`) placed anywhere on or off the page.
3. Vector inking strokes (`Stroke`): ballpoint pen, pressure-sensitive fountain pen ribbons, and translucent highlighters.
4. Rich text boxes (`NoteTextBox`) with disjoint formatting spans, custom colors, highlights, and bidirectional scripts (LTR/RTL).

Exporting this composite canvas requires preserving vector crispness, correct layer occlusion (e.g. handwriting over images), and accommodating content placed both within standard page margins and in the expanded pasteboard.

---

## 2. Framing Modes: Inbound vs. Infinite Canvas

The export engine (`PdfExportService`) supports two distinct framing modes defined by `PdfExportMode`:

```dart
enum PdfExportMode {
  /// Standard 1:1 scale matching the note page bounds (600 x 850).
  /// Content outside the inbound page boundary is clipped or remains off-page.
  pageBounds,

  /// Infinite canvas mode: computes the enclosing bounding box of all content
  /// (inking strokes, text boxes, images, pasteboard notes) and scales it down
  /// proportionally to fit comfortably on the PDF page so nothing is cut off.
  shrinkToFit,
}
```

### 2.1 Inbound Mode (`pageBounds`)
- Standard note page metrics: $W = 600$, $H = 850$ points (`AppConstants.defaultPageSize`).
- Direct 1:1 coordinate mapping: $\text{scale} = 1.0$, $\text{offsetX} = 0$, $\text{offsetY} = 0$.
- Any drawing or image located inside `[0, 0, 600, 850]` maps directly to the PDF page points.

### 2.2 Infinite Canvas Mode (`shrinkToFit`)
When users write or paste images in the pasteboard outside the $600 \times 850$ note boundaries (e.g. negative coordinates $x < 0$ or extended coordinates $x > 600, y > 850$):

1. **Union Content Bounds:**
   $$B = \text{Rect.fromLTWH}(0, 0, 600, 850) \cup \bigcup \text{stroke.bounds} \cup \bigcup \text{img.bounds} \cup \bigcup \text{textBox.bounds}$$
2. **Fitting Scale:**
   Given a standard page margin $M = 24.0\,\text{pt}$, the available printable area is:
   $$W_{\text{avail}} = W_{\text{pdf}} - 2M,\quad H_{\text{avail}} = H_{\text{pdf}} - 2M$$
   $$\text{scale} = \min\left(1.0, \min\left(\frac{W_{\text{avail}}}{B.\text{width}}, \frac{H_{\text{avail}}}{B.\text{height}}\right)\right)$$
3. **Centering Offsets:**
   $$\text{offsetX} = M + \frac{W_{\text{avail}} - (B.\text{width} \cdot \text{scale})}{2} - (B.\text{left} \cdot \text{scale})$$
   $$\text{offsetY} = M + \frac{H_{\text{avail}} - (B.\text{height} \cdot \text{scale})}{2} - (B.\text{top} \cdot \text{scale})$$
4. **Visual Page Cue:**
   In `shrinkToFit` mode, a subtle paper border is drawn at `(offsetX, offsetY, 600 * scale, 850 * scale)` against a light pasteboard background (`#F5F5F7`), showing the user the original page bounds and how their pasteboard notes surround it.

---

## 3. Coordinate System & Inverted-Y Mapping

In Flutter's `Canvas`, the origin $(0, 0)$ is at the **top-left**, with $Y$ increasing downwards.
In PDF graphics (`PdfGraphics`), the origin $(0, 0)$ is at the **bottom-left**, with $Y$ increasing upwards.

To map any transformed point $(x_{\text{canvas}}, y_{\text{canvas}})$ into PDF space:

$$X_{\text{pdf}} = (x_{\text{canvas}} \cdot \text{scale}) + \text{offsetX}$$
$$Y_{\text{pdf}} = H_{\text{page}} - \left[(y_{\text{canvas}} \cdot \text{scale}) + \text{offsetY}\right]$$

For widget positioning inside `pw.Stack`, `pw.Positioned(left: ..., top: ...)` operates with top-left coordinates, matching Flutter's `Positioned` widget.

---

## 4. Layer Ordering & Vector Inking Pipeline

PDF generation follows strict layer ordering to match on-screen drawing semantics:

```
┌────────────────────────────────────────────────────────┐
│ 4. Rich Text Boxes (pw.RichText in pw.Positioned)     │
├────────────────────────────────────────────────────────┤
│ 3. Vector Inking Pass 2 (Pens & Fountain Pen Ribbons)  │ <-- Hand-drawn notes over images
├────────────────────────────────────────────────────────┤
│ 2. Vector Inking Pass 1 (Translucent Highlighters)     │
├────────────────────────────────────────────────────────┤
│ 1. Raster Images (pw.Image from MemoryImage)           │ <-- Placed photos & diagrams
├────────────────────────────────────────────────────────┤
│ 0. Background Paper Sheet (Ruled / Grid / Blank lines) │
└────────────────────────────────────────────────────────┘
```

### 4.1 Inking Fidelity
- **Ballpoint Pen:** Rendered using `canvas.moveTo()` / `canvas.lineTo()` with `PdfLineCap.round` and `PdfLineJoin.round`. Single-point taps draw a filled circle with radius $r = \frac{\text{width}}{2}$.
- **Highlighter:** Rendered with `alpha = 0.38` and `PdfLineCap.square` in Pass 1 *behind* darker pen ink so highlighted text remains legible.
- **Fountain Pen Ribbons:** Pressure sensitivity is preserved by calculating the perpendicular normal vector between consecutive points $p_i, p_{i+1}$, constructing a quadrilateral polygon ribbon, and filling it with `canvas.fillPath()` alongside circular join caps.

---

## 5. Attributed Text & Disjoint Span Slicing

Text formatting spans (`RichTextSpan`) in `NoteTextBox` can overlap arbitrarily (e.g. a Bold span covering chars 0–10 and an Italic span covering chars 5–15). Standard PDF rich text trees require non-overlapping hierarchical or disjoint text spans.

The export service applies **Elementary Boundary Decomposition**:
1. Collect all span start and end points into a sorted set of unique offsets:
   $$\mathcal{B} = \{0, N\} \cup \{s.\text{start}, s.\text{end} \mid s \in \text{spans}\}$$
2. For each disjoint slice $[b_i, b_{i+1}]$:
   - Identify all active styles covering that slice (bold, italic, underline, strikethrough, heading font size, color, background highlight).
   - Emit a single `pw.TextSpan` with merged styles.
3. Wrap in `pw.Directionality(textDirection: ...)` to honor Right-to-Left (Arabic/Hebrew) scripts.

---

## 6. Typography & Offline Resilience

- TrueType fonts are fetched dynamically via `PdfGoogleFonts.robotoRegular()`, `robotoBold()`, etc., with a 1-second timeout.
- Loaded font instances are cached in memory using a Dart 3 record:
  ```dart
  static (pw.Font, pw.Font, pw.Font, pw.Font)? _cachedFonts;
  ```
- If network access is unavailable (e.g., offline devices or CI test runners), the service falls back instantly to standard built-in Type 1 Helvetica fonts (`pw.Font.helvetica()`).
- When using fallback Type 1 fonts (Latin-1 encoding), characters outside Latin-1 are sanitized to avoid PDF generation exceptions.

---

## 7. Cross-Platform Sharing

The export flow integrates `Printing.sharePdf(bytes: bytes, filename: filename)`:
- **Web:** Directly invokes browser download of the generated PDF file blob.
- **Desktop (Windows, macOS, Linux):** Opens native file save dialogs or share mechanisms.
- **Mobile (iOS, Android):** Triggers the native platform share sheet.
