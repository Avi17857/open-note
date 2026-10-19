# OpenNote 📝

OpenNote is a modern, cross-platform note-taking application built with Flutter. It combines the **fluid, low-latency inking experience of Samsung Notes** with the **hierarchical organization of Microsoft OneNote**.

Designed for stylus, touch, and desktop workflows, OpenNote bridges handwriting, sketching, and rich text editing in a unified, distraction-free digital canvas.

---

## ✨ Features

### 🖋️ Precision Inking & Drawing Engine
* **Dual-Layer Rendering:** Hardware-accelerated architecture separating finished strokes (cached in GPU memory via `RepaintBoundary`) from in-progress lines for zero-lag stylus tracking.
* **Pen Toolkit:** Pressure-sensitive fountain pen, ballpoint pen, chisel-tip highlighter with automatic translucency, and customizable stroke widths/palettes.
* **Smart Erasers:**
  * **Stroke Eraser:** Erase entire strokes with a single tap or swipe.
  * **Area / Precision Eraser:** Slice and erase only touched line segments with adjustable radius.
* **Stylus & Palm Rejection:** Native distinction between stylus inking and touch interactions (`PointerDeviceKind.stylus` / `invertedStylus`).
* **Lasso Selection & Transforms:** Select strokes and text boxes with a freeform lasso or tap. Move, scale, rotate with 15° tactile snapping, duplicate, recolor, or delete with full undo/redo history.

### ✍️ Rich Text & Typography
* **Non-Destructive Formatting:** Highlight text to apply formatting, or set active typing styles on the fly for upcoming text without altering existing notes.
* **Rich Styling:** Headings (H1, H2, H3), bold, italic, underline, strikethrough, custom text colors, and background highlight colors.
* **Stable Layout Anchoring:** Seamless focus and unfocus states with zero text jumping or layout shifting.
* **Pasteboard Support:** Freely drag text boxes and stroke selections outside the page boundary and bring them back anytime.

### 📚 OneNote-Style Hierarchy & Canvas
* **Structured Organization:** Organize notes logically by **Notebooks → Sections → Pages**.
* **Flexible Page Navigation:** Responsive drawer navigation and section tabs for fast switching.
* **Canvas Navigation:** Smooth two-finger pinch-to-zoom, pan, live zoom percentage indicators, one-tap "Reset View" (100% width fit), and directional off-screen page indicators when scrolled away.
* **Page Templates:** Configurable blank, ruled (lined), and grid backgrounds.

---

## 🏗️ Architecture

OpenNote follows a **Feature-First** modular architecture:

```
lib/
├── core/                     # Shared primitives, styling, utilities
│   ├── theme/                # Color palettes, typography, theme tokens
│   ├── utils/                # Geometry helpers, bezier smoothing, math
│   └── constants/            # App defaults (canvas sizes, limits)
├── features/
│   ├── canvas/               # Inking & drawing engine
│   │   ├── models/           # Stroke, StrokePoint, TextBox, ToolType
│   │   ├── controllers/      # CanvasController, RichTextEditingController
│   │   ├── presentation/     # NoteCanvas, CustomPainters, Toolbar, TextBoxWidget
│   │   └── services/         # Eraser math, lasso math, bezier smoothing
│   ├── notebook/             # Notebook, section, and page hierarchy
│   │   ├── models/           # Notebook, Section, NotePage, NoteDocument
│   │   ├── controllers/      # NotebookController
│   │   └── presentation/     # NotebookDrawer, SectionTabs, PageListView
│   └── storage/              # Persistence layer (JSON / local storage)
└── main.dart
```

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24+ recommended)
* Dart 3.5+

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/HasanMajid/open-note.git
   cd open-note
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   # Run on Desktop (Windows)
   flutter run -d windows

   # Run in Chrome / Web
   flutter run -d chrome

   # Run on Mobile (Android / iOS)
   flutter run
   ```

4. **Run tests & static analysis:**
   ```bash
   dart analyze
   flutter test
   ```

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
