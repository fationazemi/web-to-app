import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../models/layer.dart';
import 'canvas_controller.dart';

/// Builds progressive snapshots of a drawing (stroke by stroke, layer by
/// layer) for the in-app replay and the animated GIF export.
class Timelapse {
  Timelapse._();

  /// Total number of strokes across all visible layers.
  static int strokeCount(List<Layer> layers) =>
      layers.where((l) => l.visible).fold(0, (n, l) => n + l.strokes.length);

  /// Returns the layers with only the first [count] strokes (in stacking
  /// order) kept. Raster backgrounds are always present, since they cannot be
  /// replayed.
  static List<Layer> partial(List<Layer> layers, int count) {
    var remaining = count;
    return [
      for (final layer in layers)
        if (!layer.visible)
          layer
        else
          () {
            final take = remaining.clamp(0, layer.strokes.length);
            remaining -= take;
            return layer.copyWith(strokes: layer.strokes.sublist(0, take));
          }(),
    ];
  }

  /// Encodes an animated GIF of the drawing being built up.
  static Future<Uint8List> encodeGif(
    CanvasController controller, {
    int frames = 36,
    int frameDelayMs = 90,
    double pixelRatio = 1,
    void Function(double progress)? onProgress,
  }) async {
    final total = strokeCount(controller.layers);
    final steps = total == 0 ? 1 : frames.clamp(1, total);
    final encoder = img.GifEncoder(repeat: 0, samplingFactor: 10);
    final size = CanvasController.referenceSize;

    Future<void> addFrame(List<Layer> layers, int delayMs) async {
      final image = await controller.rasterize(size, pixelRatio: pixelRatio, includePaper: true, layers: layers);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final frame = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: data!.buffer,
        numChannels: 4,
      );
      image.dispose();
      encoder.addFrame(frame, duration: (delayMs / 10).round());
    }

    for (var i = 1; i <= steps; i++) {
      final count = (total * i / steps).ceil();
      await addFrame(partial(controller.layers, count), frameDelayMs);
      onProgress?.call(i / (steps + 1));
    }
    // Hold the finished drawing for a moment before looping.
    await addFrame(controller.layers, 1500);
    onProgress?.call(1);
    return encoder.finish() ?? Uint8List(0);
  }
}
