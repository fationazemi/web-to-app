import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/layer.dart';
import '../models/stroke.dart';
import 'template_painter.dart';

/// Maps normalized stylus pressure (0..1) to a stroke width multiplier.
double pressureWidthFactor(double pressure) => 0.35 + 1.0 * pressure.clamp(0.0, 1.0);

/// Ink color for template patterns that stays visible on light and dark
/// paper.
Color templateInkFor(Color paper) =>
    paper.computeLuminance() > 0.4 ? const Color(0x22000000) : const Color(0x33FFFFFF);

/// Draws one stroke onto [canvas]. The stroke's normalized geometry is scaled
/// to [size].
void paintStroke(Canvas canvas, Size size, Stroke stroke) {
  if (stroke.points.isEmpty) return;
  final width = stroke.width * size.width;
  final paint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  switch (stroke.tool) {
    case ToolType.pen:
    case ToolType.fill:
      paint
        ..color = stroke.color
        ..strokeWidth = width;
    case ToolType.brush:
      paint
        ..color = stroke.color.withValues(alpha: 0.55)
        ..strokeWidth = width * 1.6
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.25);
    case ToolType.eraser:
      paint
        ..color = Colors.black
        ..blendMode = BlendMode.clear
        ..strokeWidth = width * 1.4;
  }

  final points = stroke.points.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
  if (points.length == 1) {
    // A tap produces a dot.
    canvas.drawLine(points.first, points.first, paint);
    return;
  }

  if (stroke.hasPressure) {
    // Stylus strokes: vary the width per segment with the pen pressure.
    final pressures = stroke.pressures!;
    final base = paint.strokeWidth;
    for (var i = 0; i < points.length - 1; i++) {
      final p = (pressures[i] + pressures[i + 1]) / 2;
      paint.strokeWidth = base * pressureWidthFactor(p);
      canvas.drawLine(points[i], points[i + 1], paint);
    }
    return;
  }

  // Smooth the polyline by drawing quadratic curves through the midpoints.
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length - 1; i++) {
    final mid = Offset(
      (points[i].dx + points[i + 1].dx) / 2,
      (points[i].dy + points[i + 1].dy) / 2,
    );
    path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  canvas.drawPath(path, paint);
}

/// Draws the full drawing: paper, template, then every visible layer.
///
/// Each layer is composited inside its own transparency layer so that
/// eraser strokes (blend mode clear) only punch through that layer's ink,
/// never the paper or the layers underneath.
void paintDrawing(
  Canvas canvas,
  Size size, {
  required List<Layer> layers,
  int activeIndex = -1,
  List<Stroke> activeStrokes = const [],
  ui.Picture Function(Layer layer)? pictureFor,
  CanvasTemplate template = CanvasTemplate.blank,
  Color? paperColor,
  Color templateInk = const Color(0x22000000),
}) {
  final rect = Offset.zero & size;
  if (paperColor != null) {
    canvas.drawRect(rect, Paint()..color = paperColor);
  }
  paintTemplate(canvas, size, template, templateInk);

  for (var i = 0; i < layers.length; i++) {
    final layer = layers[i];
    if (!layer.visible) continue;
    canvas.saveLayer(rect, Paint()..color = Colors.white.withValues(alpha: layer.opacity));
    final bg = layer.background;
    if (bg != null) {
      final src = Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble());
      canvas.drawImageRect(bg, src, rect, Paint()..filterQuality = FilterQuality.medium);
    }
    if (pictureFor != null) {
      canvas.drawPicture(pictureFor(layer));
    } else {
      for (final stroke in layer.strokes) {
        paintStroke(canvas, size, stroke);
      }
    }
    if (i == activeIndex) {
      for (final stroke in activeStrokes) {
        paintStroke(canvas, size, stroke);
      }
    }
    canvas.restore();
  }
}

/// Records the committed strokes into a reusable [ui.Picture].
ui.Picture recordStrokes(Size size, List<Stroke> strokes) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  for (final stroke in strokes) {
    paintStroke(canvas, size, stroke);
  }
  return recorder.endRecording();
}
