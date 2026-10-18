import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:open_note/core/constants/app_constants.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/models/stroke.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/presentation/widgets/selection_toolbar.dart';
import 'package:open_note/features/canvas/services/eraser_service.dart';
import 'package:open_note/features/canvas/services/lasso_service.dart';

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
  List<Stroke>? _eraserGestureInitialStrokes;
  bool _eraserGestureDidModify = false;

  // Selection / Lasso Tool State
  final ValueNotifier<List<Offset>> lassoPointsNotifier =
      ValueNotifier<List<Offset>>([]);
  List<Stroke> _selectedStrokes = [];
  Rect? _selectionBounds;
  LassoHandle _activeLassoHandle = LassoHandle.none;
  Offset? _lassoDragStartPos;
  Rect? _lassoInitialBounds;
  List<Stroke>? _lassoInitialSelectedStrokes;
  List<Stroke>? _lassoPreTransformAllStrokes;
  bool _lassoTransformDidModify = false;
  Offset? _lassoTouchDownPos;
  double _lassoDragDistance = 0.0;
  bool _pointerDownOnToolbar = false;
  Offset? _lassoRotationCenter;
  double? _lassoRotationStartAngle;
  double _selectionRotation = 0.0;
  double _lassoInitialRotation = 0.0;
  final List<int> _lassoSelectedIndices = [];

  /// Dedicated notifier for the single stroke in-progress to avoid repainting
  /// completed strokes during pen-move events.
  final ValueNotifier<List<StrokePoint>> currentStrokeNotifier =
      ValueNotifier<List<StrokePoint>>([]);

  /// Dedicated notifier for live eraser cursor ring position.
  final ValueNotifier<Offset?> eraserPointerNotifier =
      ValueNotifier<Offset?>(null);

  final List<Color> _customColors = [];

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  List<Color> get customColors => List.unmodifiable(_customColors);
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

  List<Stroke> get selectedStrokes => List.unmodifiable(_selectedStrokes);
  bool get hasSelection => _selectedStrokes.isNotEmpty;
  Rect? get selectionBounds => _selectionBounds;
  double get selectionRotation => _selectionRotation;
  bool get isTransforming => _activeLassoHandle != LassoHandle.none;

  bool _isStylusButtonPressed(int buttons) {
    return (buttons & kPrimaryStylusButton != 0) ||
        (buttons & kSecondaryButton != 0) ||
        (buttons & kSecondaryStylusButton != 0);
  }

  void setTool(ToolType tool) {
    if (_activeTool == tool) return;
    if (_activeTool == ToolType.lasso) {
      deselect();
    }
    _activeTool = tool;
    _isDrawing = false;
    _eraserPendingTouch = false;
    if (_eraserGestureDidModify && _eraserGestureInitialStrokes != null) {
      _recordSnapshot(_eraserGestureInitialStrokes!);
      _redoStack.clear();
    }
    _eraserGestureInitialStrokes = null;
    _eraserGestureDidModify = false;
    currentStrokeNotifier.value = [];
    notifyListeners();
  }

  void setColor(Color color) {
    if (hasSelection) {
      recolorSelection(color);
      return;
    }
    if (_activeTool == ToolType.highlighter) {
      final adjusted = color.a >= 1.0 ? color.withValues(alpha: 0.38) : color;
      if (_highlighterColor == adjusted) return;
      _highlighterColor = adjusted;
    } else {
      if (_penColor == color) return;
      _penColor = color;
    }
    notifyListeners();
  }

  void deselect() {
    if (!hasSelection && lassoPointsNotifier.value.isEmpty) return;
    _selectedStrokes = [];
    _selectionBounds = null;
    _selectionRotation = 0.0;
    _lassoInitialRotation = 0.0;
    _activeLassoHandle = LassoHandle.none;
    _lassoInitialSelectedStrokes = null;
    _lassoPreTransformAllStrokes = null;
    _lassoTransformDidModify = false;
    _lassoRotationCenter = null;
    _lassoRotationStartAngle = null;
    _lassoSelectedIndices.clear();
    lassoPointsNotifier.value = [];
    notifyListeners();
  }

  void deleteSelection() {
    if (!hasSelection) return;
    _recordHistory();
    final toRemove = _selectedStrokes.toSet();
    _strokes = _strokes.where((s) => !toRemove.contains(s)).toList();
    _selectedStrokes = [];
    _selectionBounds = null;
    _selectionRotation = 0.0;
    _lassoInitialRotation = 0.0;
    _activeLassoHandle = LassoHandle.none;
    _redoStack.clear();
    notifyListeners();
  }

  void duplicateSelection() {
    if (!hasSelection || _selectionBounds == null) return;
    _recordHistory();
    final offset = LassoService.computeDuplicateOffset(
      _selectionBounds!,
      pageWidth: AppConstants.defaultPageSize.width,
      pageHeight: AppConstants.defaultPageSize.height,
    );
    final duplicated = LassoService.translateStrokes(
      _selectedStrokes,
      offset,
    );
    _strokes = [..._strokes, ...duplicated];
    _selectedStrokes = duplicated;
    _selectionBounds = _selectionBounds!.shift(offset);
    _redoStack.clear();
    notifyListeners();
  }

  void rotateSelection90({bool clockwise = true}) {
    if (!hasSelection || _selectionBounds == null) return;
    _recordHistory();
    final angle = clockwise ? (pi / 2) : (-pi / 2);
    final center = _selectionBounds!.center;
    final rotated = LassoService.rotateStrokes(
      _selectedStrokes,
      center,
      angle,
    );
    final oldSelectedSet = _selectedStrokes.toSet();
    final List<Stroke> newStrokes = [];
    int selIdx = 0;
    for (final s in _strokes) {
      if (oldSelectedSet.contains(s)) {
        newStrokes.add(rotated[selIdx++]);
      } else {
        newStrokes.add(s);
      }
    }
    _strokes = newStrokes;
    _selectedStrokes = rotated;
    _selectionRotation += angle;
    while (_selectionRotation > pi) {
      _selectionRotation -= 2 * pi;
    }
    while (_selectionRotation < -pi) {
      _selectionRotation += 2 * pi;
    }
    _redoStack.clear();
    notifyListeners();
  }

  void recolorSelection(Color color) {
    if (!hasSelection) return;
    _recordHistory();
    final recolored =
        _selectedStrokes.map((s) => s.copyWith(color: color)).toList();
    final oldSelectedSet = _selectedStrokes.toSet();
    final List<Stroke> newStrokes = [];
    int selIdx = 0;
    for (final s in _strokes) {
      if (oldSelectedSet.contains(s)) {
        newStrokes.add(recolored[selIdx++]);
      } else {
        newStrokes.add(s);
      }
    }
    _strokes = newStrokes;
    _selectedStrokes = recolored;
    _redoStack.clear();
    notifyListeners();
  }

  void addCustomColor(Color color) {
    _customColors.removeWhere((c) => c.toARGB32() == color.toARGB32());
    _customColors.insert(0, color);
    if (_customColors.length > 5) {
      _customColors.removeLast();
    }
    setColor(color);
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

  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  void loadStrokes(List<Stroke> newStrokes, {bool clearHistory = false}) {
    if (clearHistory) {
      _undoStack.clear();
      _redoStack.clear();
    } else {
      _recordHistory();
      _redoStack.clear();
    }
    _strokes = List.from(newStrokes);
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
      eraserPointerNotifier.value = localPosition;
      _eraserGestureInitialStrokes = List.from(_strokes);
      _eraserGestureDidModify = false;
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

    // 5. Lasso handling
    if (_activeTool == ToolType.lasso) {
      _pointerDownOnToolbar = false;
      _drawingPointerId = pointer;
      _lassoTouchDownPos = localPosition;
      _lassoDragDistance = 0.0;

      if (hasSelection && _selectionBounds != null) {
        // Priority 1: Check handles first! (Rotation knob or 4 corner resize handles)
        Offset effectivePos = localPosition;
        if (_selectionRotation != 0.0) {
          effectivePos = LassoService.unrotatePoint(
            localPosition,
            _selectionBounds!.center,
            _selectionRotation,
          );
        }

        final handle = LassoService.hitTestHandle(
          effectivePos,
          _selectionBounds!,
        );

        if (handle != LassoHandle.none && handle != LassoHandle.move) {
          _activeLassoHandle = handle;
          _lassoDragStartPos = localPosition;
          _lassoInitialBounds = _selectionBounds;
          _lassoInitialSelectedStrokes = List.from(_selectedStrokes);
          _lassoPreTransformAllStrokes = List.from(_strokes);
          _lassoTransformDidModify = false;
          _lassoInitialRotation = _selectionRotation;
          _lassoSelectedIndices.clear();
          final selSet = _selectedStrokes.toSet();
          for (int i = 0; i < _strokes.length; i++) {
            if (selSet.contains(_strokes[i])) {
              _lassoSelectedIndices.add(i);
            }
          }

          if (handle == LassoHandle.rotate) {
            final center = _selectionBounds!.center;
            _lassoRotationCenter = center;
            _lassoRotationStartAngle = atan2(
              localPosition.dy - center.dy,
              localPosition.dx - center.dx,
            );
          } else {
            _lassoRotationCenter = null;
            _lassoRotationStartAngle = null;
          }
          notifyListeners();
          return;
        }

        // Priority 2: Floating contextual toolbar
        final toolbarRect = SelectionToolbar.getToolbarRect(
          _selectionBounds!,
          rotationAngle: _selectionRotation,
          pageWidth: AppConstants.defaultPageSize.width,
        );

        if (toolbarRect.contains(localPosition)) {
          // Tap is on the floating action toolbar: do not disrupt button clicks
          _pointerDownOnToolbar = true;
          return;
        }

        // Priority 3: Move handle (inside selection bounds)
        if (handle == LassoHandle.move) {
          _activeLassoHandle = handle;
          _lassoDragStartPos = localPosition;
          _lassoInitialBounds = _selectionBounds;
          _lassoInitialSelectedStrokes = List.from(_selectedStrokes);
          _lassoPreTransformAllStrokes = List.from(_strokes);
          _lassoTransformDidModify = false;
          _lassoInitialRotation = _selectionRotation;
          _lassoSelectedIndices.clear();
          final selSet = _selectedStrokes.toSet();
          for (int i = 0; i < _strokes.length; i++) {
            if (selSet.contains(_strokes[i])) {
              _lassoSelectedIndices.add(i);
            }
          }
          _lassoRotationCenter = null;
          _lassoRotationStartAngle = null;
          notifyListeners();
          return;
        }
      }

      _activeLassoHandle = LassoHandle.none;
      _lassoDragStartPos = null;
      _lassoRotationCenter = null;
      _lassoRotationStartAngle = null;
      _lassoSelectedIndices.clear();
      lassoPointsNotifier.value = [localPosition];
      return;
    }

    // 6. Inking
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
      _eraserGestureInitialStrokes ??= List.from(_strokes);
      eraserPointerNotifier.value = localPosition;
      _eraserPendingTouch = false;
      _handleEraser(localPosition);
      return;
    }

    // Lasso Move or Scale or Drawing loop
    if (_activeTool == ToolType.lasso) {
      if (_lassoTouchDownPos != null) {
        _lassoDragDistance += (localPosition - _lassoTouchDownPos!).distance;
      }

      if (_activeLassoHandle != LassoHandle.none &&
          _lassoDragStartPos != null &&
          _lassoInitialBounds != null &&
          _lassoInitialSelectedStrokes != null) {
        _lassoTransformDidModify = true;
        final delta = localPosition - _lassoDragStartPos!;

        late final Rect updatedBounds;
        late final List<Stroke> updatedSelected;

        if (_activeLassoHandle == LassoHandle.rotate &&
            _lassoRotationCenter != null &&
            _lassoRotationStartAngle != null) {
          _lassoTransformDidModify = true;
          final currentAngle = atan2(
            localPosition.dy - _lassoRotationCenter!.dy,
            localPosition.dx - _lassoRotationCenter!.dx,
          );
          var angleDelta = currentAngle - _lassoRotationStartAngle!;
          while (angleDelta > pi) {
            angleDelta -= 2 * pi;
          }
          while (angleDelta < -pi) {
            angleDelta += 2 * pi;
          }

          var totalRotation = _lassoInitialRotation + angleDelta;

          // Angle snapping: snap totalRotation to 15-degree increments if within 3.5 degrees
          const snapThreshold = 3.5 * pi / 180.0;
          const snapStep = 15.0 * pi / 180.0;
          final nearestSnap = (totalRotation / snapStep).round() * snapStep;
          if ((totalRotation - nearestSnap).abs() < snapThreshold) {
            totalRotation = nearestSnap;
            angleDelta = totalRotation - _lassoInitialRotation;
          }

          updatedSelected = LassoService.rotateStrokes(
            _lassoInitialSelectedStrokes!,
            _lassoRotationCenter!,
            angleDelta,
          );
          _selectionRotation = totalRotation;
          updatedBounds = _lassoInitialBounds!;
        } else if (_activeLassoHandle == LassoHandle.move) {
          updatedBounds = _lassoInitialBounds!.shift(delta);
          updatedSelected = LassoService.translateStrokes(
            _lassoInitialSelectedStrokes!,
            delta,
          );
        } else {
          updatedBounds = LassoService.calculateTransformedBounds(
            _lassoInitialBounds!,
            _activeLassoHandle,
            delta,
          );
          updatedSelected = LassoService.scaleStrokes(
            _lassoInitialSelectedStrokes!,
            _lassoInitialBounds!,
            updatedBounds,
          );
        }

        final List<Stroke> newStrokes = List.from(_lassoPreTransformAllStrokes!);
        for (int i = 0; i < _lassoSelectedIndices.length; i++) {
          final idx = _lassoSelectedIndices[i];
          if (idx < newStrokes.length && i < updatedSelected.length) {
            newStrokes[idx] = updatedSelected[i];
          }
        }
        _strokes = newStrokes;
        _selectedStrokes = updatedSelected;
        _selectionBounds = updatedBounds;
        notifyListeners();
        return;
      }

      final current = lassoPointsNotifier.value;
      if (current.isNotEmpty && (current.last - localPosition).distance > 2.0) {
        lassoPointsNotifier.value = [...current, localPosition];
      }
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
    eraserPointerNotifier.value = null;

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
    final wasErasing = _eraserGestureInitialStrokes != null ||
        _activeTool.isEraser ||
        isBarrelButton;

    if (wasErasing) {
      if (_eraserPendingTouch && _eraserTouchDownPos != null) {
        // Single tap touch erase
        _eraserGestureInitialStrokes ??= List.from(_strokes);
        _handleEraser(_eraserTouchDownPos!);
        _eraserPendingTouch = false;
        _eraserTouchDownPos = null;
      }
      if (_eraserGestureDidModify && _eraserGestureInitialStrokes != null) {
        _recordSnapshot(_eraserGestureInitialStrokes!);
        _redoStack.clear();
        notifyListeners();
      }
      _eraserGestureInitialStrokes = null;
      _eraserGestureDidModify = false;
      return;
    }

    if (_activeTool == ToolType.lasso) {
      if (_pointerDownOnToolbar) {
        _pointerDownOnToolbar = false;
        _lassoTouchDownPos = null;
        _lassoDragDistance = 0.0;
        return;
      }

      if (_lassoTransformDidModify && _lassoPreTransformAllStrokes != null) {
        _recordSnapshot(_lassoPreTransformAllStrokes!);
        _redoStack.clear();
        _lassoPreTransformAllStrokes = null;
        _lassoInitialSelectedStrokes = null;
        _lassoInitialBounds = null;
        _lassoTransformDidModify = false;
        _lassoRotationCenter = null;
        _lassoRotationStartAngle = null;
        _lassoSelectedIndices.clear();
        _activeLassoHandle = LassoHandle.none;
        notifyListeners();
        return;
      }

      // If user tapped a handle or clicked inside selection without dragging, keep selection
      if (_activeLassoHandle != LassoHandle.none) {
        _lassoPreTransformAllStrokes = null;
        _lassoInitialSelectedStrokes = null;
        _lassoInitialBounds = null;
        _lassoTransformDidModify = false;
        _lassoRotationCenter = null;
        _lassoRotationStartAngle = null;
        _lassoSelectedIndices.clear();
        _activeLassoHandle = LassoHandle.none;
        _lassoTouchDownPos = null;
        _lassoDragDistance = 0.0;
        notifyListeners();
        return;
      }

      _lassoPreTransformAllStrokes = null;
      _lassoInitialSelectedStrokes = null;
      _lassoInitialBounds = null;
      _lassoTransformDidModify = false;
      _lassoRotationCenter = null;
      _lassoRotationStartAngle = null;
      _lassoSelectedIndices.clear();
      _activeLassoHandle = LassoHandle.none;

      final points = lassoPointsNotifier.value;
      final isTap = _lassoDragDistance < 10.0 || points.length < 3;

      if (isTap && _lassoTouchDownPos != null) {
        // --- SINGLE TAP SELECTION MODE ---
        // Find topmost visible stroke hit by the tap (strokes behind it are ignored)
        final tappedStroke = LassoService.findTopmostStrokeAtPoint(
          _strokes,
          _lassoTouchDownPos!,
        );

        if (tappedStroke != null) {
          _selectedStrokes = [tappedStroke];
          _selectionBounds = LassoService.computeSelectionBounds([tappedStroke]);
          _selectionRotation = 0.0;
        } else {
          deselect();
        }
      } else if (points.length >= 3) {
        // --- FREEFORM LASSO LOOP SELECTION ---
        final selected = LassoService.findSelectedStrokes(_strokes, points);
        if (selected.isNotEmpty) {
          _selectedStrokes = selected;
          _selectionBounds = LassoService.computeSelectionBounds(selected);
          _selectionRotation = 0.0;
        } else {
          deselect();
        }
      } else {
        deselect();
      }

      lassoPointsNotifier.value = [];
      _lassoTouchDownPos = null;
      _lassoDragDistance = 0.0;
      notifyListeners();
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
      _strokes = [
        ..._strokes,
        Stroke(
          points: compressed,
          color: strokeColor,
          strokeWidth: strokeWidth,
          toolType: _activeTool,
        ),
      ];
      _redoStack.clear();
    }

    _isDrawing = false;
    currentStrokeNotifier.value = [];
    notifyListeners();
  }

  void onPointerCancel({int pointer = 0}) {
    _activePointers.remove(pointer);
    eraserPointerNotifier.value = null;
    if (_eraserGestureDidModify && _eraserGestureInitialStrokes != null) {
      _recordSnapshot(_eraserGestureInitialStrokes!);
      _redoStack.clear();
    }
    _eraserGestureInitialStrokes = null;
    _eraserGestureDidModify = false;

    if (_lassoTransformDidModify && _lassoPreTransformAllStrokes != null) {
      _recordSnapshot(_lassoPreTransformAllStrokes!);
      _redoStack.clear();
    }
    _lassoPreTransformAllStrokes = null;
    _lassoInitialSelectedStrokes = null;
    _lassoInitialBounds = null;
    _lassoTransformDidModify = false;
    _activeLassoHandle = LassoHandle.none;
    _lassoTouchDownPos = null;
    _lassoDragDistance = 0.0;
    lassoPointsNotifier.value = [];

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
    _eraserGestureInitialStrokes ??= List.from(_strokes);

    if (_activeTool == ToolType.areaEraser) {
      // Area / Precision Eraser: geometric slicing of strokes
      bool modified = false;
      final List<Stroke> newStrokes = [];

      for (final stroke in _strokes) {
        final fragments =
            EraserService.sliceStroke(stroke, pointer, _eraserRadius);
        final isUnchanged =
            fragments.length == 1 && identical(fragments.first, stroke);

        if (!isUnchanged) {
          modified = true;
          newStrokes.addAll(fragments);
        } else {
          newStrokes.add(stroke);
        }
      }

      if (modified) {
        _eraserGestureDidModify = true;
        _strokes = newStrokes;
        notifyListeners();
      }
    } else {
      // Stroke Eraser: deletes entire stroke upon intersection
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
        _eraserGestureDidModify = true;
        _strokes = remaining;
        notifyListeners();
      }
    }
  }

  void undo() {
    // If an in-progress lasso transform modified strokes, commit snapshot first
    if (_lassoTransformDidModify && _lassoPreTransformAllStrokes != null) {
      _recordSnapshot(_lassoPreTransformAllStrokes!);
      _redoStack.clear();
      _lassoPreTransformAllStrokes = null;
      _lassoInitialSelectedStrokes = null;
      _lassoInitialBounds = null;
      _lassoTransformDidModify = false;
      _activeLassoHandle = LassoHandle.none;
    }
    deselect();

    // If an in-progress eraser gesture modified strokes before pointer-up, commit snapshot first
    if (_eraserGestureDidModify && _eraserGestureInitialStrokes != null) {
      _recordSnapshot(_eraserGestureInitialStrokes!);
      _redoStack.clear();
      _eraserGestureInitialStrokes = null;
      _eraserGestureDidModify = false;
    }
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.from(_strokes));
    _strokes = _undoStack.removeLast();
    notifyListeners();
  }

  void redo() {
    deselect();
    if (_redoStack.isEmpty) return;
    _undoStack.add(List.from(_strokes));
    _strokes = _redoStack.removeLast();
    notifyListeners();
  }

  void clear() {
    deselect();
    if (_strokes.isEmpty) return;
    _recordHistory();
    _strokes = [];
    _redoStack.clear();
    notifyListeners();
  }

  void _recordSnapshot(List<Stroke> snapshot) {
    _undoStack.add(List.from(snapshot));
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
  }

  void _recordHistory() {
    _recordSnapshot(_strokes);
  }

  @override
  void dispose() {
    currentStrokeNotifier.dispose();
    eraserPointerNotifier.dispose();
    lassoPointsNotifier.dispose();
    super.dispose();
  }
}
