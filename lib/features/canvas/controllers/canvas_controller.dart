import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:open_note/core/constants/app_constants.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/services/eraser_service.dart';

class CanvasController extends ChangeNotifier {
  List<Stroke> _strokes = [];
  final List<List<Stroke>> _undoStack = [];
  final List<List<Stroke>> _redoStack = [];

  ToolType _activeTool = ToolType.pen;
  Color _penColor = Colors.black;
  Color _highlighterColor = AppColors.highlighterPalette.first;
  double _penWidth = AppConstants.defaultStrokeWidth;
  double _highlighterWidth = 22.0;
  double _eraserRadius = AppConstants.defaultEraserRadius;
  bool _isDrawing = false;

  // Palm Rejection State
  bool _isStylusActive = false;
  DateTime? _lastStylusTime;

  /// Dedicated notifier for the single stroke in-progress to avoid repainting
  /// completed strokes during pen-move events.
  final ValueNotifier<List<StrokePoint>> currentStrokeNotifier =
      ValueNotifier<List<StrokePoint>>([]);

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  ToolType get activeTool => _activeTool;
  Color get activeColor =>
      _activeTool == ToolType.highlighter ? _highlighterColor : _penColor;
  double get strokeWidth =>
      _activeTool == ToolType.highlighter ? _highlighterWidth : _penWidth;
  double get eraserRadius => _eraserRadius;
  bool get isDrawing => _isDrawing;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isStylusActive => _isStylusActive;

  void setTool(ToolType tool) {
    if (_activeTool == tool) return;
    _activeTool = tool;
    notifyListeners();
  }

  void setColor(Color color) {
    if (_activeTool == ToolType.highlighter) {
      if (_highlighterColor == color) return;
      _highlighterColor = color;
    } else {
      if (_penColor == color) return;
      _penColor = color;
    }
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    if (_activeTool == ToolType.highlighter) {
      if (_highlighterWidth == width) return;
      _highlighterWidth = width;
    } else {
      if (_penWidth == width) return;
      _penWidth = width;
    }
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

  void onPointerDown(
    Offset localPosition, {
    PointerDeviceKind? kind,
    double pressure = 0.5,
  }) {
    if (_activeTool == ToolType.pan) return;

    // Track active stylus
    if (kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus) {
      _isStylusActive = true;
      _lastStylusTime = DateTime.now();
    } else if (kind == PointerDeviceKind.touch && _isStylusActive) {
      // Palm Rejection: If stylus was used within the last 1.5s, ignore palm touches
      if (_lastStylusTime != null &&
          DateTime.now().difference(_lastStylusTime!).inMilliseconds < 1500) {
        return;
      } else {
        _isStylusActive = false;
      }
    }

    // Inverted stylus tail automatically acts as an eraser
    if (kind == PointerDeviceKind.invertedStylus && !_activeTool.isEraser) {
      setTool(ToolType.strokeEraser);
    }

    if (_activeTool.isEraser) {
      _handleEraser(localPosition);
      return;
    }

    _isDrawing = true;
    final point = StrokePoint(
      localPosition.dx,
      localPosition.dy,
      pressure: pressure > 0.0 ? pressure : 0.5,
    );
    currentStrokeNotifier.value = [point];
  }

  void onPointerMove(
    Offset localPosition, {
    PointerDeviceKind? kind,
    double pressure = 0.5,
  }) {
    if (_activeTool == ToolType.pan) return;

    if (kind == PointerDeviceKind.touch && _isStylusActive) {
      return; // Palm rejection
    }

    if (_activeTool.isEraser) {
      _handleEraser(localPosition);
      return;
    }

    if (!_isDrawing) return;

    final current = currentStrokeNotifier.value;
    if (current.isEmpty || (current.last - localPosition).distance > 1.0) {
      final point = StrokePoint(
        localPosition.dx,
        localPosition.dy,
        pressure: pressure > 0.0 ? pressure : 0.5,
      );
      currentStrokeNotifier.value = [...current, point];
    }
  }

  void onPointerUp(
    Offset localPosition, {
    PointerDeviceKind? kind,
    double pressure = 0.5,
  }) {
    if (_activeTool == ToolType.pan) return;

    if (kind == PointerDeviceKind.touch && _isStylusActive) {
      return;
    }

    if (_activeTool.isEraser) {
      return;
    }

    if (!_isDrawing) return;

    final rawPoints = currentStrokeNotifier.value;
    if (rawPoints.isNotEmpty) {
      final lastPoint = StrokePoint(
        localPosition.dx,
        localPosition.dy,
        pressure: pressure > 0.0 ? pressure : 0.5,
      );
      final finalPoints = [...rawPoints, lastPoint];
      final compressed = Stroke.compressPoints(finalPoints);

      Color strokeColor = activeColor;
      if (_activeTool == ToolType.highlighter && strokeColor.a >= 1.0) {
        strokeColor = strokeColor.withValues(alpha: 0.38);
      }

      _recordHistory();
      _strokes.add(
        Stroke(
          points: compressed,
          color: strokeColor,
          strokeWidth: strokeWidth,
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
