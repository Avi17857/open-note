import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  List<List<Offset>> lines = [];
  List<Offset> currentLine = [];

  PaintMode mode = PaintMode.drawing;
  bool penDown = false;
  var eraserRadius = 10;

  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();
  ui.Image? _cachedImage;
  int _activePointerId = -1; // Track the active stylus pointer

  void _setMode(PaintMode m) {
    setState(() {
      mode = m;
    });
  }

  void _handlePointerDown(PointerEvent details) {
    // Only start drawing with a stylus
    if (details.kind != PointerDeviceKind.stylus) return;

    // Convert to coordinates local to the canvas box
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.position);

    // Ensure the pointer is within the canvas bounds
    if (local.dx < 0 || local.dy < 0 || local.dx > box.size.width || local.dy > box.size.height) return;

    setState(() {
      if (mode == PaintMode.drawing) {
        _cachedImage = null; // Clear cached image so painting resumes
        _activePointerId = details.pointer;
        currentLine.add(local);
        penDown = true;
      } else if (mode == PaintMode.erasing) {
        // Erase using canvas-local coordinates
        lines.removeWhere(
          (line) => line.any((point) => (point - local).distance < eraserRadius),
        );
      }
    });
  }

  void _handlePointerMove(PointerEvent details) {
    // Only accept moves from the active stylus pointer
    if (details.pointer != _activePointerId) return;
    if (details.kind != PointerDeviceKind.stylus) return;

    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.position);

    // Ignore moves outside the canvas
    if (local.dx < 0 || local.dy < 0 || local.dx > box.size.width || local.dy > box.size.height) return;

    setState(() {
      if (mode == PaintMode.drawing && penDown) {
        currentLine.add(local);
      } else if (mode == PaintMode.erasing) {
        lines.removeWhere((line) => line.any((point) => (point - local).distance < eraserRadius));
      }
    });
  }

  void _handlePointerUp(PointerEvent details) {
    // Only accept up from the active stylus pointer
    if (details.pointer != _activePointerId) return;
    if (details.kind != PointerDeviceKind.stylus) return;

    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.position);

    setState(() {
      if (mode == PaintMode.drawing && penDown) {
        // Only finalize if within bounds
        if (!(local.dx < 0 || local.dy < 0 || local.dx > box.size.width || local.dy > box.size.height)) {
          currentLine.add(local);
        }
        lines = [...lines, [...currentLine]];
        currentLine = [];
        penDown = false;
        _activePointerId = -1;

        // Capture the canvas as an image after drawing
        _captureCanvasAsImage();
      }
    });
  }

  Future<void> _captureCanvasAsImage() async {
    final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      final image = await boundary.toImage(pixelRatio: 1.0);
      setState(() {
        _cachedImage = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print("REBUILDING");
    // print(lines.length);
    // print(currentLine.length);
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
              // onInteractionStart: (details) {
              //   if (mode == PaintMode.drawing) {
              //     // Prevent panning when drawing
              //     return;
              //   }
              // },
              // onInteractionUpdate: (details) {
              //   if (mode == PaintMode.drawing) {
              //     // Prevent panning when drawing
              //     return;
              //   }
              // },
              // onInteractionEnd: (details) {
              //   // Allow panning again after interaction ends
              // },
              child: Center(
                child: Listener(
                  behavior: HitTestBehavior.opaque, // Ensure pointer events are captured
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _handlePointerUp,
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
                            if (_cachedImage != null)
                              CustomPaint(
                                painter: ImagePainter(image: _cachedImage!),
                              ),
                            if (_cachedImage == null) ...[
                              Container(key: Key("container"), color: Colors.white),
                              // Painter for all past lines drawn
                              // RepaintBoundary(
                              //   child: CustomPaint(
                              //     isComplex: true,
                              //     painter: Line(lines, "1", penDown: !penDown),
                              //   ),
                              // ),
                              // Painter for only the current line
                              RepaintBoundary(
                                child: CustomPaint(
                                  isComplex: true,
                                  painter: Line([currentLine], "2"),
                                ),
                              ),
                            ],
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
    final paint =
        Paint()
          ..color = Colors.black
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    // for (var i = 0; i < points.length - 1; i++) {
    //   canvas.drawLine(points[i], points[i + 1], paint);
    // }
    // var now = new DateTime.now();
    for (final line in points) {
      for (var i = 1; i < line.length; i++) {
        canvas.drawLine(line[i - 1], line[i], paint);
      }
      // canvas.drawPoints(PointMode.points, line, paint);
    }
    // canvas.drawPoints(PointMode.points, points, paint);
    // canvas.drawLine(PointMode.points, points, paint);
    // canvas.drawVertices(Vertices(VertexMode.triangleFan, [Offset(x, y)]), BlendMode.color, paint);
  }

  @override
  bool shouldRepaint(covariant Line oldDelegate) {
    // print(oldDelegate.points.length.toString() + '---');
    // print(points.length);
    var now = DateTime.now();
    // print("repaint: " + index.toString() + " " + now.toString());
    // // print('---');
    // // return oldDelegate.points.length != points.length;
    // print(index.toString() + " " + currentLine.toString());
    // return index == currentLine;
    print(key + " " + penDown.toString() + " " + now.toString());
    return penDown;
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
    return false; // No need to repaint since the image doesn't change
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
    return Container(
      child: SegmentedButton<PaintMode>(
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

        selected: <PaintMode>{widget.mode}, // started selection
        onSelectionChanged: (Set<PaintMode> newSelection) {
          widget.setMode(newSelection.first);
        },
      ),
    );
  }
}
