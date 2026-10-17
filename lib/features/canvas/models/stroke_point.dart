import 'dart:ui';

class StrokePoint extends Offset {
  final double pressure;

  const StrokePoint(
    super.dx,
    super.dy, {
    this.pressure = 0.5,
  });

  StrokePoint copyWith({
    double? dx,
    double? dy,
    double? pressure,
  }) {
    return StrokePoint(
      dx ?? this.dx,
      dy ?? this.dy,
      pressure: pressure ?? this.pressure,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': dx,
      'y': dy,
      'p': pressure,
    };
  }

  factory StrokePoint.fromJson(Map<String, dynamic> json) {
    return StrokePoint(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
      pressure: (json['p'] as num?)?.toDouble() ?? 0.5,
    );
  }

  factory StrokePoint.fromOffset(Offset offset, {double pressure = 0.5}) {
    return StrokePoint(offset.dx, offset.dy, pressure: pressure);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StrokePoint &&
        other.dx == dx &&
        other.dy == dy &&
        other.pressure == pressure;
  }

  @override
  int get hashCode => Object.hash(dx, dy, pressure);
}
