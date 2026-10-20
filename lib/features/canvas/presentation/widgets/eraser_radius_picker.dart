import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/presentation/widgets/tool_icon.dart';

class EraserRadiusPicker extends StatelessWidget {
  final CanvasController controller;

  const EraserRadiusPicker({super.key, required this.controller});

  static Future<void> show(BuildContext context, CanvasController controller) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => EraserRadiusPicker(controller: controller),
    );
  }

  static const List<double> _presets = [8.0, 16.0, 28.0, 45.0];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final radius = controller.eraserRadius;
        final isArea = controller.activeTool == ToolType.areaEraser;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Eraser Settings',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Eraser Type Selector (Area vs Stroke)
              SegmentedButton<ToolType>(
                style: SegmentedButton.styleFrom(
                  backgroundColor: controller.isDarkMode
                      ? const Color(0xFF2C2C36)
                      : Colors.grey.shade100,
                  foregroundColor: controller.isDarkMode
                      ? Colors.white70
                      : Colors.black87,
                  selectedForegroundColor: Colors.white,
                  selectedBackgroundColor: isArea
                      ? Colors.orange.shade800
                      : Colors.red.shade800,
                  side: BorderSide(
                    color: controller.isDarkMode
                        ? const Color(0xFF444455)
                        : Colors.grey.shade300,
                  ),
                ),
                segments: [
                  ButtonSegment<ToolType>(
                    value: ToolType.areaEraser,
                    icon: ToolIcon(
                      tool: ToolType.areaEraser,
                      size: 20,
                      isSelected: isArea,
                      isDarkMode: controller.isDarkMode,
                    ),
                    label: const Text('Area (Precision)'),
                  ),
                  ButtonSegment<ToolType>(
                    value: ToolType.strokeEraser,
                    icon: ToolIcon(
                      tool: ToolType.strokeEraser,
                      size: 20,
                      isSelected: !isArea,
                      isDarkMode: controller.isDarkMode,
                    ),
                    label: const Text('Stroke (Whole Line)'),
                  ),
                ],
                selected: {
                  isArea ? ToolType.areaEraser : ToolType.strokeEraser,
                },
                onSelectionChanged: (selected) {
                  controller.setTool(selected.first);
                },
              ),

              const SizedBox(height: 20),

              // Visual Size Preview Circle
              Container(
                height: 100,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Container(
                  width: (radius * 2).clamp(12.0, 90.0),
                  height: (radius * 2).clamp(12.0, 90.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isArea
                        ? const Color(0x22FF9800)
                        : const Color(0x22F44336),
                    border: Border.all(
                      color: isArea
                          ? const Color(0xB3FF9800)
                          : const Color(0xB3F44336),
                      width: 2.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${radius.toInt()}pt',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isArea
                            ? Colors.orange.shade900
                            : Colors.red.shade900,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Preset Quick Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _presets.map((preset) {
                  final isSelected = (radius - preset).abs() < 1.0;
                  return ChoiceChip(
                    label: Text('${preset.toInt()}pt'),
                    selected: isSelected,
                    onSelected: (_) => controller.setEraserRadius(preset),
                  );
                }).toList(),
              ),

              const SizedBox(height: 8),

              // Fine-tuning Slider
              Row(
                children: [
                  const Icon(Icons.circle, size: 12, color: Colors.grey),
                  Expanded(
                    child: Slider(
                      value: radius.clamp(6.0, 60.0),
                      min: 6.0,
                      max: 60.0,
                      divisions: 54,
                      label: '${radius.toInt()}pt',
                      onChanged: (val) => controller.setEraserRadius(val),
                    ),
                  ),
                  const Icon(Icons.circle, size: 28, color: Colors.grey),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
