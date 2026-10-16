import 'package:flutter/material.dart';
import 'package:open_note/core/constants/app_constants.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/presentation/painters/active_stroke_painter.dart';
import 'package:open_note/features/canvas/presentation/painters/completed_strokes_painter.dart';
import 'package:open_note/features/canvas/presentation/painters/page_background_painter.dart';
import 'package:open_note/features/canvas/presentation/widgets/drawing_toolbar.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DrawingToolbar(controller: widget.controller),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              return InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(400),
                minScale: AppConstants.minScale,
                maxScale: AppConstants.maxScale,
                panEnabled: !widget.controller.isDrawing,
                scaleEnabled: !widget.controller.isDrawing,
                child: Center(
                  child: Container(
                    width: AppConstants.defaultPageSize.width,
                    height: AppConstants.defaultPageSize.height,
                    decoration: BoxDecoration(
                      color: AppColors.canvasBackground,
                      borderRadius: BorderRadius.circular(2.0),
                      border: Border.all(color: AppColors.canvasBorder, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.canvasShadow,
                          blurRadius: 10.0,
                          spreadRadius: 2.0,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) => widget.controller.onPointerDown(
                        e.localPosition,
                        kind: e.kind,
                      ),
                      onPointerMove: (e) =>
                          widget.controller.onPointerMove(e.localPosition),
                      onPointerUp: (e) =>
                          widget.controller.onPointerUp(e.localPosition),
                      child: ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Page Background (plain, lined, or grid)
                            CustomPaint(
                              painter: PageBackgroundPainter(
                                template: widget.template,
                              ),
                            ),

                            // 2. Completed Strokes (only repaints when a stroke finishes or erases)
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: CompletedStrokesPainter(
                                  widget.controller.strokes,
                                ),
                              ),
                            ),

                            // 3. Active Stroke in progress (ultra-lightweight live pointer)
                            ValueListenableBuilder<List<Offset>>(
                              valueListenable:
                                  widget.controller.currentStrokeNotifier,
                              builder: (context, currentPoints, _) {
                                return RepaintBoundary(
                                  child: CustomPaint(
                                    painter: ActiveStrokePainter(
                                      points: currentPoints,
                                      color: widget.controller.activeColor,
                                      strokeWidth:
                                          widget.controller.strokeWidth,
                                      toolType: widget.controller.activeTool,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
