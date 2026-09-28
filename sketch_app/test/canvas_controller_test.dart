import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sketch/canvas/canvas_controller.dart';
import 'package:sketch/models/stroke.dart';

void main() {
  const size = Size(360, 480);

  CanvasController controller() => CanvasController(template: CanvasTemplate.blank);

  void draw(CanvasController c, List<Offset> points) {
    c.beginStroke(points.first, size);
    for (final p in points.skip(1)) {
      c.extendStroke(p);
    }
    c.endStroke();
  }

  test('strokes are committed with normalized width', () {
    final c = controller()..setStrokeWidth(18);
    draw(c, const [Offset(0.1, 0.1), Offset(0.4, 0.4)]);
    expect(c.strokes, hasLength(1));
    expect(c.strokes.single.width, closeTo(18 / 360, 1e-9));
    expect(c.strokes.single.points, hasLength(2));
    expect(c.dirty, isTrue);
  });

  test('undo, redo and clear walk the history', () {
    final c = controller();
    draw(c, const [Offset(0.1, 0.1), Offset(0.2, 0.2)]);
    draw(c, const [Offset(0.3, 0.3), Offset(0.4, 0.4)]);
    expect(c.strokes, hasLength(2));

    c.undo();
    expect(c.strokes, hasLength(1));
    expect(c.canRedo, isTrue);

    c.redo();
    expect(c.strokes, hasLength(2));

    c.clear();
    expect(c.isEmpty, isTrue);
    c.undo();
    expect(c.strokes, hasLength(2));
  });

  test('a new stroke discards the redo stack', () {
    final c = controller();
    draw(c, const [Offset(0.1, 0.1), Offset(0.2, 0.2)]);
    c.undo();
    expect(c.canRedo, isTrue);
    draw(c, const [Offset(0.5, 0.5), Offset(0.6, 0.6)]);
    expect(c.canRedo, isFalse);
  });

  test('the fill tool does not create strokes', () {
    final c = controller()..setTool(ToolType.fill);
    c.beginStroke(const Offset(0.5, 0.5), size);
    c.endStroke();
    expect(c.strokes, isEmpty);
  });

  test('export produces a PNG', () async {
    final c = controller();
    draw(c, const [Offset(0.1, 0.1), Offset(0.9, 0.9)]);
    final bytes = await c.exportPng(size, pixelRatio: 1);
    // PNG signature.
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('flood fill flattens the canvas into a background', () async {
    final c = controller()
      ..setColor(const Color(0xFFE53935))
      ..setTool(ToolType.fill);
    await c.fillAt(const Offset(0.5, 0.5));
    expect(c.background, isNotNull);
    expect(c.strokes, isEmpty);
    expect(c.canUndo, isTrue);
    c.undo();
    expect(c.background, isNull);
  });
}
