import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:open_note/core/constants/app_constants.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/controllers/rich_text_editing_controller.dart';
import 'package:open_note/features/canvas/models/note_text_box.dart';
import 'package:open_note/features/canvas/models/stroke_point.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/presentation/painters/active_stroke_painter.dart';
import 'package:open_note/features/canvas/presentation/painters/completed_strokes_painter.dart';
import 'package:open_note/features/canvas/presentation/painters/eraser_cursor_painter.dart';
import 'package:open_note/features/canvas/presentation/painters/lasso_path_painter.dart';
import 'package:open_note/features/canvas/presentation/painters/page_background_painter.dart';
import 'package:open_note/features/canvas/presentation/painters/selection_painter.dart';
import 'package:open_note/features/canvas/presentation/widgets/drawing_toolbar.dart';
import 'package:open_note/features/canvas/presentation/widgets/selection_toolbar.dart';
import 'package:open_note/features/canvas/presentation/widgets/text_box_widget.dart';
import 'package:open_note/features/canvas/services/lasso_service.dart';

class NoteCanvas extends StatefulWidget {
  final CanvasController controller;
  final PageTemplate template;

  const NoteCanvas({
    super.key,
    required this.controller,
    this.template = PageTemplate.ruled,
  });

  @override
  State<NoteCanvas> createState() => _NoteCanvasState();
}

class _NoteCanvasState extends State<NoteCanvas> {
  static const double _boardMarginHorizontal = 300.0;
  static const double _boardMarginVertical = 120.0;

  final TransformationController _transformationController =
      TransformationController();
  final Map<String, RichTextEditingController> _textControllers = {};

  RichTextEditingController _getOrCreateTextController(NoteTextBox box) {
    var ctrl = _textControllers[box.id];
    if (ctrl == null) {
      ctrl = RichTextEditingController(text: box.text, spans: box.spans);
      ctrl.addListener(() {
        box.text = ctrl!.text;
        box.spans = ctrl.spans;
      });
      _textControllers[box.id] = ctrl;
    }
    return ctrl;
  }

  @override
  void dispose() {
    for (final ctrl in _textControllers.values) {
      ctrl.dispose();
    }
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final matrix = _transformationController.value.clone();
    matrix.scale(1.2, 1.2);
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformationController.value.clone();
    matrix.scale(0.8, 0.8);
    _transformationController.value = matrix;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  MouseCursor get _currentCursor {
    return switch (widget.controller.activeTool) {
      ToolType.pen ||
      ToolType.fountainPen ||
      ToolType.highlighter ||
      ToolType.lasso =>
        SystemMouseCursors.precise,
      ToolType.text => SystemMouseCursors.text,
      ToolType.strokeEraser || ToolType.areaEraser => SystemMouseCursors.click,
      ToolType.pan => SystemMouseCursors.grab,
    };
  }

  bool _isPointerOverAnyTextBox(Offset boardPos) {
    for (int i = 0; i < widget.controller.pages.length; i++) {
      final page = widget.controller.pages[i];
      final origin = Offset(
        _boardMarginHorizontal,
        _boardMarginVertical +
            AppConstants.pageHeaderHeight +
            i * AppConstants.pagePitch,
      );
      for (final box in page.textBoxes) {
        final boxRect = Rect.fromLTWH(
          origin.dx + box.position.dx,
          origin.dy + box.position.dy,
          box.width,
          box.height ?? 44.0,
        ).inflate(12.0);
        if (boxRect.contains(boardPos)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DrawingToolbar(controller: widget.controller),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final isPanTool = widget.controller.activeTool == ToolType.pan;

              return Stack(
                children: [
                  // Interactive Pan / Zoom Viewport with mouse scroll support
                  Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        final matrix = _transformationController.value.clone();
                        matrix.translate(0.0, -pointerSignal.scrollDelta.dy);
                        _transformationController.value = matrix;
                      }
                    },
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: const EdgeInsets.all(600),
                      minScale: AppConstants.minScale,
                      maxScale: AppConstants.maxScale,
                      panEnabled: isPanTool,
                      scaleEnabled: true,
                      constrained: false,
                      child: Center(
                        child: MouseRegion(
                          cursor: _currentCursor,
                          child: SizedBox(
                            width: AppConstants.defaultPageSize.width +
                                _boardMarginHorizontal * 2,
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (e) {
                                final boardX = e.localPosition.dx;
                                final boardY = e.localPosition.dy;
                                final yRelativeToFirstPage =
                                    boardY - _boardMarginVertical;
                                final touchPageIndex = (yRelativeToFirstPage /
                                        AppConstants.pagePitch)
                                    .floor()
                                    .clamp(
                                        0, widget.controller.pages.length - 1);

                                bool isInteractingWithSelection = false;
                                if (widget.controller.hasSelection &&
                                    widget.controller.selectionBounds != null) {
                                  final activeIdx =
                                      widget.controller.activePageIndex;
                                  final canvasOrigin = Offset(
                                    _boardMarginHorizontal,
                                    _boardMarginVertical +
                                        AppConstants.pageHeaderHeight +
                                        activeIdx * AppConstants.pagePitch,
                                  );
                                  final globalBounds = widget.controller
                                      .selectionBounds!
                                      .shift(canvasOrigin);

                                  Offset effectivePos = e.localPosition;
                                  if (widget.controller.selectionRotation !=
                                      0.0) {
                                    effectivePos = LassoService.unrotatePoint(
                                      e.localPosition,
                                      globalBounds.center,
                                      widget.controller.selectionRotation,
                                    );
                                  }
                                  final handle = LassoService.hitTestHandle(
                                    effectivePos,
                                    globalBounds,
                                  );
                                  final toolbarRect =
                                      SelectionToolbar.getToolbarRect(
                                    globalBounds,
                                    rotationAngle:
                                        widget.controller.selectionRotation,
                                    pageWidth:
                                        AppConstants.defaultPageSize.width,
                                  );
                                  if (handle != LassoHandle.none ||
                                      toolbarRect.contains(e.localPosition)) {
                                    isInteractingWithSelection = true;
                                  }
                                }

                                if (!isInteractingWithSelection) {
                                  if (widget.controller.activePageIndex !=
                                      touchPageIndex) {
                                    widget.controller
                                        .setActivePage(touchPageIndex);
                                  }
                                }

                                final activeIdx =
                                    widget.controller.activePageIndex;
                                final localX = boardX - _boardMarginHorizontal;
                                final localY = boardY -
                                    (_boardMarginVertical +
                                        AppConstants.pageHeaderHeight +
                                        activeIdx * AppConstants.pagePitch);

                                // If touching inside a text box and not in text mode, do not draw or lasso
                                if (!isInteractingWithSelection &&
                                    widget.controller.activeTool !=
                                        ToolType.text &&
                                    _isPointerOverAnyTextBox(e.localPosition)) {
                                  return;
                                }

                                widget.controller.onPointerDown(
                                  Offset(localX, localY),
                                  pointer: e.pointer,
                                  kind: e.kind,
                                  pressure: e.pressure,
                                  buttons: e.buttons,
                                );
                              },
                              onPointerMove: (e) {
                                final activeIdx =
                                    widget.controller.activePageIndex;
                                final localX =
                                    e.localPosition.dx - _boardMarginHorizontal;
                                final localY = e.localPosition.dy -
                                    (_boardMarginVertical +
                                        AppConstants.pageHeaderHeight +
                                        activeIdx * AppConstants.pagePitch);

                                widget.controller.onPointerMove(
                                  Offset(localX, localY),
                                  pointer: e.pointer,
                                  kind: e.kind,
                                  pressure: e.pressure,
                                  buttons: e.buttons,
                                );
                              },
                              onPointerUp: (e) {
                                final activeIdx =
                                    widget.controller.activePageIndex;
                                final localX =
                                    e.localPosition.dx - _boardMarginHorizontal;
                                final localY = e.localPosition.dy -
                                    (_boardMarginVertical +
                                        AppConstants.pageHeaderHeight +
                                        activeIdx * AppConstants.pagePitch);

                                widget.controller.onPointerUp(
                                  Offset(localX, localY),
                                  pointer: e.pointer,
                                  kind: e.kind,
                                  pressure: e.pressure,
                                  buttons: e.buttons,
                                );
                              },
                              onPointerCancel: (e) {
                                widget.controller
                                    .onPointerCancel(pointer: e.pointer);
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Layer 1: Page sheets in vertical column
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: _boardMarginHorizontal,
                                      vertical: _boardMarginVertical,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (int i = 0;
                                            i <
                                                widget.controller.pages
                                                    .length;
                                            i++) ...[
                                          _buildPageSheet(i),
                                          const SizedBox(
                                            height: AppConstants.pageGap,
                                          ),
                                        ],
                                        _buildAddPageButton(),
                                        const SizedBox(height: 48.0),
                                      ],
                                    ),
                                  ),

                                  // Layer 2: All text boxes across all pages
                                  for (int i = 0;
                                      i < widget.controller.pages.length;
                                      i++)
                                    for (final box in widget
                                        .controller.pages[i].textBoxes)
                                      TextBoxWidget(
                                        key: ValueKey(box.id),
                                        textBox: box,
                                        controller: widget.controller,
                                        isSelected: widget.controller
                                                .activeTextBoxId ==
                                            box.id,
                                        richController:
                                            _getOrCreateTextController(box),
                                        boardPosition: Offset(
                                          _boardMarginHorizontal +
                                              box.position.dx,
                                          _boardMarginVertical +
                                              AppConstants.pageHeaderHeight +
                                              i * AppConstants.pagePitch +
                                              box.position.dy,
                                        ),
                                      ),

                                  // Layer 3: Selection bounding box, handles, toolbar, and dragged strokes
                                  if (widget.controller.hasSelection &&
                                      widget.controller.selectionBounds !=
                                          null)
                                    _buildGlobalSelectionOverlay(
                                      _boardMarginHorizontal,
                                      _boardMarginVertical,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Floating Zoom Controls (Bottom-Right)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            tooltip: 'Zoom Out',
                            onPressed: _zoomOut,
                          ),
                          IconButton(
                            icon: const Icon(Icons.fit_screen, size: 18),
                            tooltip: 'Fit / Reset',
                            onPressed: _resetZoom,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            tooltip: 'Zoom In',
                            onPressed: _zoomIn,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddPageButton() {
    return SizedBox(
      width: AppConstants.defaultPageSize.width,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
        ),
        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
        label: const Text(
          'Add New Page',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () {
          widget.controller.addPage();
        },
      ),
    );
  }

  Widget _buildPageSheet(int pageIndex) {
    final page = widget.controller.pages[pageIndex];
    final isActivePage = widget.controller.activePageIndex == pageIndex;

    final renderedStrokes = isActivePage && widget.controller.isTransforming
        ? page.strokes
            .where((s) => !widget.controller.selectedStrokes.contains(s))
            .toList()
        : page.strokes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Header Indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, right: 4.0),
          child: SizedBox(
            width: AppConstants.defaultPageSize.width,
            height: 24.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActivePage
                        ? AppColors.primary
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Page ${pageIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.controller.pages.length > 1)
                  Tooltip(
                    message: 'Delete Page ${pageIndex + 1}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => widget.controller.deletePage(pageIndex),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Page Canvas Container (unclipped so margin notes and drags are visible)
        Container(
          width: AppConstants.defaultPageSize.width,
          height: AppConstants.defaultPageSize.height,
          decoration: BoxDecoration(
            color: AppColors.canvasBackground,
            borderRadius: BorderRadius.circular(2.0),
            border: Border.all(
              color: isActivePage
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.canvasBorder,
              width: isActivePage ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isActivePage
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.canvasShadow,
                blurRadius: 10.0,
                spreadRadius: 2.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              // 1. Page Background (plain, lined, or grid)
              CustomPaint(
                painter: PageBackgroundPainter(
                  template: widget.template,
                ),
              ),

              // 2. Completed Highlighters
              RepaintBoundary(
                child: CustomPaint(
                  painter: CompletedStrokesPainter(
                    renderedStrokes,
                    layer: StrokeLayer.highlightersOnly,
                  ),
                ),
              ),

              // 3. Active Highlighter (on active page)
              if (isActivePage)
                ValueListenableBuilder<List<StrokePoint>>(
                  valueListenable: widget.controller.currentStrokeNotifier,
                  builder: (context, currentPoints, _) {
                    if (widget.controller.activeTool != ToolType.highlighter ||
                        currentPoints.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return RepaintBoundary(
                      child: CustomPaint(
                        painter: ActiveStrokePainter(
                          points: currentPoints,
                          color: widget.controller.activeColor,
                          strokeWidth: widget.controller.strokeWidth,
                          toolType: widget.controller.activeTool,
                        ),
                      ),
                    );
                  },
                ),

              // 4. Completed Pens & Fountain Pens
              RepaintBoundary(
                child: CustomPaint(
                  painter: CompletedStrokesPainter(
                    renderedStrokes,
                    layer: StrokeLayer.pensOnly,
                  ),
                ),
              ),

              // 5. Active Pen / Fountain Pen (on active page)
              if (isActivePage)
                ValueListenableBuilder<List<StrokePoint>>(
                  valueListenable: widget.controller.currentStrokeNotifier,
                  builder: (context, currentPoints, _) {
                    if (widget.controller.activeTool == ToolType.highlighter ||
                        currentPoints.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return RepaintBoundary(
                      child: CustomPaint(
                        painter: ActiveStrokePainter(
                          points: currentPoints,
                          color: widget.controller.activeColor,
                          strokeWidth: widget.controller.strokeWidth,
                          toolType: widget.controller.activeTool,
                        ),
                      ),
                    );
                  },
                ),

              // 6. Eraser Visual Cursor (on active page)
              if (isActivePage)
                ValueListenableBuilder<Offset?>(
                  valueListenable: widget.controller.eraserPointerNotifier,
                  builder: (context, eraserPos, _) {
                    if (eraserPos == null) {
                      return const SizedBox.shrink();
                    }
                    return CustomPaint(
                      painter: EraserCursorPainter(
                        position: eraserPos,
                        radius: widget.controller.eraserRadius,
                        isAreaEraser: widget.controller.activeTool ==
                            ToolType.areaEraser,
                      ),
                    );
                  },
                ),

              // 7. Lasso in-progress freeform loop
              if (isActivePage)
                ValueListenableBuilder<List<Offset>>(
                  valueListenable: widget.controller.lassoPointsNotifier,
                  builder: (context, lassoPoints, _) {
                    if (lassoPoints.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return CustomPaint(
                      painter: LassoPathPainter(lassoPoints),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Global selection overlay rendered across the entire multi-page Column so dragged strokes,
  /// selection bounding boxes, and handles can cross page boundaries and margins without clipping.
  Widget _buildGlobalSelectionOverlay(
    double boardMarginHorizontal,
    double boardMarginVertical,
  ) {
    final activePageIdx = widget.controller.activePageIndex;
    final canvasOrigin = Offset(
      boardMarginHorizontal,
      boardMarginVertical +
          AppConstants.pageHeaderHeight +
          activePageIdx * AppConstants.pagePitch,
    );
    final globalBounds = widget.controller.selectionBounds!.shift(canvasOrigin);

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Dragged strokes floating above all pages and margins while transforming
          if (widget.controller.isTransforming)
            Transform.translate(
              offset: canvasOrigin,
              child: CustomPaint(
                painter: CompletedStrokesPainter(
                  widget.controller.selectedStrokes,
                ),
              ),
            ),

          // 2. Selection dashed bounding box, corner handles, and rotation stem
          IgnorePointer(
            ignoring: true,
            child: CustomPaint(
              painter: SelectionPainter(
                bounds: globalBounds,
                rotationAngle: widget.controller.selectionRotation,
              ),
            ),
          ),

          // 3. Floating Contextual Toolbar
          if (!widget.controller.isTransforming)
            SelectionToolbar(
              controller: widget.controller,
              bounds: globalBounds,
              rotationAngle: widget.controller.selectionRotation,
            ),
        ],
      ),
    );
  }
}
