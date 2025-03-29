import 'dart:ui';

import 'package:flutter/material.dart';

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

  bool isDrawing = false;
  bool isErasing = false; // isDrawing must be true during Erasing
  var eraserRadius = 10;

  void _handlePointerDown(PointerEvent details) {
    setState(() {
      var x = details.localPosition.dx;
      var y = details.localPosition.dy;
      currentLine.add(Offset(x, y));
      isDrawing = true;
      if (isErasing) {
        lines.removeWhere((line) =>
            line.any((point) =>
                (point - details.localPosition).distance < eraserRadius));
      }
    });
  }

  void _handlePointerMove(PointerEvent details) {
    setState(() {
      var x = details.localPosition.dx;
      var y = details.localPosition.dy;
      currentLine.add(Offset(x, y));
      isDrawing = true;
      if (isErasing) {
        lines.removeWhere((line) =>
            line.any((point) =>
                (point - details.localPosition).distance < eraserRadius));
      }
    });
  }

  void _handlePointerUp(PointerEvent details) {
    var x = details.localPosition.dx;
    var y = details.localPosition.dy;
    setState(() {
      currentLine.add(Offset(x, y));
      lines = [...lines, [..._compressLine(currentLine)]];
      currentLine = [];
      isDrawing = false;
    });
  }

  List<Offset> _compressLine(List<Offset> line) {
    List<Offset> newLine = [];
    const inc = 8;
    if (line.length < inc*2) {return line;}
    for (var i = inc; i < line.length-1; i+=inc){
      if ((line[i-inc] - line[i]).distance > 0.5) {
        newLine.add(line[i-inc]);
      }
    }
    newLine.add(line[line.length-1]);
    return newLine;
  }

  @override
  Widget build(BuildContext context) {
    print("REBUILDING");
    // print(lines.length);
    // print(currentLine.length);
    return Center(
      key: Key('canvas'),
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        child: Stack(
          key: Key("lines"),
          children: [
            Container(
                key: Key("container"),
                color: Colors.white,
            ),
            // Painter for all past lines drawn
            RepaintBoundary(child: CustomPaint(isComplex: true, painter: Line(lines, "1", isDrawing: !isDrawing))),
            // Painter for only the current line 
            RepaintBoundary(child: CustomPaint(isComplex: true, painter: Line([currentLine], "2"))),
            // for (var i = 0; i < lines.length; i++)
            //   RepaintBoundary(child: CustomPaint(key: Key(i.toString()), painter: Line(lines[i], i, lines.length - 1))),
          ],
        ),
      ),
    );
  }
}

class Line extends CustomPainter {
  List<List<Offset>> points;
  bool isDrawing;
  String key;

  @override
  Line(this.points, this.key, {this.isDrawing = true}) : super();

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
    for (final line in points){
      for (var i = 1; i < line.length; i++) {
        canvas.drawLine(line[i-1], line[i], paint);
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
    var now = new DateTime.now();
    // print("repaint: " + index.toString() + " " + now.toString());
    // // print('---');
    // // return oldDelegate.points.length != points.length;
    // print(index.toString() + " " + currentLine.toString());
    // return index == currentLine;
    print(key + " " + isDrawing.toString() + " " + now.toString());
    return isDrawing;
  }
}
