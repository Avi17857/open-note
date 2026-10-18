import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_note/core/constants/app_constants.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/controllers/rich_text_editing_controller.dart';
import 'package:open_note/features/canvas/models/note_text_box.dart';

/// An interactive, movable, and resizable rich text box placed directly on the canvas page.
class TextBoxWidget extends StatefulWidget {
  final NoteTextBox textBox;
  final CanvasController controller;
  final bool isSelected;
  final RichTextEditingController richController;
  final Offset? boardPosition;

  const TextBoxWidget({
    super.key,
    required this.textBox,
    required this.controller,
    required this.isSelected,
    required this.richController,
    this.boardPosition,
  });

  @override
  State<TextBoxWidget> createState() => _TextBoxWidgetState();
}

class _TextBoxWidgetState extends State<TextBoxWidget> {
  late final FocusNode _focusNode;
  bool _isDragging = false;
  Offset? _dragStartPos;
  double? _dragInitialX;
  double? _dragInitialY;

  bool _isResizing = false;
  double? _resizeStartX;
  double? _resizeInitialWidth;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);

    if (widget.isSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.controller.setActiveRichTextController(widget.richController);
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant TextBoxWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.controller.setActiveRichTextController(widget.richController);
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        }
      });
    } else if (!widget.isSelected && oldWidget.isSelected) {
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      widget.controller.selectTextBox(widget.textBox.id);
      widget.controller.setActiveRichTextController(widget.richController);
    } else {
      if (widget.controller.activeTextBoxId == widget.textBox.id) {
        widget.controller.setActiveRichTextController(null);
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final box = widget.textBox;

    final renderLeft = widget.boardPosition?.dx ?? box.position.dx;
    final renderTop = widget.boardPosition?.dy ?? box.position.dy;

    return Positioned(
      left: renderLeft,
      top: renderTop,
      width: box.width,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent, // Completely transparent so grid/ruled lines show through!
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
              width: isSelected ? 1.2 : 0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag bar handle (only shown when focused/selected)
              if (isSelected) _buildDragHandle(),

              // Content row: editable text field + right-edge resize handle
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 6.0,
                      ),
                      child: TextField(
                        controller: widget.richController,
                        focusNode: _focusNode,
                        autofocus: widget.isSelected,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          fontSize: 15.0,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),

                  // Right-edge resize handle
                  if (isSelected) _buildResizeHandle(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top pill handle to drag and move the text container on the canvas
  Widget _buildDragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        widget.controller.beginTextBoxTransform();
        setState(() => _isDragging = true);
        _dragStartPos = details.globalPosition;
        _dragInitialX = widget.textBox.position.dx;
        _dragInitialY = widget.textBox.position.dy;
      },
      onPanUpdate: (details) {
        if (!_isDragging || _dragStartPos == null) return;
        final delta = details.globalPosition - _dragStartPos!;
        final newX = _dragInitialX! + delta.dx;
        final newY = _dragInitialY! + delta.dy;
        widget.controller.updateTextBoxPosition(
          widget.textBox.id,
          Offset(newX, newY),
        );
      },
      onPanEnd: (_) {
        setState(() => _isDragging = false);
        _dragStartPos = null;
        widget.controller.transferTextBoxIfNeeded(widget.textBox.id);
        widget.controller.commitTextBoxTransform();
      },
      child: Container(
        height: 20,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
        child: Center(
          child: Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  /// Right-edge vertical handle to widen or narrow the text container
  Widget _buildResizeHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        widget.controller.beginTextBoxTransform();
        setState(() => _isResizing = true);
        _resizeStartX = details.globalPosition.dx;
        _resizeInitialWidth = widget.textBox.width;
      },
      onPanUpdate: (details) {
        if (!_isResizing || _resizeStartX == null) return;
        final deltaX = details.globalPosition.dx - _resizeStartX!;
        final maxWidth = AppConstants.defaultPageSize.width -
            widget.textBox.position.dx -
            8.0;
        final newWidth = max(
          NoteTextBox.minWidth,
          min(maxWidth, _resizeInitialWidth! + deltaX),
        );
        widget.textBox.width = newWidth;
        widget.controller.updateTextBox(widget.textBox);
      },
      onPanEnd: (_) {
        setState(() => _isResizing = false);
        _resizeStartX = null;
        widget.controller.commitTextBoxTransform();
      },
      child: Container(
        width: 14,
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
