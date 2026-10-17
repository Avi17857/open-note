import 'package:flutter/material.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';

class StrokeWidthPicker extends StatelessWidget {
  final CanvasController controller;

  const StrokeWidthPicker({super.key, required this.controller});

  static Future<void> show(BuildContext context, CanvasController controller) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(20),
        title: Text(
          switch (controller.activeTool) {
            ToolType.highlighter => 'Highlighter Width',
            ToolType.fountainPen => 'Fountain Pen Width',
            _ => 'Pen Width',
          },
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SizedBox(
          width: 320,
          child: StrokeWidthPicker(controller: controller),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isHighlighter = controller.activeTool == ToolType.highlighter;
        final currentWidth = controller.strokeWidth;
        final presets = isHighlighter
            ? const [12.0, 18.0, 24.0, 32.0, 40.0]
            : const [1.5, 3.0, 5.0, 8.0, 14.0];

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tip Preview
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: isHighlighter ? currentWidth * 1.5 : currentWidth,
                height: currentWidth,
                decoration: BoxDecoration(
                  color: controller.activeColor,
                  shape: isHighlighter ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isHighlighter ? BorderRadius.circular(2) : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${currentWidth.toStringAsFixed(1)} pt',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'Presets',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),

            // Preset Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: presets.map((w) {
                final isSelected = (currentWidth - w).abs() < 0.2;
                return ChoiceChip(
                  label: Text('${w.toInt()} pt'),
                  selected: isSelected,
                  selectedColor: AppColors.primaryLight.withValues(alpha: 0.3),
                  onSelected: (_) => controller.setStrokeWidth(w),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            const Text(
              'Fine Tuning',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),

            // Continuous Slider
            Slider(
              value: currentWidth.clamp(1.0, 48.0),
              min: 1.0,
              max: 48.0,
              divisions: 47,
              activeColor: AppColors.primary,
              label: '${currentWidth.toInt()} pt',
              onChanged: (val) => controller.setStrokeWidth(val),
            ),
          ],
        );
      },
    );
  }
}
