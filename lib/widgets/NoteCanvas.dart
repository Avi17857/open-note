
import 'package:flutter/material.dart';

import 'package:open_note/lib/core/models/note_model.dart';

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
  List<Offset> currentLine = [];

  // Future<void> loadNote() async {
  //   try {
      
      
  //   } catch (e) {
  //     print("Error reading note: " + e.toString());
  //   }
  // }

  // @override
  // void initState() {
  //   super.initState();

  // }

      @override
      void initState() {
        super.initState();
        readNote().then((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }


  PaintMode mode = PaintMode.drawing;
  bool penDown = false;
  double eraserRadius = 10.0;

  void _setMode(PaintMode m) {
    setState(() {
      mode = m;
    });
  }

  void _handlePointerDown(PointerEvent details) {
    setState(() {
      var x = details.localPosition.dx;
      var y = details.localPosition.dy;
      if (mode == PaintMode.drawing) {
        //&& details.kind == PointerDeviceKind.stylus
        currentLine.add(Offset(x, y));
        penDown = true;
      }
      if (mode == PaintMode.erasing) {
        // penDown = true;
        lines.removeWhere((line) {
          for (int j = 0; j < line.length; j++) {
            if (j + 1 != line.length) {
              if (((details.localPosition >
                          (line[j] -
                              Offset(
                                eraserRadius,
                                eraserRadius,
                              )) &&
                      details.localPosition <
                          (line[j + 1] +
                              Offset(
                                eraserRadius,
                                eraserRadius,
                              ))) ||
                  (details.localPosition <
                          (line[j] +
                              Offset(
                                eraserRadius,
                                eraserRadius,
                              )) &&
                      details.localPosition >
                          (line[j + 1] -
                              Offset(
                                eraserRadius,
                                eraserRadius,
                              ))))) {
                print("DELETING LINE");
                return true;
              }
            }
            if ((line[j] - details.localPosition).distance < eraserRadius) {
              return true;
            }
          }
          return false;
        });
      }
    });
  }

  void _handlePointerMove(PointerEvent details) {
    setState(() {
      var x = details.localPosition.dx;
      var y = details.localPosition.dy;
      if (mode == PaintMode.drawing) {
        // && penDown && details.kind == PointerDeviceKind.stylus
        currentLine.add(Offset(x, y));
      }
      if (mode == PaintMode.erasing) {
        lines.removeWhere((line) {
          for (int j = 0; j < line.length; j++) {
            if (j + 1 != line.length) {
              if (((details.localPosition >
                          (line[j] -
                              Offset(
                                eraserRadius,
                                eraserRadius,
                              )) &&
                      details.localPosition <
                          (line[j + 1] +
                              Offset(
                                eraserRadius,
                                eraserRadius,
                              ))) ||
                  (details.localPosition <
                          (line[j] +
                              Offset(
                                eraserRadius,
                                eraserRadius,
                              )) &&
                      details.localPosition >
                          (line[j + 1] -
                              Offset(
                                eraserRadius,
                                eraserRadius,
                              ))))) {
                print("DELETING LINE");
                return true;
              }
            }
            if ((line[j] - details.localPosition).distance < eraserRadius) {
              return true;
            }
          }
          return false;
        });
      }
    });
  }

  void _handlePointerUp(PointerEvent details) {
    var x = details.localPosition.dx;
    var y = details.localPosition.dy;
    setState(() {
      if (mode == PaintMode.drawing) {
        // && penDown && details.kind == PointerDeviceKind.stylus
        currentLine.add(Offset(x, y));
        lines.add(_compressLine(currentLine));
        // [
        //   ...lines,
        //   [..._compressLine(currentLine)],
        // ]
        currentLine = [];
        penDown = false;
        print("LINES LENGTH: " + lines.length.toString());
      }
    });
  }

  List<Offset> _compressLine(List<Offset> line) {
    List<Offset> newLine = [];
    const inc = 8;
    if (line.length < inc * 2) {
      return line;
    }
    for (var i = inc; i < line.length - 1; i += inc) {
      if ((line[i - inc] - line[i]).distance > 0.5) {
        newLine.add(line[i - inc]);
      }
    }
    newLine.add(line[line.length - 1]);
    return newLine;
  }

  @override
  Widget build(BuildContext context) {
    // print("REBUILDING");
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
                  behavior:
                      HitTestBehavior
                          .opaque, // Ensure pointer events are captured
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _handlePointerUp,
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
                    child: Stack(
                      key: Key("canvasStack"),
                      children: [
                        Container(key: Key("container"), color: Colors.white),
                        // Painter for all past lines drawn
                        RepaintBoundary(
                          child: CustomPaint(
                            isComplex: true,
                            painter: Line(lines, "1", penDown: !penDown),
                          ),
                        ),
                        // Painter for only the current line
                        RepaintBoundary(
                          child: CustomPaint(
                            isComplex: true,
                            painter: Line([_compressLine(currentLine)], "2"),
                          ),
                        ),
                      ],
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
  List<List<Offset>>? points;
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
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
    // for (var i = 0; i < points.length - 1; i++) {
    //   canvas.drawLine(points[i], points[i + 1], paint);
    // }
    // var now = new DateTime.now();
    for (final line in (points ?? lines)) {
      final path = Path();
      for (var i = 1; i < line.length; i++) {
        path.moveTo(line[i - 1].dx, line[i - 1].dy);
        path.lineTo(line[i].dx, line[i].dy);
      }
      canvas.drawPath(path, paint);
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
    // print(key + " " + penDown.toString() + " " + now.toString());
    // return penDown;
    return true;
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
