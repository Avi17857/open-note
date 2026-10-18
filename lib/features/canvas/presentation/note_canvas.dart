import 'package:flutter/material.dart';
import 'package:open_note/core/constants/app_constants.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
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
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
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
      ToolType.strokeEraser || ToolType.areaEraser => SystemMouseCursors.click,
      ToolType.pan => SystemMouseCursors.grab,
    };
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
                  // Interactive Pan / Zoom Viewport
                  InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: const EdgeInsets.all(400),
                    minScale: AppConstants.minScale,
                    maxScale: AppConstants.maxScale,
                    panEnabled: isPanTool,
                    scaleEnabled: true,
                    child: Center(
                      child: MouseRegion(
                        cursor: _currentCursor,
                        child: Container(
                          width: AppConstants.defaultPageSize.width,
                          height: AppConstants.defaultPageSize.height,
                          decoration: BoxDecoration(
                            color: AppColors.canvasBackground,
                            borderRadius: BorderRadius.circular(2.0),
                            border: Border.all(
                              color: AppColors.canvasBorder,
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.canvasShadow,
                                blurRadius: 10.0,
                                spreadRadius: 2.0,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRect(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Canvas drawing surface and gesture listener
                                Positioned.fill(
                                  child: Listener(
                                    behavior: HitTestBehavior.opaque,
                                    onPointerDown: (e) =>
                                        widget.controller.onPointerDown(
                                      e.localPosition,
                                      pointer: e.pointer,
                                      kind: e.kind,
                                      pressure: e.pressure,
                                      buttons: e.buttons,
                                    ),
                                    onPointerMove: (e) => widget.controller
                                        .onPointerMove(
                                      e.localPosition,
                                      pointer: e.pointer,
                                      kind: e.kind,
                                      pressure: e.pressure,
                                      buttons: e.buttons,
                                    ),
                                    onPointerUp: (e) =>
                                        widget.controller.onPointerUp(
                                      e.localPosition,
                                      pointer: e.pointer,
                                      kind: e.kind,
                                      pressure: e.pressure,
                                      buttons: e.buttons,
                                    ),
                                    onPointerCancel: (e) =>
                                        widget.controller.onPointerCancel(
                                      pointer: e.pointer,
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // 1. Page Background (plain, lined, or grid)
                                        CustomPaint(
                                          painter: PageBackgroundPainter(
                                            template: widget.template,
                                          ),
                                        ),

                                        // 2. Completed Highlighters (always render behind ink)
                                        RepaintBoundary(
                                          child: CustomPaint(
                                            painter: CompletedStrokesPainter(
                                              widget.controller.strokes,
                                              layer: StrokeLayer.highlightersOnly,
                                            ),
                                          ),
                                        ),

                                        // 3. Active Highlighter (while drawing, renders behind existing pen notes!)
                                        ValueListenableBuilder<List<StrokePoint>>(
                                          valueListenable:
                                              widget.controller.currentStrokeNotifier,
                                          builder: (context, currentPoints, _) {
                                            if (widget.controller.activeTool !=
                                                    ToolType.highlighter ||
                                                currentPoints.isEmpty) {
                                              return const SizedBox.shrink();
                                            }
                                            return RepaintBoundary(
                                              child: CustomPaint(
                                                painter: ActiveStrokePainter(
                                                  points: currentPoints,
                                                  color:
                                                      widget.controller.activeColor,
                                                  strokeWidth:
                                                      widget.controller.strokeWidth,
                                                  toolType:
                                                      widget.controller.activeTool,
                                                ),
                                              ),
                                            );
                                          },
                                        ),

                                        // 4. Completed Pens & Fountain Pens (crisp, on top of highlighters)
                                        RepaintBoundary(
                                          child: CustomPaint(
                                            painter: CompletedStrokesPainter(
                                              widget.controller.strokes,
                                              layer: StrokeLayer.pensOnly,
                                            ),
                                          ),
                                        ),

                                        // 5. Active Pen / Fountain Pen (renders on top of everything)
                                        ValueListenableBuilder<List<StrokePoint>>(
                                          valueListenable:
                                              widget.controller.currentStrokeNotifier,
                                          builder: (context, currentPoints, _) {
                                            if (widget.controller.activeTool ==
                                                    ToolType.highlighter ||
                                                currentPoints.isEmpty) {
                                              return const SizedBox.shrink();
                                            }
                                            return RepaintBoundary(
                                              child: CustomPaint(
                                                painter: ActiveStrokePainter(
                                                  points: currentPoints,
                                                  color:
                                                      widget.controller.activeColor,
                                                  strokeWidth:
                                                      widget.controller.strokeWidth,
                                                  toolType:
                                                      widget.controller.activeTool,
                                                ),
                                              ),
                                            );
                                          },
                                        ),

                                        // 6. Eraser Visual Cursor (Ring under finger/stylus when erasing)
                                        ValueListenableBuilder<Offset?>(
                                          valueListenable:
                                              widget.controller.eraserPointerNotifier,
                                          builder: (context, eraserPos, _) {
                                            if (eraserPos == null) {
                                              return const SizedBox.shrink();
                                            }
                                            return CustomPaint(
                                              painter: EraserCursorPainter(
                                                position: eraserPos,
                                                radius:
                                                    widget.controller.eraserRadius,
                                                isAreaEraser: widget.controller
                                                        .activeTool ==
                                                    ToolType.areaEraser,
                                              ),
                                            );
                                          },
                                        ),

                                        // 7. Lasso in-progress freeform loop
                                        ValueListenableBuilder<List<Offset>>(
                                          valueListenable:
                                              widget.controller.lassoPointsNotifier,
                                          builder: (context, lassoPoints, _) {
                                            if (lassoPoints.isEmpty) {
                                              return const SizedBox.shrink();
                                            }
                                            return CustomPaint(
                                              painter: LassoPathPainter(lassoPoints),
                                            );
                                          },
                                        ),

                                        // 8. Selection dashed bounding box and resize handles
                                        if (widget.controller.hasSelection &&
                                            widget.controller.selectionBounds != null)
                                          CustomPaint(
                                            painter: SelectionPainter(
                                              bounds:
                                                  widget.controller.selectionBounds!,
                                              rotationAngle:
                                                  widget.controller.selectionRotation,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),

                                // 9. Floating contextual toolbar for selected strokes (rendered ON TOP of Listener)
                                // Automatically hidden while actively transforming (moving, scaling, rotating)
                                if (widget.controller.hasSelection &&
                                    widget.controller.selectionBounds != null &&
                                    !widget.controller.isTransforming)
                                  SelectionToolbar(
                                    controller: widget.controller,
                                    bounds: widget.controller.selectionBounds!,
                                    rotationAngle:
                                        widget.controller.selectionRotation,
                                  ),
                              ],
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
}
