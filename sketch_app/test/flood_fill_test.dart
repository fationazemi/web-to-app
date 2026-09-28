import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sketch/canvas/flood_fill.dart';

void main() {
  // A 5x5 transparent image with a 1px opaque black vertical wall at x = 2.
  Uint8List walledImage() {
    const w = 5, h = 5;
    final px = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      final i = (y * w + 2) * 4;
      px[i + 3] = 255; // alpha; rgb stay 0 (black, premultiplied)
    }
    return px;
  }

  int alphaAt(Uint8List px, int x, int y, int w) => px[(y * w + x) * 4 + 3];
  int redAt(Uint8List px, int x, int y, int w) => px[(y * w + x) * 4];

  test('fills only the region enclosed by the wall', () {
    final px = walledImage();
    final changed = floodFillRgba(px, 5, 5, 0, 0, const Color(0xFFFF0000));
    expect(changed, isTrue);
    // Left of the wall is filled red.
    expect(redAt(px, 0, 0, 5), 255);
    expect(redAt(px, 1, 4, 5), 255);
    expect(alphaAt(px, 1, 4, 5), 255);
    // The wall itself stays black.
    expect(redAt(px, 2, 2, 5), 0);
    expect(alphaAt(px, 2, 2, 5), 255);
    // Right of the wall is untouched.
    expect(alphaAt(px, 3, 0, 5), 0);
    expect(alphaAt(px, 4, 4, 5), 0);
  });

  test('filling with the seed color is a no-op', () {
    final px = walledImage();
    final changed = floodFillRgba(px, 5, 5, 2, 0, const Color(0xFF000000));
    expect(changed, isFalse);
  });

  test('out-of-range seed is rejected', () {
    final px = walledImage();
    expect(floodFillRgba(px, 5, 5, 9, 9, const Color(0xFFFF0000)), isFalse);
  });

  test('tolerance merges near colors', () {
    const w = 3, h = 1;
    final px = Uint8List(w * h * 4);
    // Three opaque grays: 100, 120, 200.
    for (var x = 0; x < w; x++) {
      final v = [100, 120, 200][x];
      px[x * 4] = v;
      px[x * 4 + 1] = v;
      px[x * 4 + 2] = v;
      px[x * 4 + 3] = 255;
    }
    floodFillRgba(px, w, h, 0, 0, const Color(0xFF0000FF), tolerance: 30);
    expect(px[0 * 4 + 2], 255); // filled blue
    expect(px[1 * 4 + 2], 255); // within tolerance, filled
    expect(px[2 * 4 + 2], 200); // outside tolerance, untouched
  });
}
