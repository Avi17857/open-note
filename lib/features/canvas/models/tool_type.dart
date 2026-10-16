import 'package:flutter/material.dart';

enum ToolType {
  pen,
  highlighter,
  strokeEraser,
  areaEraser,
  pan,
}

extension ToolTypeExtension on ToolType {
  String get label {
    return switch (this) {
      ToolType.pen => 'Pen',
      ToolType.highlighter => 'Highlighter',
      ToolType.strokeEraser => 'Stroke Eraser',
      ToolType.areaEraser => 'Area Eraser',
      ToolType.pan => 'Pan / Hand',
    };
  }

  IconData get icon {
    return switch (this) {
      ToolType.pen => Icons.edit,
      ToolType.highlighter => Icons.brush,
      ToolType.strokeEraser => Icons.auto_fix_normal,
      ToolType.areaEraser => Icons.cleaning_services,
      ToolType.pan => Icons.pan_tool_outlined,
    };
  }

  bool get isEraser =>
      this == ToolType.strokeEraser || this == ToolType.areaEraser;

  bool get isDrawingTool =>
      this == ToolType.pen || this == ToolType.highlighter;
}
