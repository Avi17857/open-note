import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

  // Palm Rejection & Multi-Touch State
  bool _isStylusActive = false;
  DateTime? _lastStylusTime;
  final Set<int> _activePointers = {};
  int? _drawingPointerId;
  bool _isMultiTouch = false;
  bool _eraserPendingTouch = false;
  Offset? _eraserTouchDownPos;

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
  bool get isMultiTouch => _isMultiTouch;

  bool _isStylusButtonPressed(int buttons) {
    return (buttons & kPrimaryStylusButton != 0) ||
        (buttons & kSecondaryButton != 0) ||
        (buttons & kSecondaryStylusButton != 0);
  }

  void setTool(ToolType tool) {
    if (_activeTool == tool) return;
    _activeTool = tool;
    _isDrawing = false;
    _eraserPendingTouch = false;
    _eraserTouchDownPos = null;
    currentStrokeNotifier.value = [];
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
    int pointer = 0,
    PointerDeviceKind? kind,
    double pressure = 0.5,
    int buttons = 0,
  }) {
    if (_activeTool == ToolType.pan) return;

    // 1. Palm Rejection: If stylus is active, ignore touch pointers before tracking them
    if (kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus) {
      _isStylusActive = true;
      _lastStylusTime = DateTime.now();
    } else if (kind == PointerDeviceKind.touch && _isStylusActive) {
      if (_lastStylusTime != null &&
          DateTime.now().difference(_lastStylusTime!).inMilliseconds < 1500) {
        return; // Reject palm touch
      } else {
        _isStylusActive = false;
      }
    }

    _activePointers.add(pointer);

    // 2. Multi-touch rejection (Pinch-to-zoom / 2-finger pan)
    if (_activePointers.length >= 2) {
      _isMultiTouch = true;
      _eraserPendingTouch = false;
      _eraserTouchDownPos = null;
      if (_isDrawing) {
        _isDrawing = false;
        currentStrokeNotifier.value = [];
      }
      _drawingPointerId = null;
      return;
    }

    if (_isMultiTouch) return;

    // 3. Inverted stylus tail automatically acts as an eraser
    if (kind == PointerDeviceKind.invertedStylus && !_activeTool.isEraser) {
      setTool(ToolType.strokeEraser);
    }

    // 4. Eraser handling
    final isBarrelButton = _isStylusButtonPressed(buttons);
    if (_activeTool.isEraser || isBarrelButton) {
      if (kind == PointerDeviceKind.touch) {
        // Defer touch erasure to move or up to prevent accidental erasure
        // when placing 2 fingers down for zoom/pan
        _drawingPointerId = pointer;
        _eraserPendingTouch = true;
        _eraserTouchDownPos = localPosition;
      } else {
        // Stylus or Mouse: erase immediately
        _handleEraser(localPosition);
      }
      return;
    }

    // 5. Inking
    _drawingPointerId = pointer;
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
    int pointer = 0,
    PointerDeviceKind? kind,
    double pressure = 0.5,
    int buttons = 0,
  }) {
    if (_activeTool == ToolType.pan) return;
    if (_isMultiTouch || _activePointers.length >= 2) return;
    if (kind == PointerDeviceKind.touch && _isStylusActive) return; // Palm rejection
    if (_drawingPointerId != null && _drawingPointerId != pointer) return;

    // S-Pen barrel button: instantly acts as an eraser while held
    final isBarrelButton = _isStylusButtonPressed(buttons);
    if (_activeTool.isEraser || isBarrelButton) {
      if (_isDrawing) {
        _isDrawing = false;
        currentStrokeNotifier.value = [];
      }
      _eraserPendingTouch = false;
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
    int pointer = 0,
    PointerDeviceKind? kind,
    double pressure = 0.5,
    int buttons = 0,
  }) {
    _activePointers.remove(pointer);

    if (_isMultiTouch) {
      if (_activePointers.isEmpty) {
        _isMultiTouch = false;
      }
      return;
    }

    if (_activeTool == ToolType.pan) return;
    if (kind == PointerDeviceKind.touch && _isStylusActive) return;
    if (_drawingPointerId != null && _drawingPointerId != pointer) return;
    _drawingPointerId = null;

    final isBarrelButton = _isStylusButtonPressed(buttons);
    if (_activeTool.isEraser || isBarrelButton) {
      if (_eraserPendingTouch && _eraserTouchDownPos != null) {
        // Single tap touch erase
        _handleEraser(_eraserTouchDownPos!);
        _eraserPendingTouch = false;
        _eraserTouchDownPos = null;
      }
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

  void onPointerCancel({int pointer = 0}) {
    _activePointers.remove(pointer);
    if (_activePointers.isEmpty) {
      _isMultiTouch = false;
    }
    if (_drawingPointerId == pointer) {
      _drawingPointerId = null;
      _eraserPendingTouch = false;
      _eraserTouchDownPos = null;
      if (_isDrawing) {
        _isDrawing = false;
        currentStrokeNotifier.value = [];
      }
    }
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
