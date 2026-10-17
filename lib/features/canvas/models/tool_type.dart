import 'package:flutter/material.dart';

enum ToolType {
  pen,
  fountainPen,
  highlighter,
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
      ToolType.strokeEraser => 'Stroke Eraser',
      ToolType.areaEraser => 'Area Eraser',
      ToolType.lasso => 'Lasso Select',
      ToolType.pan => 'Pan / Hand',
    };
  }

  IconData get icon {
    return switch (this) {
      ToolType.pen => Icons.edit,
      ToolType.fountainPen => Icons.draw,
      ToolType.highlighter => Icons.brush,
      ToolType.strokeEraser => Icons.auto_fix_normal,
      ToolType.areaEraser => Icons.cleaning_services,
      ToolType.lasso => Icons.gesture,
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
}
