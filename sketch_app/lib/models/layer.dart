import 'dart:ui' as ui;

import 'stroke.dart';

/// One layer of a drawing: a stack of strokes over an optional raster
/// background. Layers are immutable; edits produce a new [Layer] via
/// [copyWith], which also bumps [revision] so caches can be invalidated.
class Layer {
  const Layer({
    required this.id,
    required this.name,
    this.visible = true,
    this.opacity = 1.0,
    this.strokes = const [],
    this.background,
    this.revision = 0,
  });

  final String id;
  final String name;
  final bool visible;
  final double opacity;
  final List<Stroke> strokes;
  final ui.Image? background;
  final int revision;

  bool get isEmpty => strokes.isEmpty && background == null;

  static String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Layer copyWith({
    String? name,
    bool? visible,
    double? opacity,
    List<Stroke>? strokes,
    ui.Image? background,
    bool clearBackground = false,
  }) {
    return Layer(
      id: id,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      strokes: strokes ?? this.strokes,
      background: clearBackground ? null : (background ?? this.background),
      revision: revision + 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'visible': visible,
        'opacity': opacity,
        'hasBackground': background != null,
        'strokes': [for (final s in strokes) s.toJson()],
      };

  /// Restores a layer; [background] is loaded separately by the repository.
  factory Layer.fromJson(Map<String, dynamic> json, {ui.Image? background}) {
    final rawStrokes = json['strokes'] as List<dynamic>? ?? const [];
    return Layer(
      id: json['id'] as String? ?? newId(),
      name: json['name'] as String? ?? 'Layer',
      visible: json['visible'] as bool? ?? true,
      opacity: ((json['opacity'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0),
      strokes: [for (final s in rawStrokes) Stroke.fromJson(s as Map<String, dynamic>)],
      background: background,
    );
  }
}

/// Mirror modes for symmetric drawing.
enum SymmetryMode { none, vertical, horizontal, quad }

extension SymmetryModeX on SymmetryMode {
  String get label => switch (this) {
        SymmetryMode.none => 'Off',
        SymmetryMode.vertical => 'Mirror left / right',
        SymmetryMode.horizontal => 'Mirror top / bottom',
        SymmetryMode.quad => 'Four-way',
      };
}
