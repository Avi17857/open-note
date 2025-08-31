import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;

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
  // only keep one live stroke in memory
  List<Offset> currentLine = [];

  // eraser path while erasing (visual only until applied to cached image)
  List<Offset> eraserPoints = [];

  PaintMode mode = PaintMode.drawing;
  bool penDown = false;
  var eraserRadius = 20.0;

  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();

  ui.Image? _cachedImage;

  // track active pointer so multi-touch doesn't create strokes
  int? _activePointerId;

  // thinning threshold (in logical pixels)
  final double _thinningDistance = 2.5;

  void _setMode(PaintMode m) {
    setState(() {
      mode = m;
    });
  }

  bool _isStylus(PointerEvent event) =>
      event.kind == PointerDeviceKind.stylus;

  double _dist(Offset a, Offset b) => (a - b).distance;

  void _addPointThinned(List<Offset> list, Offset p) {
    if (list.isEmpty) {
      list.add(p);
      return;
    }
    if (_dist(list.last, p) >= _thinningDistance) {
      list.add(p);
    }
  }

  void _handlePointerDown(PointerEvent details) {
    // Strictly stylus-only
    // if (!_isStylus(details)) return;
    // If another pointer is active ignore additional pointers
    if (_activePointerId != null) return;
    _activePointerId = details.pointer;

    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.position);

    // ensure inside canvas
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > box.size.width ||
        local.dy > box.size.height) {
      return;
    }

    setState(() {
      penDown = true;
      if (mode == PaintMode.drawing) {
        // start only one live stroke
        currentLine = [local];
      } else if (mode == PaintMode.erasing) {
        eraserPoints = [local];
      }
    });
  }

  void _handlePointerMove(PointerEvent details) {
    // strictly stylus and only the active pointer
    // if (!_isStylus(details)) return;
    if (_activePointerId == null || details.pointer != _activePointerId) return;

    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.position);

    // ignore moves outside the canvas bounds
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > box.size.width ||
        local.dy > box.size.height) {
      return;
    }

    setState(() {
      if (mode == PaintMode.drawing && penDown) {
        _addPointThinned(currentLine, local);
      } else if (mode == PaintMode.erasing && penDown) {
        _addPointThinned(eraserPoints, local);
      }
    });
  }

  Future<void> _handlePointerUp(PointerEvent details) async {
    // strictly stylus and only the active pointer
    // if (!_isStylus(details)) {
    //   _clearActivePointer();
    //   return;
    // }
    if (_activePointerId == null || details.pointer != _activePointerId) {
      return;
    }

    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      _clearActivePointer();
      return;
    }
    final local = box.globalToLocal(details.position);

    if (mode == PaintMode.drawing && penDown) {
      // finalize stroke only if inside bounds
      if (!(local.dx < 0 ||
          local.dy < 0 ||
          local.dx > box.size.width ||
          local.dy > box.size.height)) {
        _addPointThinned(currentLine, local);
      }

      setState(() {
        penDown = false;
      });

      // ensure the stroke renders, then rasterize into cached image
      await SchedulerBinding.instance.endOfFrame;
      await _captureCanvasAsImage();

      setState(() {
        currentLine = [];
      });
    } else if (mode == PaintMode.erasing && penDown) {
      // finalize eraser path and apply to the cached image
      if (!(local.dx < 0 ||
          local.dy < 0 ||
          local.dx > box.size.width ||
          local.dy > box.size.height)) {
        _addPointThinned(eraserPoints, local);
      }

      setState(() {
        penDown = false;
      });

      await SchedulerBinding.instance.endOfFrame;
      await _applyEraserToImage(eraserPoints);

      setState(() {
        eraserPoints = [];
      });
    }

    _clearActivePointer();
  }

  void _handlePointerCancel(PointerEvent details) {
    if (_activePointerId == null || details.pointer != _activePointerId) return;
    setState(() {
      penDown = false;
      currentLine = [];
      eraserPoints = [];
    });
    _clearActivePointer();
  }

  void _clearActivePointer() {
    _activePointerId = null;
  }

  Future<void> _captureCanvasAsImage() async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final pixelRatio = ui.window.devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);

      // dispose previous image to free memory
      _cachedImage?.dispose();

      setState(() {
        _cachedImage = image;
      });
    } catch (e) {
      debugPrint('capture error: $e');
    }
  }

  Future<void> _applyEraserToImage(List<Offset> points) async {
    if (points.isEmpty) return;
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final size = box.size;
    if (size.isEmpty) return;

    final pixelRatio = ui.window.devicePixelRatio;
    final widthPx = (size.width * pixelRatio).ceil();
    final heightPx = (size.height * pixelRatio).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));

    // draw existing image (or fill white) onto the canvas in logical pixels
    final paint = Paint();
    if (_cachedImage != null) {
      final src =
          Rect.fromLTWH(0, 0, _cachedImage!.width.toDouble(), _cachedImage!.height.toDouble());
      final dst = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(_cachedImage!, src, dst, paint);
    } else {
      // empty white background
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.white);
    }

    // build path for eraser strokes
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      if (i == 0) {
        path.moveTo(points[i].dx, points[i].dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }

    // Erase using clear blend mode (composite onto recorded picture)
    final eraserPaint = Paint()
      ..blendMode = BlendMode.clear
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeWidth = eraserRadius * 2;

    canvas.drawPath(path, eraserPaint);

    final picture = recorder.endRecording();
    final ui.Image newImage = await picture.toImage(widthPx, heightPx);

    // replace cached image
    _cachedImage?.dispose();
    setState(() {
      _cachedImage = newImage;
    });
  }

  @override
  void dispose() {
    _cachedImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: keep rebuilds minimal; avoid expensive prints in production
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
              panEnabled: !penDown, // disable panning while drawing/erasing
              child: Center(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  child: Center(
                    child: Container(
                      width: 600,
                      height: 800,
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
                            // rasterized finished strokes
                            if (_cachedImage != null)
                              CustomPaint(
                                painter: ImagePainter(image: _cachedImage!),
                                size: Size.infinite,
                              ),
                            // live stroke being drawn (single list)
                            if (mode == PaintMode.drawing)
                              CustomPaint(
                                isComplex: true,
                                painter: Line([currentLine], "live", penDown: penDown),
                                size: Size.infinite,
                              ),
                            // visual eraser overlay while erasing (not applied until pointer up)
                            if (mode == PaintMode.erasing && eraserPoints.isNotEmpty)
                              CustomPaint(
                                painter: EraserPreviewPainter(eraserPoints, eraserRadius),
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
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (final line in points) {
      for (var i = 1; i < line.length; i++) {
        canvas.drawLine(line[i - 1], line[i], paint);
      }
      // if single point (tap) show a dot
      if (line.length == 1) {
        canvas.drawCircle(line.first, paint.strokeWidth / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant Line oldDelegate) {
    if (!identical(oldDelegate.points, points)) return true;
    if (oldDelegate.penDown != penDown) return true;
    return false;
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;

  ImagePainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    // Draw the image to fill the canvas logical size
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) {
    return oldDelegate.image != image;
  }
}

class EraserPreviewPainter extends CustomPainter {
  final List<Offset> points;
  final double radius;

  EraserPreviewPainter(this.points, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = true;

    final fill = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // draw translucent circles along eraser points for preview
    for (final p in points) {
      canvas.drawCircle(p, radius, fill);
      canvas.drawCircle(p, radius, paint);
    }

    // preview path line
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant EraserPreviewPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.radius != radius;
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
