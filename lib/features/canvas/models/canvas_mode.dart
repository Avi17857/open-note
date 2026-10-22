/// Defines the spatial layout mode of a note canvas.
enum CanvasMode {
  /// Standard fixed-dimension multi-page document (e.g. A4/Letter sheets) with vertical page breaks.
  paged,

  /// Unbounded 2D infinite canvas with seamless grid/ruled backgrounds and no page breaks.
  infinite;

  String get label => switch (this) {
        CanvasMode.paged => 'Standard Paged',
        CanvasMode.infinite => 'Infinite Canvas',
      };

  bool get isPaged => this == CanvasMode.paged;
  bool get isInfinite => this == CanvasMode.infinite;
}
