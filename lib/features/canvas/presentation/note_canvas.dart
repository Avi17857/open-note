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
                      boundaryMargin: const EdgeInsets.symmetric(
                        horizontal: 400,
                        vertical: 600,
                      ),
                      minScale: AppConstants.minScale,
                      maxScale: AppConstants.maxScale,
                      panEnabled: isPanTool,
                      scaleEnabled: true,
                      constrained: false,
                      child: Center(
                        child: MouseRegion(
                          cursor: _currentCursor,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 36.0,
                              horizontal: 24.0,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int i = 0;
                                    i < widget.controller.pages.length;
                                    i++) ...[
                                  _buildPageSheet(i),
                                  const SizedBox(height: 28.0),
                                ],
                                _buildAddPageButton(),
                                const SizedBox(height: 48.0),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Header Indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, right: 4.0),
          child: SizedBox(
            width: AppConstants.defaultPageSize.width,
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

        // Page Canvas Container
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
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Canvas drawing surface and gesture listener
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) {
                      if (widget.controller.activePageIndex != pageIndex) {
                        widget.controller.setActivePage(pageIndex);
                      }
                      widget.controller.onPointerDown(
                        e.localPosition,
                        pointer: e.pointer,
                        kind: e.kind,
                        pressure: e.pressure,
                        buttons: e.buttons,
                      );
                    },
                    onPointerMove: (e) {
                      if (widget.controller.activePageIndex == pageIndex) {
                        widget.controller.onPointerMove(
                          e.localPosition,
                          pointer: e.pointer,
                          kind: e.kind,
                          pressure: e.pressure,
                          buttons: e.buttons,
                        );
                      }
                    },
                    onPointerUp: (e) {
                      if (widget.controller.activePageIndex == pageIndex) {
                        widget.controller.onPointerUp(
                          e.localPosition,
                          pointer: e.pointer,
                          kind: e.kind,
                          pressure: e.pressure,
                          buttons: e.buttons,
                        );
                      }
                    },
                    onPointerCancel: (e) {
                      if (widget.controller.activePageIndex == pageIndex) {
                        widget.controller.onPointerCancel(
                          pointer: e.pointer,
                        );
                      }
                    },
                    child: Stack(
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
                              page.strokes,
                              layer: StrokeLayer.highlightersOnly,
                            ),
                          ),
                        ),

                        // 3. Active Highlighter (on active page)
                        if (isActivePage)
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
                              page.strokes,
                              layer: StrokeLayer.pensOnly,
                            ),
                          ),
                        ),

                        // 5. Rich Text Box Containers for THIS page
                        for (final box in page.textBoxes)
                          TextBoxWidget(
                            key: ValueKey(box.id),
                            textBox: box,
                            controller: widget.controller,
                            isSelected:
                                widget.controller.activeTextBoxId == box.id,
                            richController: _getOrCreateTextController(box),
                          ),

                        // 6. Active Pen / Fountain Pen (on active page)
                        if (isActivePage)
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
                                    color: widget.controller.activeColor,
                                    strokeWidth: widget.controller.strokeWidth,
                                    toolType: widget.controller.activeTool,
                                  ),
                                ),
                              );
                            },
                          ),

                        // 7. Eraser Visual Cursor (on active page)
                        if (isActivePage)
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
                                  radius: widget.controller.eraserRadius,
                                  isAreaEraser: widget.controller.activeTool ==
                                      ToolType.areaEraser,
                                ),
                              );
                            },
                          ),

                        // 8. Lasso in-progress freeform loop
                        if (isActivePage)
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

                        // 9. Selection dashed bounding box and resize handles
                        if (isActivePage &&
                            widget.controller.hasSelection &&
                            widget.controller.selectionBounds != null)
                          CustomPaint(
                            painter: SelectionPainter(
                              bounds: widget.controller.selectionBounds!,
                              rotationAngle:
                                  widget.controller.selectionRotation,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 10. Floating contextual toolbar for selected strokes (rendered ON TOP of Listener)
                if (isActivePage &&
                    widget.controller.hasSelection &&
                    widget.controller.selectionBounds != null &&
                    !widget.controller.isTransforming)
                  SelectionToolbar(
                    controller: widget.controller,
                    bounds: widget.controller.selectionBounds!,
                    rotationAngle: widget.controller.selectionRotation,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
