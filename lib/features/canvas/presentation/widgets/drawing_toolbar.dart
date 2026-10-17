import 'package:flutter/material.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/presentation/widgets/custom_color_picker_dialog.dart';
import 'package:open_note/features/canvas/presentation/widgets/eraser_radius_picker.dart';
import 'package:open_note/features/canvas/presentation/widgets/stroke_width_picker.dart';

class DrawingToolbar extends StatelessWidget {
  final CanvasController controller;

  const DrawingToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final activeTool = controller.activeTool;
        final isDrawing = activeTool.isDrawingTool;
        final currentPalette = activeTool == ToolType.highlighter
            ? AppColors.highlighterPalette
            : AppColors.penPalette;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x15000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tool Selector (Segmented)
                SegmentedButton<ToolType>(
                  segments: ToolType.values.map((tool) {
                    return ButtonSegment<ToolType>(
                      value: tool,
                      icon: Icon(tool.icon, size: 20),
                      tooltip: tool.label,
                    );
                  }).toList(),
                  selected: {activeTool},
                  onSelectionChanged: (newSelection) {
                    controller.setTool(newSelection.first);
                  },
                  showSelectedIcon: false,
                ),

                const SizedBox(width: 12),
                const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                const SizedBox(width: 12),

                // Stroke Width Button (only shown for drawing tools)
                if (isDrawing) ...[
                  Tooltip(
                    message: 'Stroke Thickness',
                    child: InkWell(
                      onTap: () => StrokeWidthPicker.show(context, controller),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              alignment: Alignment.center,
                              child: Container(
                                width: controller.strokeWidth.clamp(3.0, 16.0),
                                height: controller.strokeWidth.clamp(3.0, 16.0),
                                decoration: BoxDecoration(
                                  color: controller.activeColor,
                                  shape: activeTool == ToolType.highlighter
                                      ? BoxShape.rectangle
                                      : BoxShape.circle,
                                  borderRadius:
                                      activeTool == ToolType.highlighter
                                          ? BorderRadius.circular(2)
                                          : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${controller.strokeWidth.toInt()}pt',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                  const SizedBox(width: 12),
                ],

                // Eraser Settings Button (only shown for eraser tools)
                if (activeTool.isEraser) ...[
                  Tooltip(
                    message: 'Eraser Size & Mode',
                    child: InkWell(
                      onTap: () => EraserRadiusPicker.show(context, controller),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              activeTool == ToolType.areaEraser
                                  ? Icons.cleaning_services
                                  : Icons.auto_fix_normal,
                              size: 16,
                              color: activeTool == ToolType.areaEraser
                                  ? Colors.orange.shade800
                                  : Colors.red.shade800,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${controller.eraserRadius.toInt()}pt',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                  const SizedBox(width: 12),
                ],

                // Color Palette Dots & Custom Color Picker (changes between pen & highlighter)
                if (isDrawing) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...currentPalette.map((color) {
                        final isSelected =
                            controller.activeColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () => controller.setColor(color),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3.0),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color,
                              shape: activeTool == ToolType.highlighter
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                              borderRadius: activeTool == ToolType.highlighter
                                  ? BorderRadius.circular(4)
                                  : null,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                                width: isSelected ? 2.5 : 1.0,
                              ),
                            ),
                          ),
                        );
                      }),

                      // Custom colors chosen by user
                      ...controller.customColors
                          .where((c) =>
                              !currentPalette.any((p) => p.toARGB32() == c.toARGB32()))
                          .map((color) {
                        final isSelected =
                            controller.activeColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () => controller.setColor(color),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3.0),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color,
                              shape: activeTool == ToolType.highlighter
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                              borderRadius: activeTool == ToolType.highlighter
                                  ? BorderRadius.circular(4)
                                  : null,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                                width: isSelected ? 2.5 : 1.0,
                              ),
                            ),
                          ),
                        );
                      }),

                      // Custom Color Picker Button
                      Tooltip(
                        message: 'Custom Color',
                        child: InkWell(
                          onTap: () =>
                              CustomColorPickerDialog.show(context, controller),
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.shade400,
                                width: 1.0,
                              ),
                            ),
                            child: const Icon(
                              Icons.palette_outlined,
                              size: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                  const SizedBox(width: 12),
                ],

                // Undo / Redo
                IconButton(
                  icon: const Icon(Icons.undo, size: 20),
                  tooltip: 'Undo',
                  onPressed: controller.canUndo ? controller.undo : null,
                ),
                IconButton(
                  icon: const Icon(Icons.redo, size: 20),
                  tooltip: 'Redo',
                  onPressed: controller.canRedo ? controller.redo : null,
                ),

                // Clear Page
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Clear Page',
                  onPressed: controller.strokes.isNotEmpty
                      ? () => _showClearDialog(context)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Canvas?'),
        content: const Text('Are you sure you want to clear all strokes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              controller.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
