import 'package:flutter/material.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';

class DrawingToolbar extends StatelessWidget {
  final CanvasController controller;

  const DrawingToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: const [
              BoxShadow(
                color: Color(0x15000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
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
                selected: {controller.activeTool},
                onSelectionChanged: (newSelection) {
                  controller.setTool(newSelection.first);
                },
                showSelectedIcon: false,
              ),

              const SizedBox(width: 12),
              const VerticalDivider(width: 1, indent: 8, endIndent: 8),
              const SizedBox(width: 12),

              // Color Dots (hidden when eraser is active)
              if (!controller.activeTool.isEraser) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: AppColors.penPalette.map((color) {
                    final isSelected = controller.activeColor == color;
                    return GestureDetector(
                      onTap: () => controller.setColor(color),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3.0),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey.shade400,
                            width: isSelected ? 2.5 : 1.0,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
