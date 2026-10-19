import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/models/note_image.dart';
import 'package:open_note/features/canvas/models/tool_type.dart';
import 'package:open_note/features/canvas/presentation/widgets/unbounded_hit_test.dart';

enum ImageCorner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// An interactive, movable, and resizable raster image widget placed directly on the canvas page.
class NoteImageWidget extends StatefulWidget {
  final NoteImage image;
  final CanvasController controller;
  final bool isSelected;
  final int pageIndex;

  const NoteImageWidget({
    super.key,
    required this.image,
    required this.controller,
    required this.isSelected,
    required this.pageIndex,
  });

  @override
  State<NoteImageWidget> createState() => _NoteImageWidgetState();
}

class _NoteImageWidgetState extends State<NoteImageWidget> {
  bool _isDragging = false;
  Offset? _dragStartPos;
  double? _dragInitialX;
  double? _dragInitialY;

  bool _isResizing = false;
  Offset? _resizeStartPos;
  double? _resizeInitialWidth;
  double? _resizeInitialHeight;
  double? _resizeInitialX;
  double? _resizeInitialY;

  @override
  Widget build(BuildContext context) {
    final canInteract = widget.controller.activeTool == ToolType.text ||
        widget.controller.activeTool == ToolType.lasso ||
        widget.isSelected;
    final isSelected = widget.isSelected;
    final img = widget.image;

    return Positioned(
      left: img.position.dx,
      top: img.position.dy,
      width: img.width,
      height: img.height,
      child: UnboundedHitTest(
        child: UnboundedHitTestStack(
          clipBehavior: Clip.none,
          children: [
            // 1. Image Container & Drag Detector
            IgnorePointer(
              ignoring: !canInteract,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (canInteract) {
                    widget.controller.selectImage(img.id);
                  }
                },
                onPanStart: isSelected
                    ? (details) {
                        widget.controller.beginImageTransform();
                        setState(() => _isDragging = true);
                        _dragStartPos = details.globalPosition;
                        _dragInitialX = img.position.dx;
                        _dragInitialY = img.position.dy;
                      }
                    : null,
                onPanUpdate: isSelected
                    ? (details) {
                        if (!_isDragging || _dragStartPos == null) return;
                        final scale = widget.controller.canvasScale;
                        final delta = (details.globalPosition - _dragStartPos!) / scale;
                        final newX = _dragInitialX! + delta.dx;
                        final newY = _dragInitialY! + delta.dy;
                        widget.controller.updateImagePosition(
                          img.id,
                          Offset(newX, newY),
                        );
                      }
                    : null,
                onPanEnd: isSelected
                    ? (_) {
                        setState(() => _isDragging = false);
                        _dragStartPos = null;
                        widget.controller.transferImageIfNeeded(img.id);
                        widget.controller.commitImageTransform();
                      }
                    : null,
                child: MouseRegion(
                  cursor: isSelected ? SystemMouseCursors.move : SystemMouseCursors.click,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.2),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.memory(
                        img.bytes,
                        fit: BoxFit.fill,
                        width: img.width,
                        height: img.height,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                              size: 32,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. Corner Resize Handles (when selected)
            if (isSelected) ...[
              _buildCornerHandle(ImageCorner.topLeft, -14, -14),
              _buildCornerHandle(ImageCorner.topRight, -14, img.width - 14),
              _buildCornerHandle(ImageCorner.bottomLeft, img.height - 14, -14),
              _buildCornerHandle(ImageCorner.bottomRight, img.height - 14, img.width - 14),
            ],

            // 3. Floating Contextual Toolbar (Floats 10px below image with explicit height)
            if (isSelected)
              Positioned(
                top: img.height + 10,
                left: -60,
                right: -60,
                height: 44,
                child: Center(
                  child: _buildActionToolbar(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerHandle(ImageCorner corner, double top, double left) {
    final cursor = (corner == ImageCorner.topLeft || corner == ImageCorner.bottomRight)
        ? SystemMouseCursors.resizeUpLeftDownRight
        : SystemMouseCursors.resizeUpRightDownLeft;

    return Positioned(
      key: Key('image_corner_handle_${corner.name}'),
      top: top,
      left: left,
      width: 28,
      height: 28,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            widget.controller.beginImageTransform();
            setState(() {
              _isResizing = true;
            });
            _resizeStartPos = details.globalPosition;
            _resizeInitialWidth = widget.image.width;
            _resizeInitialHeight = widget.image.height;
            _resizeInitialX = widget.image.position.dx;
            _resizeInitialY = widget.image.position.dy;
          },
          onPanUpdate: (details) {
            if (!_isResizing || _resizeStartPos == null) return;
            final scale = widget.controller.canvasScale;
            final delta = (details.globalPosition - _resizeStartPos!) / scale;
            final aspectRatio = _resizeInitialWidth! / _resizeInitialHeight!;

            double newWidth = _resizeInitialWidth!;
            double newHeight = _resizeInitialHeight!;
            double newX = _resizeInitialX!;
            double newY = _resizeInitialY!;

            switch (corner) {
              case ImageCorner.bottomRight:
                newWidth = max(NoteImage.minSize, _resizeInitialWidth! + delta.dx);
                newHeight = newWidth / aspectRatio;
                break;
              case ImageCorner.bottomLeft:
                newWidth = max(NoteImage.minSize, _resizeInitialWidth! - delta.dx);
                newHeight = newWidth / aspectRatio;
                newX = _resizeInitialX! + (_resizeInitialWidth! - newWidth);
                break;
              case ImageCorner.topRight:
                newWidth = max(NoteImage.minSize, _resizeInitialWidth! + delta.dx);
                newHeight = newWidth / aspectRatio;
                newY = _resizeInitialY! + (_resizeInitialHeight! - newHeight);
                break;
              case ImageCorner.topLeft:
                newWidth = max(NoteImage.minSize, _resizeInitialWidth! - delta.dx);
                newHeight = newWidth / aspectRatio;
                newX = _resizeInitialX! + (_resizeInitialWidth! - newWidth);
                newY = _resizeInitialY! + (_resizeInitialHeight! - newHeight);
                break;
            }

            widget.image.position = Offset(newX, newY);
            widget.image.width = newWidth;
            widget.image.height = newHeight;
            widget.controller.updateImage(widget.image);
          },
          onPanEnd: (_) {
            setState(() {
              _isResizing = false;
            });
            _resizeStartPos = null;
            widget.controller.commitImageTransform();
          },
          onPanCancel: () {
            setState(() {
              _isResizing = false;
            });
            _resizeStartPos = null;
          },
          child: Container(
            width: 28,
            height: 28,
            color: Colors.transparent,
            alignment: Alignment.center,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF007AFF),
                  width: 2.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionToolbar() {
    return Center(
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Bring to Front',
                child: IconButton(
                  key: const Key('image_bring_to_front_button'),
                  icon: const Icon(Icons.flip_to_front_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    widget.controller.bringImageToFront(widget.image.id);
                  },
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Send to Back',
                child: IconButton(
                  key: const Key('image_send_to_back_button'),
                  icon: const Icon(Icons.flip_to_back_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    widget.controller.sendImageToBack(widget.image.id);
                  },
                ),
              ),
              const SizedBox(width: 4),
              Container(width: 1, height: 16, color: Colors.grey.shade300),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Delete image',
                child: IconButton(
                  key: const Key('image_delete_button'),
                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade600),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    widget.controller.deleteImage(widget.image.id);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
