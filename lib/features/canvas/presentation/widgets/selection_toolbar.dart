import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';

/// Floating contextual action bar positioned near selected strokes on the canvas.
class SelectionToolbar extends StatelessWidget {
  final CanvasController controller;
  final Rect bounds;

  const SelectionToolbar({
    super.key,
    required this.controller,
    required this.bounds,
  });

  /// Computes the bounding rectangle of the floating toolbar relative to page bounds.
  /// When rotation knob is at top, positions toolbar below the selection box to prevent
  /// any overlap or touch conflicts with the rotation knob. If near the bottom edge,
  /// places toolbar well above the rotation knob.
  static Rect getToolbarRect(
    Rect bounds, {
    double pageWidth = 600.0,
    double pageHeight = 850.0,
  }) {
    final centerLeft = bounds.center.dx;
    final leftPos = (centerLeft - 95).clamp(8.0, pageWidth - 190.0 - 8.0);

    if (bounds.top >= 36.0) {
      // Rotation handle is at top (bounds.top - 28)
      // Default: position below selection bounds (complete clearance from rotation knob)
      if (bounds.bottom + 14.0 <= pageHeight - 55.0) {
        return Rect.fromLTWH(leftPos, bounds.bottom + 14.0, 190, 44);
      } else {
        // Selection near bottom: position well above rotation knob
        return Rect.fromLTWH(leftPos, bounds.top - 82.0, 190, 44);
      }
    } else {
      // Rotation handle flipped below (bounds.bottom + 28)
      final topPos = (bounds.bottom + 58.0).clamp(8.0, pageHeight - 55.0);
      return Rect.fromLTWH(leftPos, topPos, 190, 44);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rect = getToolbarRect(bounds);

    return Positioned(
      top: rect.top,
      left: rect.left,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // Absorbs taps so they do not fall through to the canvas
        child: Material(
          elevation: 4,
          shadowColor: const Color(0x33000000),
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Duplicate',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: controller.duplicateSelection,
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.rotate_right_rounded, size: 18),
                  tooltip: 'Rotate 90°',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: () => controller.rotateSelection90(),
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.red.shade700,
                  ),
                  tooltip: 'Delete',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: controller.deleteSelection,
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Deselect',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: controller.deselect,
                ),
              ],
          ),
        ),
      ),
      ),
    );
  }
}
