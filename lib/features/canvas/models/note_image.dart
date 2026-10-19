import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Represents a raster image (PNG, JPEG, WebP, GIF) placed directly on a canvas page.
class NoteImage {
  final String id;
  Offset position;
  double width;
  double height;
  final Uint8List bytes;
  final String? name;

  NoteImage({
    required this.id,
    required this.position,
    required this.width,
    required this.height,
    required this.bytes,
    this.name,
  });

  /// Minimum width or height allowed when resizing on the canvas.
  static const double minSize = 40.0;

  /// Bounding rectangle in page coordinates.
  Rect get bounds => Rect.fromLTWH(position.dx, position.dy, width, height);

  NoteImage copyWith({
    String? id,
    Offset? position,
    double? width,
    double? height,
    Uint8List? bytes,
    String? name,
  }) {
    return NoteImage(
      id: id ?? this.id,
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      bytes: bytes ?? this.bytes,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': position.dx,
      'y': position.dy,
      'width': width,
      'height': height,
      'data': base64Encode(bytes),
      if (name != null) 'name': name,
    };
  }

  factory NoteImage.fromJson(Map<String, dynamic> json) {
    final base64Data = json['data'] as String? ?? '';
    final bytes = base64Data.isNotEmpty ? base64Decode(base64Data) : Uint8List(0);
    return NoteImage(
      id: json['id'] as String? ?? 'img_${DateTime.now().millisecondsSinceEpoch}',
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0.0,
        (json['y'] as num?)?.toDouble() ?? 0.0,
      ),
      width: (json['width'] as num?)?.toDouble() ?? 300.0,
      height: (json['height'] as num?)?.toDouble() ?? 200.0,
      bytes: bytes,
      name: json['name'] as String?,
    );
  }
}
