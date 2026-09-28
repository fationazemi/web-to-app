import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sketch/models/drawing.dart';
import 'package:sketch/models/stroke.dart';

void main() {
  test('Stroke survives a JSON round trip', () {
    const stroke = Stroke(
      tool: ToolType.brush,
      color: Color(0xFF1E88E5),
      width: 0.03,
      points: [Offset(0.1, 0.2), Offset(0.5, 0.5), Offset(0.9, 0.1)],
    );
    final restored = Stroke.fromJson(stroke.toJson());
    expect(restored.tool, ToolType.brush);
    expect(restored.color, const Color(0xFF1E88E5));
    expect(restored.width, 0.03);
    expect(restored.points, stroke.points);
  });

  test('Stylus pressure survives a JSON round trip and is optional', () {
    const stroke = Stroke(
      tool: ToolType.pen,
      color: Color(0xFF000000),
      width: 0.02,
      points: [Offset(0.1, 0.1), Offset(0.2, 0.2)],
      pressures: [0.2, 0.9],
    );
    final restored = Stroke.fromJson(stroke.toJson());
    expect(restored.pressures, [0.2, 0.9]);
    expect(restored.hasPressure, isTrue);

    const finger = Stroke(tool: ToolType.pen, color: Color(0xFF000000), width: 0.02, points: [Offset(0, 0)]);
    expect(finger.toJson().containsKey('pressures'), isFalse);
    expect(Stroke.fromJson(finger.toJson()).hasPressure, isFalse);
  });

  test('Unknown tool and template names fall back safely', () {
    expect(ToolTypeX.fromName('laser'), ToolType.pen);
    expect(CanvasTemplateX.fromName(null), CanvasTemplate.blank);
  });

  test('DrawingMeta round trip and date formatting', () {
    final meta = DrawingMeta(
      id: 'abc',
      name: 'Flower',
      createdAt: DateTime(2026, 9, 10),
      updatedAt: DateTime(2026, 9, 12),
      template: CanvasTemplate.dots,
      strokeCount: 3,
      hasBackground: true,
    );
    final restored = DrawingMeta.fromJson(meta.toJson());
    expect(restored.name, 'Flower');
    expect(restored.template, CanvasTemplate.dots);
    expect(restored.hasBackground, isTrue);
    expect(formatDate(restored.updatedAt), '12 Sep 2026');
  });
}
