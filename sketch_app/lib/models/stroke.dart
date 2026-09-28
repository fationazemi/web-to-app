import 'package:flutter/material.dart';

/// The drawing tools available on the canvas.
enum ToolType { pen, brush, eraser, fill }

extension ToolTypeX on ToolType {
  String get label => switch (this) {
        ToolType.pen => 'Pen',
        ToolType.brush => 'Brush',
        ToolType.eraser => 'Eraser',
        ToolType.fill => 'Fill',
      };

  IconData get icon => switch (this) {
        ToolType.pen => Icons.edit_outlined,
        ToolType.brush => Icons.brush_outlined,
        ToolType.eraser => Icons.auto_fix_off_outlined,
        ToolType.fill => Icons.format_color_fill_outlined,
      };

  static ToolType fromName(String? name) =>
      ToolType.values.firstWhere((t) => t.name == name, orElse: () => ToolType.pen);
}

/// The paper pattern drawn underneath the strokes.
enum CanvasTemplate { blank, grid, ruled, dots }

extension CanvasTemplateX on CanvasTemplate {
  String get label => switch (this) {
        CanvasTemplate.blank => 'Blank Canvas',
        CanvasTemplate.grid => 'Grid',
        CanvasTemplate.ruled => 'Ruled',
        CanvasTemplate.dots => 'Dots',
      };

  IconData get icon => switch (this) {
        CanvasTemplate.blank => Icons.landscape_outlined,
        CanvasTemplate.grid => Icons.grid_4x4,
        CanvasTemplate.ruled => Icons.notes,
        CanvasTemplate.dots => Icons.grain,
      };

  static CanvasTemplate fromName(String? name) => CanvasTemplate.values
      .firstWhere((t) => t.name == name, orElse: () => CanvasTemplate.blank);
}

/// A single stroke on the canvas.
///
/// All geometry is stored in *normalized* canvas coordinates (0..1) so a
/// drawing renders identically on any screen size. [width] is a fraction of
/// the canvas width for the same reason.
class Stroke {
  const Stroke({
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    this.pressures,
  });

  final ToolType tool;
  final Color color;
  final double width;
  final List<Offset> points;

  /// Optional normalized stylus pressure (0..1) per point. `null` for
  /// strokes drawn with a finger or mouse, which render at constant width.
  final List<double>? pressures;

  bool get isEraser => tool == ToolType.eraser;

  bool get hasPressure => pressures != null && pressures!.length == points.length && points.length > 1;

  Map<String, dynamic> toJson() => {
        'tool': tool.name,
        'color': color.toARGB32(),
        'width': width,
        'points': [
          for (final p in points) ...[p.dx, p.dy],
        ],
        if (pressures != null) 'pressures': pressures,
      };

  factory Stroke.fromJson(Map<String, dynamic> json) {
    final raw = (json['points'] as List<dynamic>? ?? const []).cast<num>();
    final points = <Offset>[];
    for (var i = 0; i + 1 < raw.length; i += 2) {
      points.add(Offset(raw[i].toDouble(), raw[i + 1].toDouble()));
    }
    final rawPressures = (json['pressures'] as List<dynamic>?)?.cast<num>();
    return Stroke(
      tool: ToolTypeX.fromName(json['tool'] as String?),
      color: Color((json['color'] as num?)?.toInt() ?? 0xFF000000),
      width: (json['width'] as num?)?.toDouble() ?? 0.02,
      points: points,
      pressures: rawPressures == null ? null : [for (final v in rawPressures) v.toDouble()],
    );
  }
}
