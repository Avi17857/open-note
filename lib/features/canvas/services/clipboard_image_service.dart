import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Service for reading image payloads from the system clipboard and picking local image files.
class ClipboardImageService {
  /// Reads an image from the system clipboard (PNG, JPEG, WebP, GIF), returning raw bytes.
  static Future<Uint8List?> readImageFromClipboard() async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) return null;

      final reader = await clipboard.read();
      final formats = [
        Formats.png,
        Formats.jpeg,
        Formats.webp,
        Formats.gif,
      ];

      for (final format in formats) {
        if (reader.canProvide(format)) {
          final completer = Completer<Uint8List?>();
          reader.getFile(
            format,
            (file) async {
              try {
                final bytes = await file.readAll();
                if (!completer.isCompleted) {
                  completer.complete(bytes);
                }
              } catch (_) {
                if (!completer.isCompleted) {
                  completer.complete(null);
                }
              }
            },
            onError: (_) {
              if (!completer.isCompleted) {
                completer.complete(null);
              }
            },
          );
          final result = await completer.future;
          if (result != null && result.isNotEmpty) {
            return result;
          }
        }
      }
    } catch (_) {
      // Platform clipboard access exception or permission denial
    }
    return null;
  }

  /// Opens the native/web file picker to select an image file from the device.
  static Future<({Uint8List bytes, String name})?> pickImageFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null && bytes.isNotEmpty) {
          return (bytes: bytes, name: file.name);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Inspects the natural pixel width and height of an image payload.
  static Future<Size> getImageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width.toDouble();
      final height = frame.image.height.toDouble();
      frame.image.dispose();
      return Size(width, height);
    } catch (_) {
      return const Size(300.0, 200.0);
    }
  }
}
