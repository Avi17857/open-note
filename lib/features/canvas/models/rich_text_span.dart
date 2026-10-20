import 'package:flutter/material.dart';

/// Semantic heading levels for structured typography in notes.
enum HeadingLevel {
  none,
  h1,
  h2,
  h3;

  String get label => switch (this) {
        HeadingLevel.none => 'Body',
        HeadingLevel.h1 => 'Heading 1',
        HeadingLevel.h2 => 'Heading 2',
        HeadingLevel.h3 => 'Heading 3',
      };

  double get defaultFontSize => switch (this) {
        HeadingLevel.none => 15.0,
        HeadingLevel.h1 => 26.0,
        HeadingLevel.h2 => 20.0,
        HeadingLevel.h3 => 17.0,
      };

  FontWeight get defaultFontWeight => switch (this) {
        HeadingLevel.none => FontWeight.normal,
        HeadingLevel.h1 => FontWeight.bold,
        HeadingLevel.h2 => FontWeight.bold,
        HeadingLevel.h3 => FontWeight.w600,
      };
}

/// A non-destructive attributed formatting range over plain UTF-16 text.
class RichTextSpan {
  final int start;
  final int end;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final double? fontSize;
  final Color? color;
  final Color? highlightColor;
  final HeadingLevel heading;

  const RichTextSpan({
    required this.start,
    required this.end,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.fontSize,
    this.color,
    this.highlightColor,
    this.heading = HeadingLevel.none,
  }) : assert(start <= end, 'Span start ($start) must be <= end ($end)');

  int get length => end - start;
  bool get isEmpty => start == end;

  /// Returns true if this span covers any character in [rangeStart, rangeEnd].
  bool overlaps(int rangeStart, int rangeEnd) {
    return start < rangeEnd && end > rangeStart;
  }

  /// Returns true if this span encloses the given text [offset].
  bool contains(int offset) {
    return offset >= start && offset < end;
  }

  RichTextSpan copyWith({
    int? start,
    int? end,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    double? fontSize,
    Color? color,
    Color? highlightColor,
    HeadingLevel? heading,
  }) {
    return RichTextSpan(
      start: start ?? this.start,
      end: end ?? this.end,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      highlightColor: highlightColor ?? this.highlightColor,
      heading: heading ?? this.heading,
    );
  }

  /// Combines span attributes into a Flutter [TextStyle].
  TextStyle toTextStyle({TextStyle? baseStyle, bool isDarkMode = false}) {
    final effectiveBase = baseStyle ?? const TextStyle();

    final TextDecoration decoration = TextDecoration.combine([
      if (underline) TextDecoration.underline,
      if (strikethrough) TextDecoration.lineThrough,
    ]);

    FontWeight effectiveWeight = effectiveBase.fontWeight ?? FontWeight.normal;
    if (bold || heading != HeadingLevel.none) {
      effectiveWeight = heading != HeadingLevel.none
          ? heading.defaultFontWeight
          : FontWeight.bold;
    }

    double effectiveFontSize = effectiveBase.fontSize ?? 15.0;
    if (fontSize != null) {
      effectiveFontSize = fontSize!;
    } else if (heading != HeadingLevel.none) {
      effectiveFontSize = heading.defaultFontSize;
    }

    Color? effectiveColor = color ?? effectiveBase.color;
    if (isDarkMode && effectiveColor != null && effectiveColor.a >= 0.5) {
      final hsv = HSVColor.fromColor(effectiveColor);
      if (hsv.value < 0.25 && hsv.saturation < 0.25) {
        effectiveColor = Colors.white;
      }
    }

    return effectiveBase.copyWith(
      fontWeight: effectiveWeight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      decoration: decoration == TextDecoration.none ? null : decoration,
      fontSize: effectiveFontSize,
      color: effectiveColor,
      backgroundColor: highlightColor ?? effectiveBase.backgroundColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      if (bold) 'bold': true,
      if (italic) 'italic': true,
      if (underline) 'underline': true,
      if (strikethrough) 'strikethrough': true,
      if (fontSize != null) 'fontSize': fontSize,
      if (color != null) 'color': color!.toARGB32(),
      if (highlightColor != null) 'highlight': highlightColor!.toARGB32(),
      if (heading != HeadingLevel.none) 'heading': heading.name,
    };
  }

  factory RichTextSpan.fromJson(Map<String, dynamic> json) {
    Color? parseColor(dynamic value) {
      if (value == null) return null;
      if (value is int) return Color(value);
      if (value is String) {
        final hex = value.replaceFirst('#', '');
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 8) {
          return Color(int.parse(hex, radix: 16));
        }
      }
      return null;
    }

    HeadingLevel parseHeading(dynamic val) {
      if (val == null) return HeadingLevel.none;
      return HeadingLevel.values.firstWhere(
        (h) => h.name.toLowerCase() == val.toString().toLowerCase(),
        orElse: () => HeadingLevel.none,
      );
    }

    return RichTextSpan(
      start: (json['start'] as num?)?.toInt() ?? 0,
      end: (json['end'] as num?)?.toInt() ?? 0,
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      underline: json['underline'] == true,
      strikethrough: json['strikethrough'] == true,
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      color: parseColor(json['color']),
      highlightColor: parseColor(json['highlight']),
      heading: parseHeading(json['heading']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RichTextSpan &&
        other.start == start &&
        other.end == end &&
        other.bold == bold &&
        other.italic == italic &&
        other.underline == underline &&
        other.strikethrough == strikethrough &&
        other.fontSize == fontSize &&
        other.color == color &&
        other.highlightColor == highlightColor &&
        other.heading == heading;
  }

  @override
  int get hashCode => Object.hash(
        start,
        end,
        bold,
        italic,
        underline,
        strikethrough,
        fontSize,
        color,
        highlightColor,
        heading,
      );
}
