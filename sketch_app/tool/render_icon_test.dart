// Renders the app icon and splash artwork from the same brush-stroke
// painter the app uses, so the branding stays in sync with the UI.
//
// Run with:  flutter test tool/render_icon_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sketch/theme/app_theme.dart';
import 'package:sketch/widgets/brush_stroke.dart';

Future<void> _render(String path, int size, void Function(Canvas canvas, Size size) paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, Size(size.toDouble(), size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}

void _artwork(Canvas canvas, Size size, {bool withPaper = true}) {
  final w = size.width, h = size.height;
  if (withPaper) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.paper);
  }
  // Brush stroke sweeping diagonally through the centre.
  final box = Size(w * 1.2, h * 0.5);
  canvas.save();
  canvas.translate(w * 0.5, h * 0.52);
  canvas.rotate(-0.4);
  canvas.translate(-box.width / 2, -box.height / 2);
  const BrushStrokePainter().paint(canvas, box);
  canvas.restore();

  // Ink "S" squiggle over the stroke.
  final ink = Paint()
    ..color = AppColors.ink
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = w * 0.06;
  final s = Path()
    ..moveTo(w * 0.64, h * 0.31)
    ..cubicTo(w * 0.44, h * 0.21, w * 0.32, h * 0.42, w * 0.50, h * 0.50)
    ..cubicTo(w * 0.70, h * 0.58, w * 0.58, h * 0.80, w * 0.36, h * 0.69);
  canvas.drawPath(s, ink);
}

void main() {
  test('render icon and splash artwork', () async {
    await _render('assets/icon/icon.png', 1024, (c, s) => _artwork(c, s));
    await _render('assets/icon/icon_foreground.png', 1024, (c, s) {
      // Adaptive icons get masked; keep the art inside the safe zone.
      c.translate(s.width * 0.16, s.height * 0.16);
      c.scale(0.68);
      _artwork(c, s, withPaper: false);
    });
    await _render('assets/icon/splash.png', 768, (c, s) => _artwork(c, s, withPaper: false));
    expect(File('assets/icon/icon.png').lengthSync(), greaterThan(1000));
  });
}
