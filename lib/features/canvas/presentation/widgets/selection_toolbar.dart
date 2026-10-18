import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/services/lasso_service.dart';

/// Floating contextual action bar positioned near selected strokes on the canvas.
class SelectionToolbar extends StatelessWidget {
  final CanvasController controller;
  final Rect bounds;
  final double rotationAngle;
  final Offset? screenPosition;

  const SelectionToolbar({
    super.key,
    required this.controller,
    required this.bounds,
    this.rotationAngle = 0.0,
    this.screenPosition,
  });

  /// Computes the bounding rectangle of the floating toolbar relative to page bounds.
  /// When rotation knob is at top, positions toolbar below the selection box to prevent
  /// any overlap or touch conflicts with the rotation knob. If near the bottom edge,
  /// places toolbar well above the rotation knob.
  static Rect getToolbarRect(
    Rect bounds, {
    double rotationAngle = 0.0,
    double? pageWidth,
    double? pageHeight,
  }) {
    final effectiveBounds = rotationAngle == 0.0
        ? bounds
        : LassoService.computeRotatedEnclosingBounds(bounds, rotationAngle);
    final centerLeft = effectiveBounds.center.dx;
    final leftPos = pageWidth != null
        ? (centerLeft - 95).clamp(8.0, pageWidth - 190.0 - 8.0)
        : centerLeft - 95;

    if (effectiveBounds.top >= 36.0) {
      if (pageHeight != null &&
          effectiveBounds.bottom + 14.0 > pageHeight - 55.0) {
        return Rect.fromLTWH(leftPos, effectiveBounds.top - 82.0, 190, 44);
      } else {
        return Rect.fromLTWH(leftPos, effectiveBounds.bottom + 14.0, 190, 44);
      }
    } else {
      final topPos = pageHeight != null
          ? (effectiveBounds.bottom + 58.0).clamp(8.0, pageHeight - 55.0)
          : effectiveBounds.bottom + 14.0;
      return Rect.fromLTWH(leftPos, topPos, 190, 44);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (double left, double top) = screenPosition != null
        ? (screenPosition!.dx, screenPosition!.dy)
        : () {
            final rect = getToolbarRect(bounds, rotationAngle: rotationAngle);
            return (rect.left, rect.top);
          }();

    return Positioned(
      top: top,
      left: left,
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
