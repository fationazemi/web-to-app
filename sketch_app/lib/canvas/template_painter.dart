import 'package:flutter/material.dart';

import '../models/stroke.dart';

/// Paints the paper pattern (grid, ruled lines, dots) for a template.
void paintTemplate(Canvas canvas, Size size, CanvasTemplate template, Color inkColor) {
  if (template == CanvasTemplate.blank) return;
  final scale = size.width / 360;
  final paint = Paint()
    ..color = inkColor
    ..strokeWidth = 1 * scale
    ..style = PaintingStyle.stroke;

  switch (template) {
    case CanvasTemplate.blank:
      break;
    case CanvasTemplate.grid:
      final step = 24 * scale;
      for (var x = step; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (var y = step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    case CanvasTemplate.ruled:
      final step = 28 * scale;
      for (var y = step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    case CanvasTemplate.dots:
      final step = 24 * scale;
      final dot = Paint()..color = inkColor;
      for (var x = step; x < size.width; x += step) {
        for (var y = step; y < size.height; y += step) {
          canvas.drawCircle(Offset(x, y), 1.4 * scale, dot);
        }
      }
  }
}
