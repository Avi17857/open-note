import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:open_note/core/constants/app_constants.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/services/eraser_service.dart';

class CanvasController extends ChangeNotifier {
  List<Stroke> _strokes = [];
  final List<List<Stroke>> _undoStack = [];
  final List<List<Stroke>> _redoStack = [];

  ToolType _activeTool = ToolType.pen;
  Color _activeColor = Colors.black;
  double _strokeWidth = AppConstants.defaultStrokeWidth;
  double _eraserRadius = AppConstants.defaultEraserRadius;
  bool _isDrawing = false;

  /// Dedicated notifier for the single stroke in-progress to avoid repainting
  /// completed strokes during pen-move events.
  final ValueNotifier<List<Offset>> currentStrokeNotifier =
      ValueNotifier<List<Offset>>([]);

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  ToolType get activeTool => _activeTool;
  Color get activeColor => _activeColor;
  double get strokeWidth => _strokeWidth;
  double get eraserRadius => _eraserRadius;
  bool get isDrawing => _isDrawing;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void setTool(ToolType tool) {
    if (_activeTool == tool) return;
    _activeTool = tool;
    notifyListeners();
  }

  void setColor(Color color) {
    if (_activeColor == color) return;
    _activeColor = color;
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    if (_strokeWidth == width) return;
    _strokeWidth = width;
    notifyListeners();
  }

  void setEraserRadius(double radius) {
    if (_eraserRadius == radius) return;
    _eraserRadius = radius;
    notifyListeners();
  }

  void loadStrokes(List<Stroke> newStrokes) {
    _recordHistory();
    _strokes = List.from(newStrokes);
    _redoStack.clear();
    notifyListeners();
  }

  void onPointerDown(Offset localPosition, {PointerDeviceKind? kind}) {
    // Inverted stylus tail automatically acts as an eraser
    if (kind == PointerDeviceKind.invertedStylus && !_activeTool.isEraser) {
      setTool(ToolType.strokeEraser);
    }

    if (_activeTool.isEraser) {
      _handleEraser(localPosition);
      return;
    }

    _isDrawing = true;
    currentStrokeNotifier.value = [localPosition];
  }

  void onPointerMove(Offset localPosition) {
    if (_activeTool.isEraser) {
      _handleEraser(localPosition);
      return;
    }

    if (!_isDrawing) return;

    final current = currentStrokeNotifier.value;
    if (current.isEmpty || (current.last - localPosition).distance > 1.0) {
      currentStrokeNotifier.value = [...current, localPosition];
    }
  }

  void onPointerUp(Offset localPosition) {
    if (_activeTool.isEraser) {
      return;
    }

    if (!_isDrawing) return;

    final rawPoints = currentStrokeNotifier.value;
    if (rawPoints.isNotEmpty) {
      final finalPoints = [...rawPoints, localPosition];
      final compressed = Stroke.compressPoints(finalPoints);

      _recordHistory();
      _strokes.add(
        Stroke(
          points: compressed,
          color: _activeColor,
          strokeWidth: _strokeWidth,
          toolType: _activeTool,
        ),
      );
      _redoStack.clear();
    }

    _isDrawing = false;
    currentStrokeNotifier.value = [];
    notifyListeners();
  }

  void _handleEraser(Offset pointer) {
    bool strokeRemoved = false;
    final List<Stroke> remaining = [];

    for (final stroke in _strokes) {
      if (EraserService.hitTestStroke(stroke, pointer, _eraserRadius)) {
        strokeRemoved = true;
      } else {
        remaining.add(stroke);
      }
    }

    if (strokeRemoved) {
      _recordHistory();
      _strokes = remaining;
      _redoStack.clear();
      notifyListeners();
    }
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.from(_strokes));
    _strokes = _undoStack.removeLast();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List.from(_strokes));
    _strokes = _redoStack.removeLast();
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _recordHistory();
    _strokes = [];
    _redoStack.clear();
    notifyListeners();
  }

  void _recordHistory() {
    _undoStack.add(List.from(_strokes));
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
  }

  @override
  void dispose() {
    currentStrokeNotifier.dispose();
    super.dispose();
  }
}
