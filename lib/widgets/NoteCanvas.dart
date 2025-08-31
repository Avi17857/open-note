import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

enum PaintMode { drawing, erasing }

const List<Icon> paintModeIcons = [Icon(Icons.create), Icon(Icons.edit_off)];

class NoteCanvas extends StatefulWidget {
  const NoteCanvas({super.key});

  @override
  State<StatefulWidget> createState() {
    return _NoteCanvasState();
  }
}

class _NoteCanvasState extends State<NoteCanvas> {
  // removed multi-line history to keep only the active stroke in memory,
  // finished strokes are rasterized into _cachedImage
  List<Offset> currentLine = [];

  PaintMode mode = PaintMode.drawing;
  bool penDown = false;
  var eraserRadius = 10;

  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();

  ui.Image? _cachedImage;

  void _setMode(PaintMode m) {
    setState(() {
      mode = m;
    });
  }

  void _handlePointerDown(PointerEvent details) {
    // Only start drawing with a stylus
    // if (details.kind != PointerDeviceKind.stylus) return;

    // Convert to coordinates local to the canvas box
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.position);

    // Ensure the pointer is within the canvas bounds
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > box.size.width ||
        local.dy > box.size.height) {
      return;
    }

    setState(() {
      if (mode == PaintMode.drawing) {
        // start a new single current line
        currentLine = [local];
        penDown = true;
      } else if (mode == PaintMode.erasing) {
        // Eraser not implemented against rasterized image here.
        // You can implement erasing by drawing transparent strokes onto a new image.
      }
    });
  }

  void _handlePointerMove(PointerEvent details) {
    // Only accept stylus moves
    // if (details.kind != PointerDeviceKind.stylus) return;

    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.position);

    // Ignore moves outside the canvas
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > box.size.width ||
        local.dy > box.size.height) {
      return;
    }

    setState(() {
      if (mode == PaintMode.drawing && penDown) {
        currentLine.add(local);
      } else if (mode == PaintMode.erasing) {
        // Erasing against raster image would require compositing onto a new image.
      }
    });
  }

  Future<void> _handlePointerUp(PointerEvent details) async {
    // Only accept stylus up
    // if (details.kind != PointerDeviceKind.stylus) return;

    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.position);

    if (mode == PaintMode.drawing && penDown) {
      // finalize stroke only if inside bounds
      if (!(local.dx < 0 ||
          local.dy < 0 ||
          local.dx > box.size.width ||
          local.dy > box.size.height)) {
        currentLine.add(local);
      }

      // ensure the current stroke is painted in the next frame, then capture
      setState(() {
        penDown = false;
      });

      // Wait until the frame paints the stroke, then capture the boundary.
      // SchedulerBinding ensures we wait for end of frame.
      await SchedulerBinding.instance.endOfFrame;
      await _captureCanvasAsImage();

      // clear currentLine after rasterizing into _cachedImage
      setState(() {
        currentLine = [];
      });
    }
  }

  Future<void> _captureCanvasAsImage() async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // choose device pixel ratio for better quality if desired
      final pixelRatio = ui.window.devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);

      // dispose previous image to free memory
      _cachedImage?.dispose();

      setState(() {
        _cachedImage = image;
      });
    } catch (e) {
      // ignore capture errors in debug, or log if needed
      debugPrint('capture error: $e');
    }
  }

  @override
  void dispose() {
    _cachedImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("REBUILDING");
    return Center(
      key: Key('NotePage'),
      child: Column(
        children: [
          PaintToolbar(setMode: _setMode, mode: mode),
          Expanded(
            child: InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(500),
              minScale: 0.5,
              maxScale: 2.0,
              panEnabled: !penDown, // Disable panning while drawing
              child: Center(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: (details) => _handlePointerUp(details),
                  child: Center(
                    child: Container(
                      width: 600, // Fixed width for the drawing area
                      height: 800, // Fixed height for the drawing area
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            blurRadius: 4.0,
                            spreadRadius: 2.0,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                      key: _canvasKey,
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: Stack(
                          key: Key("canvasStack"),
                          children: [
                            // rasterized background of finished strokes
                            if (_cachedImage != null)
                              CustomPaint(
                                painter: ImagePainter(image: _cachedImage!),
                                size: Size.infinite,
                              ),
                            // live stroke being drawn (only one list of points)
                            CustomPaint(
                              isComplex: true,
                              painter: Line([currentLine], "live", penDown: penDown),
                              size: Size.infinite,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Line extends CustomPainter {
  List<List<Offset>> points;
  bool penDown;
  String key;

  @override
  Line(this.points, this.key, {this.penDown = true}) : super();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (final line in points) {
      for (var i = 1; i < line.length; i++) {
        canvas.drawLine(line[i - 1], line[i], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant Line oldDelegate) {
    // repaint when the live points change (or when drawing)
    if (identical(oldDelegate.points, points) == false) return true;
    if (oldDelegate.penDown != penDown) return true;
    return false;
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;

  ImagePainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the image onto the canvas
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) {
    return oldDelegate.image != image;
  }
}

class PaintToolbar extends StatefulWidget {
  const PaintToolbar({super.key, required this.setMode, required this.mode});

  final Function setMode;
  final PaintMode mode;

  @override
  State<StatefulWidget> createState() => PaintToolbarState();
}

class PaintToolbarState extends State<PaintToolbar> {
  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PaintMode>(
      segments: [
        ButtonSegment<PaintMode>(
          value: PaintMode.drawing,
          icon: paintModeIcons[0],
        ),
        ButtonSegment<PaintMode>(
          value: PaintMode.erasing,
          icon: paintModeIcons[1],
        ),
      ],
      multiSelectionEnabled: false,
      emptySelectionAllowed: false,
      selected: <PaintMode>{widget.mode},
      onSelectionChanged: (Set<PaintMode> newSelection) {
        widget.setMode(newSelection.first);
      },
    );
  }
}
