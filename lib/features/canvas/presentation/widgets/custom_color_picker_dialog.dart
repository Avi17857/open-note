import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';

class CustomColorPickerDialog extends StatefulWidget {
  final CanvasController controller;

  const CustomColorPickerDialog({super.key, required this.controller});

  static Future<Color?> show(BuildContext context, CanvasController controller) {
    return showDialog<Color>(
      context: context,
      builder: (context) => CustomColorPickerDialog(controller: controller),
    );
  }

  @override
  State<CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<CustomColorPickerDialog> {
  late HSVColor _hsvColor;
  late TextEditingController _hexController;
  bool _isHexEditing = false;

  static const List<Color> _quickSwatches = [
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Deep Purple
    Color(0xFF3F51B5), // Indigo
    Color(0xFF00BCD4), // Cyan
    Color(0xFF009688), // Teal
    Color(0xFF8BC34A), // Light Green
    Color(0xFFFFC107), // Amber
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFF212121), // Charcoal
    Color(0xFFFFFFFF), // White
  ];

  @override
  void initState() {
    super.initState();
    final initialColor = widget.controller.activeColor.withValues(alpha: 1.0);
    _hsvColor = HSVColor.fromColor(initialColor);
    _hexController = TextEditingController(text: _colorToHex(_hsvColor.toColor()));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '$r$g$b'.toUpperCase();
  }

  void _updateFromHsv(HSVColor hsv) {
    setState(() {
      _hsvColor = hsv;
      if (!_isHexEditing) {
        _hexController.text = _colorToHex(_hsvColor.toColor());
      }
    });
  }

  void _onHexChanged(String value) {
    final clean = value.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final parsed = int.tryParse(clean, radix: 16);
      if (parsed != null) {
        _isHexEditing = true;
        _updateFromHsv(HSVColor.fromColor(Color(0xFF000000 | parsed)));
        _isHexEditing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighter = widget.controller.activeTool == ToolType.highlighter;
    final currentColor = _hsvColor.toColor();
    final previewColor = isHighlighter
        ? currentColor.withValues(alpha: 0.38)
        : currentColor;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isHighlighter ? Icons.highlight : Icons.palette,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(isHighlighter ? 'Highlighter Color' : 'Custom Color'),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 2D Saturation / Value Box
              SizedBox(
                height: 160,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;

                    return GestureDetector(
                      onPanDown: (details) =>
                          _handleSvDrag(details.localPosition, width, height),
                      onPanUpdate: (details) =>
                          _handleSvDrag(details.localPosition, width, height),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            // Base Hue
                            Container(
                              decoration: BoxDecoration(
                                color: HSVColor.fromAHSV(
                                  1.0,
                                  _hsvColor.hue,
                                  1.0,
                                  1.0,
                                ).toColor(),
                              ),
                            ),
                            // Saturation Gradient (Horizontal: white to transparent)
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [Colors.white, Colors.transparent],
                                ),
                              ),
                            ),
                            // Value Gradient (Vertical: transparent to black)
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black],
                                ),
                              ),
                            ),
                            // Indicator Reticle
                            Positioned(
                              left: (_hsvColor.saturation * width).clamp(0.0, width) - 10,
                              top: ((1.0 - _hsvColor.value) * height).clamp(0.0, height) - 10,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 1D Rainbow Hue Slider
              SizedBox(
                height: 24,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    return GestureDetector(
                      onPanDown: (details) =>
                          _handleHueDrag(details.localPosition.dx, width),
                      onPanUpdate: (details) =>
                          _handleHueDrag(details.localPosition.dx, width),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFF0000),
                                    Color(0xFFFFFF00),
                                    Color(0xFF00FF00),
                                    Color(0xFF00FFFF),
                                    Color(0xFF0000FF),
                                    Color(0xFFFF00FF),
                                    Color(0xFFFF0000),
                                  ],
                                ),
                              ),
                            ),
                            // Hue Thumb Indicator
                            Positioned(
                              left: ((_hsvColor.hue / 360.0) * width).clamp(0.0, width) - 8,
                              top: 2,
                              child: Container(
                                width: 16,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.black26),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Hex Input and Color Preview
              Row(
                children: [
                  // Color Preview Chip
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: previewColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Hex Text Field
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      decoration: const InputDecoration(
                        prefixText: '# ',
                        labelText: 'Hex Code',
                        isDense: true,
                        counterText: '',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      maxLength: 6,
                      onChanged: _onHexChanged,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Quick Swatches
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quick Swatches',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickSwatches.map((color) {
                  return GestureDetector(
                    onTap: () => _updateFromHsv(HSVColor.fromColor(color)),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isHighlighter ? color.withValues(alpha: 0.38) : color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _hsvColor.toColor().toARGB32() == color.toARGB32()
                              ? Colors.black
                              : Colors.grey.shade300,
                          width: _hsvColor.toColor().toARGB32() == color.toARGB32() ? 2.0 : 1.0,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.controller.addCustomColor(previewColor);
            Navigator.of(context).pop(previewColor);
          },
          child: const Text('Select'),
        ),
      ],
    );
  }

  void _handleSvDrag(Offset localPos, double width, double height) {
    final s = (localPos.dx / width).clamp(0.0, 1.0);
    final v = (1.0 - (localPos.dy / height)).clamp(0.0, 1.0);
    _updateFromHsv(_hsvColor.withSaturation(s).withValue(v));
  }

  void _handleHueDrag(double dx, double width) {
    final h = (dx / width).clamp(0.0, 1.0) * 360.0;
    _updateFromHsv(_hsvColor.withHue(h >= 360.0 ? 0.0 : h));
  }
}
