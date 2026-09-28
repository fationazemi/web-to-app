import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Flood-fills the connected region around ([startX], [startY]) in a raw
/// RGBA buffer with [fillColor]. Pixels whose channels are all within
/// [tolerance] of the seed pixel belong to the region.
///
/// Returns `true` when at least one pixel changed.
bool floodFillRgba(
  Uint8List pixels,
  int width,
  int height,
  int startX,
  int startY,
  ui.Color fillColor, {
  int tolerance = 40,
}) {
  if (startX < 0 || startY < 0 || startX >= width || startY >= height) {
    return false;
  }
  final seed = (startY * width + startX) * 4;
  final sr = pixels[seed], sg = pixels[seed + 1];
  final sb = pixels[seed + 2], sa = pixels[seed + 3];

  // Premultiplied RGBA to match the engine's rawRgba byte format.
  final fa = (fillColor.a * 255).round();
  final fr = (fillColor.r * fa).round();
  final fg = (fillColor.g * fa).round();
  final fb = (fillColor.b * fa).round();
  if (fr == sr && fg == sg && fb == sb && fa == sa) return false;

  bool matches(int i) {
    return (pixels[i] - sr).abs() <= tolerance &&
        (pixels[i + 1] - sg).abs() <= tolerance &&
        (pixels[i + 2] - sb).abs() <= tolerance &&
        (pixels[i + 3] - sa).abs() <= tolerance;
  }

  final visited = Uint8List(width * height);
  final stack = <int>[startY * width + startX];
  var changed = false;

  // Scanline fill: expand each seed left and right, then queue the rows above
  // and below wherever a new run starts.
  while (stack.isNotEmpty) {
    final index = stack.removeLast();
    final y = index ~/ width;
    var x = index % width;
    if (visited[index] == 1 || !matches(index * 4)) continue;

    var left = x;
    while (left > 0 && visited[y * width + left - 1] == 0 && matches((y * width + left - 1) * 4)) {
      left--;
    }
    var right = x;
    while (right < width - 1 && visited[y * width + right + 1] == 0 && matches((y * width + right + 1) * 4)) {
      right++;
    }

    var aboveRun = false;
    var belowRun = false;
    for (x = left; x <= right; x++) {
      final i = y * width + x;
      visited[i] = 1;
      final p = i * 4;
      pixels[p] = fr;
      pixels[p + 1] = fg;
      pixels[p + 2] = fb;
      pixels[p + 3] = fa;
      changed = true;

      if (y > 0) {
        final up = i - width;
        final ok = visited[up] == 0 && matches(up * 4);
        if (ok && !aboveRun) stack.add(up);
        aboveRun = ok;
      }
      if (y < height - 1) {
        final down = i + width;
        final ok = visited[down] == 0 && matches(down * 4);
        if (ok && !belowRun) stack.add(down);
        belowRun = ok;
      }
    }
  }
  return changed;
}

/// Rasterises a flood fill of [source] and returns the resulting image.
Future<ui.Image> floodFillImage(
  ui.Image source,
  int startX,
  int startY,
  ui.Color fillColor, {
  int tolerance = 40,
}) async {
  final data = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) return source;
  final pixels = Uint8List.fromList(data.buffer.asUint8List());
  floodFillRgba(pixels, source.width, source.height, startX, startY, fillColor,
      tolerance: tolerance);
  return decodeRgba(pixels, source.width, source.height);
}

/// Decodes raw RGBA bytes into a [ui.Image].
Future<ui.Image> decodeRgba(Uint8List pixels, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
