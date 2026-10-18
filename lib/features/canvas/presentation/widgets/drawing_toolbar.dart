import 'package:flutter/material.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/rich_text_span.dart';
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

                // Lasso Selection Controls
                if (activeTool == ToolType.lasso) ...[
                  if (controller.hasSelection) ...[
                    Tooltip(
                      message: 'Duplicate Selection',
                      child: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        onPressed: controller.duplicateSelection,
                      ),
                    ),
                    Tooltip(
                      message: 'Delete Selection',
                      child: IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Colors.red.shade700,
                        ),
                        onPressed: controller.deleteSelection,
                      ),
                    ),
                    Tooltip(
                      message: 'Deselect',
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: controller.deselect,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                    const SizedBox(width: 8),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tap or circle strokes to select',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                    const SizedBox(width: 12),
                  ],
                ],

                // Text Tool Formatting Bar (docked in top toolbar)
                if (activeTool == ToolType.text) ...[
                  // 1. Heading Selector Dropdown
                  _buildHeadingDropdown(context),

                  const SizedBox(width: 8),

                  // 2. Inline Style Toggles: B, I, U, S
                  _buildFormatToggleBtn(
                    label: 'B',
                    tooltip: 'Bold',
                    isBold: true,
                    isActive: controller.activeTextBold,
                    onTap: controller.toggleBold,
                  ),
                  const SizedBox(width: 4),
                  _buildFormatToggleBtn(
                    label: 'I',
                    tooltip: 'Italic',
                    isItalic: true,
                    isActive: controller.activeTextItalic,
                    onTap: controller.toggleItalic,
                  ),
                  const SizedBox(width: 4),
                  _buildFormatToggleBtn(
                    label: 'U',
                    tooltip: 'Underline',
                    isUnderline: true,
                    isActive: controller.activeTextUnderline,
                    onTap: controller.toggleUnderline,
                  ),
                  const SizedBox(width: 4),
                  _buildFormatToggleBtn(
                    label: 'S',
                    tooltip: 'Strikethrough',
                    isStrikethrough: true,
                    isActive: controller.activeTextStrikethrough,
                    onTap: controller.toggleStrikethrough,
                  ),

                  const SizedBox(width: 8),
                  const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                  const SizedBox(width: 8),

                  // 3. Text Font Color Picker Menu
                  _buildTextColorMenu(context),

                  const SizedBox(width: 4),

                  // 4. Text Highlight Color Menu
                  _buildTextHighlightMenu(context),

                  const SizedBox(width: 8),
                  const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                  const SizedBox(width: 8),

                  // 5. Spawn new text box button
                  Tooltip(
                    message: 'Add new text box',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Box', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        controller.addTextBox(const Offset(80, 100));
                      },
                    ),
                  ),

                  // 6. Delete & Done buttons (if a text box is focused)
                  if (controller.activeTextBox != null) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Delete text box',
                      child: IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Colors.red.shade700,
                        ),
                        onPressed: controller.deleteActiveTextBox,
                      ),
                    ),
                    Tooltip(
                      message: 'Done / Deselect',
                      child: IconButton(
                        icon: const Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: Color(0xFF007AFF),
                        ),
                        onPressed: controller.unfocusActiveTextBox,
                      ),
                    ),
                  ],

                  const SizedBox(width: 12),
                  const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                  const SizedBox(width: 12),
                ],

                // Color Palette Dots & Custom Color Picker (for drawing and recoloring selection)
                if (isDrawing ||
                    (activeTool == ToolType.lasso &&
                        controller.hasSelection)) ...[
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

  Widget _buildHeadingDropdown(BuildContext context) {
    final currentHeading = controller.activeTextHeading;

    return PopupMenuButton<HeadingLevel>(
      tooltip: 'Heading style',
      initialValue: currentHeading,
      onSelected: controller.setHeading,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentHeading == HeadingLevel.none
                  ? 'Body'
                  : currentHeading.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: HeadingLevel.none,
          child: Text('Body (Regular)'),
        ),
        const PopupMenuItem(
          value: HeadingLevel.h1,
          child: Text(
            'H1 - Heading 1',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        const PopupMenuItem(
          value: HeadingLevel.h2,
          child: Text(
            'H2 - Heading 2',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const PopupMenuItem(
          value: HeadingLevel.h3,
          child: Text(
            'H3 - Heading 3',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatToggleBtn({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
    bool isBold = false,
    bool isItalic = false,
    bool isUnderline = false,
    bool isStrikethrough = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF007AFF).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? const Color(0xFF007AFF) : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: TextDecoration.combine([
                if (isUnderline) TextDecoration.underline,
                if (isStrikethrough) TextDecoration.lineThrough,
              ]),
              color: isActive ? const Color(0xFF007AFF) : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextColorMenu(BuildContext context) {
    const colors = [
      Colors.black,
      Color(0xFFD32F2F), // Red
      Color(0xFF1976D2), // Blue
      Color(0xFF388E3C), // Green
      Color(0xFF7B1FA2), // Purple
      Color(0xFFF57C00), // Orange
    ];

    return PopupMenuButton<Color>(
      tooltip: 'Font Color',
      onSelected: controller.setTextColor,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.format_color_text_rounded, size: 16, color: Colors.black87),
            const SizedBox(width: 4),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: controller.activeTextColor ?? Colors.black87,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => colors.map((c) {
        return PopupMenuItem<Color>(
          value: c,
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                c == Colors.black
                    ? 'Black'
                    : '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextHighlightMenu(BuildContext context) {
    final highlights = [
      null,
      AppColors.highlighterPalette[0], // Yellow
      AppColors.highlighterPalette[1], // Green
      AppColors.highlighterPalette[2], // Cyan
      AppColors.highlighterPalette[3], // Pink
      AppColors.highlighterPalette[4], // Orange
    ];

    return PopupMenuButton<Color?>(
      tooltip: 'Highlight Background',
      onSelected: controller.setTextHighlight,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Icon(Icons.border_color_rounded, size: 16, color: Colors.black87),
      ),
      itemBuilder: (context) => highlights.map((c) {
        return PopupMenuItem<Color?>(
          value: c,
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: c ?? Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                c == null ? 'None (Clear)' : 'Highlight',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
