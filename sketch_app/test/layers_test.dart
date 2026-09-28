import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sketch/canvas/canvas_controller.dart';
import 'package:sketch/canvas/timelapse.dart';
import 'package:sketch/models/layer.dart';
import 'package:sketch/models/stroke.dart';
import 'package:sketch/widgets/sketch_canvas.dart';

void main() {
  const size = Size(360, 480);

  CanvasController controller() => CanvasController(template: CanvasTemplate.blank, maxLayers: 3);

  void draw(CanvasController c, List<Offset> points) {
    c.beginStroke(points.first, size);
    for (final p in points.skip(1)) {
      c.extendStroke(p);
    }
    c.endStroke();
  }

  group('layers', () {
    test('strokes land on the active layer', () {
      final c = controller();
      draw(c, const [Offset(0.1, 0.1), Offset(0.2, 0.2)]);
      c.addLayer();
      expect(c.layers, hasLength(2));
      expect(c.activeIndex, 1);
      draw(c, const [Offset(0.3, 0.3), Offset(0.4, 0.4)]);
      expect(c.layers[0].strokes, hasLength(1));
      expect(c.layers[1].strokes, hasLength(1));
      expect(c.strokeCount, 2);
    });

    test('respects the layer limit', () {
      final c = controller();
      c.addLayer();
      c.addLayer();
      expect(c.canAddLayer, isFalse);
      c.addLayer();
      expect(c.layers, hasLength(3));
    });

    test('remove, move, visibility and rename are undoable; select is not', () {
      final c = controller();
      c.addLayer();
      c.renameLayer(1, 'Ink');
      expect(c.layers[1].name, 'Ink');
      c.setLayerVisible(1, false);
      expect(c.layers[1].visible, isFalse);
      c.moveLayer(1, 0);
      expect(c.layers[0].name, 'Ink');
      expect(c.activeLayer.name, 'Ink');
      c.selectLayer(1);
      final undoDepth = 4;
      for (var i = 0; i < undoDepth; i++) {
        c.undo();
      }
      expect(c.layers, hasLength(1));
      expect(c.canUndo, isFalse);
      c.removeLayer(0); // last layer cannot be removed
      expect(c.layers, hasLength(1));
    });

    test('opacity drag is a single undo step', () {
      final c = controller();
      c.beginTransientEdit();
      c.setLayerOpacity(0, 0.8);
      c.setLayerOpacity(0, 0.5);
      c.setLayerOpacity(0, 0.3);
      c.endTransientEdit();
      expect(c.layers[0].opacity, closeTo(0.3, 1e-9));
      c.undo();
      expect(c.layers[0].opacity, 1.0);
      expect(c.canUndo, isFalse);
    });

    test('merge down flattens into the lower layer', () async {
      final c = controller();
      draw(c, const [Offset(0.1, 0.1), Offset(0.2, 0.2)]);
      c.addLayer();
      draw(c, const [Offset(0.5, 0.5), Offset(0.6, 0.6)]);
      await c.mergeDown(1);
      expect(c.layers, hasLength(1));
      expect(c.layers[0].background, isNotNull);
      expect(c.layers[0].strokes, isEmpty);
    });

    test('clear only touches the active layer', () {
      final c = controller();
      draw(c, const [Offset(0.1, 0.1), Offset(0.2, 0.2)]);
      c.addLayer();
      draw(c, const [Offset(0.5, 0.5), Offset(0.6, 0.6)]);
      c.clear();
      expect(c.layers[1].strokes, isEmpty);
      expect(c.layers[0].strokes, hasLength(1));
    });

    test('layer JSON round trip keeps everything but the raster', () {
      final layer = Layer(
        id: 'a',
        name: 'Line art',
        visible: false,
        opacity: 0.4,
        strokes: const [Stroke(tool: ToolType.pen, color: Color(0xFF000000), width: 0.01, points: [Offset(0, 0)])],
      );
      final restored = Layer.fromJson(layer.toJson());
      expect(restored.id, 'a');
      expect(restored.name, 'Line art');
      expect(restored.visible, isFalse);
      expect(restored.opacity, closeTo(0.4, 1e-9));
      expect(restored.strokes, hasLength(1));
    });
  });

  group('symmetry', () {
    test('vertical mirror commits a mirrored copy', () {
      final c = controller()..setSymmetry(SymmetryMode.vertical);
      draw(c, const [Offset(0.1, 0.2), Offset(0.3, 0.4)]);
      expect(c.strokes, hasLength(2));
      expect(c.strokes[1].points, const [Offset(0.9, 0.2), Offset(0.7, 0.4)]);
      c.undo();
      expect(c.strokes, isEmpty);
    });

    test('four-way mirror commits four strokes', () {
      final c = controller()..setSymmetry(SymmetryMode.quad);
      draw(c, const [Offset(0.1, 0.2), Offset(0.3, 0.4)]);
      expect(c.strokes, hasLength(4));
      expect(c.activeStrokes, isEmpty);
    });
  });

  group('viewport', () {
    test('zooms around the focal point and clamps', () {
      final v = CanvasViewport();
      v.apply(factor: 2, focal: const Offset(180, 240), viewportSize: size);
      expect(v.scale, 2);
      expect(v.offset, const Offset(-180, -240));
      expect(v.toCanvas(const Offset(180, 240)), const Offset(180, 240));

      v.apply(pan: const Offset(1000, 1000), viewportSize: size);
      expect(v.offset, Offset.zero); // cannot pan past the paper edge

      v.apply(factor: 100, focal: Offset.zero, viewportSize: size);
      expect(v.scale, CanvasViewport.maxScale);

      v.reset();
      expect(v.isIdentity, isTrue);
    });
  });

  group('timelapse', () {
    test('partial keeps the first n strokes in stacking order', () {
      final c = controller();
      draw(c, const [Offset(0.1, 0.1), Offset(0.2, 0.2)]);
      draw(c, const [Offset(0.3, 0.3), Offset(0.4, 0.4)]);
      c.addLayer();
      draw(c, const [Offset(0.5, 0.5), Offset(0.6, 0.6)]);
      expect(Timelapse.strokeCount(c.layers), 3);
      final partial = Timelapse.partial(c.layers, 2);
      expect(partial[0].strokes, hasLength(2));
      expect(partial[1].strokes, isEmpty);
    });

    test('encodes an animated GIF', () async {
      final c = controller();
      draw(c, const [Offset(0.1, 0.1), Offset(0.9, 0.9)]);
      draw(c, const [Offset(0.9, 0.1), Offset(0.1, 0.9)]);
      final gif = await Timelapse.encodeGif(c, frames: 3, pixelRatio: 0.25);
      expect(String.fromCharCodes(gif.sublist(0, 6)), 'GIF89a');
    });
  });
}
