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
  static Rect getToolbarRect(Rect bounds) {
    final showBelow = bounds.top < 60;
    final topPos = showBelow ? bounds.bottom + 8 : bounds.top - 56;
    final centerLeft = bounds.center.dx;
    return Rect.fromLTWH(centerLeft - 80, topPos, 160, 50);
  }

  @override
  Widget build(BuildContext context) {
    // If selection is near top of canvas, position toolbar below the bounds
    final showBelow = bounds.top < 60;
    final topPos = showBelow ? bounds.bottom + 12 : bounds.top - 52;
    final centerLeft = bounds.center.dx;

    return Positioned(
      top: topPos,
      left: centerLeft - 75,
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
    );
  }
}
