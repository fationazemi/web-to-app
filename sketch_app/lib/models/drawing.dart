import 'stroke.dart';

/// Metadata describing a saved drawing. The stroke data and background
/// raster live in separate files and are loaded on demand.
class DrawingMeta {
  const DrawingMeta({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.template,
    required this.strokeCount,
    required this.hasBackground,
    this.layerCount = 1,
    this.paperColor,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CanvasTemplate template;
  final int strokeCount;
  final bool hasBackground;
  final int layerCount;

  /// ARGB paper color, `null` for the default paper.
  final int? paperColor;

  DrawingMeta copyWith({
    String? name,
    DateTime? updatedAt,
    CanvasTemplate? template,
    int? strokeCount,
    bool? hasBackground,
    int? layerCount,
    int? paperColor,
  }) {
    return DrawingMeta(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      template: template ?? this.template,
      strokeCount: strokeCount ?? this.strokeCount,
      hasBackground: hasBackground ?? this.hasBackground,
      layerCount: layerCount ?? this.layerCount,
      paperColor: paperColor ?? this.paperColor,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'template': template.name,
        'strokeCount': strokeCount,
        'hasBackground': hasBackground,
        'layerCount': layerCount,
        if (paperColor != null) 'paperColor': paperColor,
      };

  factory DrawingMeta.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return DrawingMeta(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      template: CanvasTemplateX.fromName(json['template'] as String?),
      strokeCount: (json['strokeCount'] as num?)?.toInt() ?? 0,
      hasBackground: json['hasBackground'] as bool? ?? false,
      layerCount: (json['layerCount'] as num?)?.toInt() ?? 1,
      paperColor: (json['paperColor'] as num?)?.toInt(),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a date as `12 Sep 2026`.
String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';
