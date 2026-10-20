import 'package:flutter/material.dart';

enum ToolType {
  pen,
  fountainPen,
  highlighter,
  text,
  strokeEraser,
  areaEraser,
  lasso,
  pan,
}

extension ToolTypeExtension on ToolType {
  String get label {
    return switch (this) {
      ToolType.pen => 'Ballpoint',
      ToolType.fountainPen => 'Fountain Pen',
      ToolType.highlighter => 'Highlighter',
      ToolType.text => 'Text Box',
      ToolType.strokeEraser => 'Stroke Eraser',
      ToolType.areaEraser => 'Area Eraser',
      ToolType.lasso => 'Lasso Select',
      ToolType.pan => 'Pan / Hand',
    };
  }

  IconData get icon {
    return switch (this) {
      ToolType.pen => Icons.edit_rounded,
      ToolType.fountainPen => Icons.history_edu_rounded,
      ToolType.highlighter => Icons.highlight_rounded,
      ToolType.text => Icons.text_fields_rounded,
      ToolType.strokeEraser => Icons.auto_fix_high_rounded,
      ToolType.areaEraser => Icons.motion_photos_off_rounded,
      ToolType.lasso => Icons.gesture_rounded,
      ToolType.pan => Icons.pan_tool_outlined,
    };
  }

  bool get isEraser =>
      this == ToolType.strokeEraser || this == ToolType.areaEraser;

  bool get isDrawingTool =>
      this == ToolType.pen ||
      this == ToolType.fountainPen ||
      this == ToolType.highlighter;

  bool get isLasso => this == ToolType.lasso;

  bool get isText => this == ToolType.text;
}
