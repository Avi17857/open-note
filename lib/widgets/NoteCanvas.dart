import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;

enum PaintMode { drawing, erasing }
enum PenInputMode { stylusOnly, allowTouch }

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
  PenInputMode penInputMode = PenInputMode.stylusOnly;
  bool penDown = false;
  var eraserRadius = 20.0;

  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();

  ui.Image? _cachedImage;

  // track active pointer so multi-touch doesn't create strokes
  int? _activePointerId;

  // thinning threshold (in logical pixels)
  final double _thinningDistance = 2.5;

  // track current interaction scale so captures are higher-res when zoomed
  double _currentScale = 1.0;

  // multiplier applied to capture pixelRatio to reduce pixelation on rasterization.
  // Increase for crisper images at cost of memory/GPU.
  final double _captureExtraScale = 2.0; // tweak if you want crisper or smaller images
  final double _captureMaxMultiplier = 3.0; // cap to avoid huge captures

  void _setMode(PaintMode m) {
    setState(() {
      mode = m;
    });
  }

  void _setPenInputMode(PenInputMode p) {
    setState(() {
      penInputMode = p;
    });
  }

  bool _isAllowedInput(PointerEvent event) {
    if (penInputMode == PenInputMode.allowTouch) return true;
    return event.kind == PointerDeviceKind.stylus;
  }

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
    if (!_isAllowedInput(details)) return;
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
      _clearActivePointer();
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
    if (!_isAllowedInput(details)) return;
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
    if (!_isAllowedInput(details)) {
      _clearActivePointer();
      return;
    }
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

      // ensure the stroke renders, then rasterize into cached image at appropriate pixel ratio
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

      // compute capture multiplier to reduce pixelation when rasterizing
      final requestedMultiplier =
          math.max(1.0, _currentScale) * _captureExtraScale;
      final captureMultiplier = math.min(_captureMaxMultiplier, requestedMultiplier);

      final pixelRatio = ui.window.devicePixelRatio * captureMultiplier;
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

    final pixelRatio = ui.window.devicePixelRatio * math.max(1.0, _currentScale);
    final widthPx = (size.width * pixelRatio).ceil();
    final heightPx = (size.height * pixelRatio).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));

    // draw existing image (or fill white) onto the canvas in logical pixels
    final paint = Paint();
    if (_cachedImage != null) {
      final src = Rect.fromLTWH(
          0, 0, _cachedImage!.width.toDouble(), _cachedImage!.height.toDouble());
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
          // Pass pen mode control to toolbar
          PaintToolbar(
            setMode: _setMode,
            mode: mode,
            penInputMode: penInputMode,
            setPenInputMode: _setPenInputMode,
          ),
          Expanded(
            child: InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(500),
              minScale: 0.5,
              maxScale: 3.0,
              panEnabled: !penDown, // disable panning while drawing/erasing
              onInteractionStart: (details) {
                // nothing special
              },
              onInteractionUpdate: (details) {
                // track scale for higher-res captures to avoid pixelation when zoomed
                _currentScale = details.scale;
              },
              onInteractionEnd: (details) {
                // clamp scale to reasonable minimum
                _currentScale = math.max(1.0, _currentScale);
              },
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
                            // visual eraser overlay while erasing (real-time clear preview)
                            if (mode == PaintMode.erasing && eraserPoints.isNotEmpty)
                              CustomPaint(
                                painter: EraserLivePreviewPainter(
                                    eraserPoints, eraserRadius, _cachedImage),
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
    // Draw the image to fill the canvas logical size; request high filterQuality
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) {
    return oldDelegate.image != image;
  }
}

/// Painter that shows live erasing by compositing the cached image into a layer,
/// clearing the eraser path inside that layer (so erase appears immediately),
/// and drawing an eraser preview outline above.
class EraserLivePreviewPainter extends CustomPainter {
  final List<Offset> points;
  final double radius;
  final ui.Image? image;

  EraserLivePreviewPainter(this.points, this.radius, this.image);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final layerRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Paint the cached image into a new layer, then clear the eraser path inside that layer.
    canvas.saveLayer(layerRect, Paint());

    // draw cached image (or white background) into the layer
    if (image != null) {
      final src =
          Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble());
      final dst = Rect.fromLTWH(0, 0, size.width, size.height);
      final imagePaint = Paint()..isAntiAlias = true..filterQuality = FilterQuality.high;
      canvas.drawImageRect(image!, src, dst, imagePaint);
    } else {
      canvas.drawRect(layerRect, Paint()..color = Colors.white);
    }

    // clear stroke inside layer so it appears erased immediately
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, clearPaint);

    // restore: this composites the layer back to canvas with the cleared holes visible
    canvas.restore();

    // overlay the eraser preview UI (outline + translucent fill)
    final previewStroke = Paint()
      ..color = Colors.grey.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = true;

    final previewFill = Paint()
      ..color = Colors.grey.withOpacity(0.12)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final p in points) {
      canvas.drawCircle(p, radius, previewFill);
      canvas.drawCircle(p, radius, previewStroke);
    }

    if (points.length > 1) {
      final pathOutline = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        pathOutline.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(pathOutline, previewStroke);
    }
  }

  @override
  bool shouldRepaint(covariant EraserLivePreviewPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.radius != radius ||
        oldDelegate.image != image;
  }
}

class PaintToolbar extends StatefulWidget {
  const PaintToolbar(
      {super.key,
      required this.setMode,
      required this.mode,
      required this.penInputMode,
      required this.setPenInputMode});

  final Function setMode;
  final PaintMode mode;
  final PenInputMode penInputMode;
  final Function setPenInputMode;

  @override
  State<StatefulWidget> createState() => PaintToolbarState();
}

class PaintToolbarState extends State<PaintToolbar> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      child: Row(
        children: [
          Expanded(
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
              selected: <PaintMode>{widget.mode},
              onSelectionChanged: (Set<PaintMode> newSelection) {
                widget.setMode(newSelection.first);
              },
            ),
          ),
          const SizedBox(width: 8),
          // Pen input mode toggle
          ToggleButtons(
            isSelected: [
              widget.penInputMode == PenInputMode.stylusOnly,
              widget.penInputMode == PenInputMode.allowTouch
            ],
            onPressed: (index) {
              final newMode =
                  (index == 0) ? PenInputMode.stylusOnly : PenInputMode.allowTouch;
              widget.setPenInputMode(newMode);
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.pan_tool), // stylus / pen
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.touch_app), // touch allowed
              ),
            ],
          ),
        ],
      ),
    );
  }
}
