import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A painterly brush stroke: a tapered body with bristle streaks, drawn
/// along a bezier. Used as decoration on the home hero card.
class BrushStrokePainter extends CustomPainter {
  const BrushStrokePainter({this.color = AppColors.accent});

  final Color color;

  // Perpendicular offsets (as a fraction of the body width) and alpha of
  // each bristle streak. Fixed so the stroke looks identical every frame.
  static const _streaks = <(double, double, bool)>[
    (-0.34, 0.16, true),
    (-0.14, 0.10, false),
    (0.04, 0.14, true),
    (0.24, 0.10, false),
    (0.38, 0.14, true),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.66)
      ..cubicTo(w * 0.28, h * 0.02, w * 0.50, h * 1.02, w * 0.94, h * 0.30);
    final metric = path.computeMetrics().first;
    final length = metric.length;
    const samples = 90;
    final bodyWidth = h * 0.34;

    double envelope(double t) => math.pow(math.sin(math.pi * t), 0.45).toDouble();

    // Body: a soft under-layer slightly wider than the opaque core gives the
    // edges a wet, painted look instead of a hard vector outline.
    final under = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.02)
      ..isAntiAlias = true;
    final body = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (var i = 0; i < samples; i++) {
      final t0 = i / samples, t1 = (i + 1) / samples;
      final p0 = metric.getTangentForOffset(t0 * length)!.position;
      final p1 = metric.getTangentForOffset(t1 * length)!.position;
      final width = bodyWidth * envelope((t0 + t1) / 2);
      under.strokeWidth = width * 1.08;
      canvas.drawLine(p0, p1, under);
      body.strokeWidth = width;
      canvas.drawLine(p0, p1, body);
    }

    // Bristle streaks
    final light = Color.lerp(color, Colors.white, 0.45)!;
    final deep = Color.lerp(color, AppColors.ink, 0.35)!;
    for (final (offset, alpha, isLight) in _streaks) {
      final paint = Paint()
        ..color = (isLight ? light : deep).withValues(alpha: alpha)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = h * 0.012
        ..isAntiAlias = true;
      Offset? prev;
      for (var i = 0; i <= samples; i++) {
        final t = i / samples;
        final tangent = metric.getTangentForOffset(t * length)!;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        final width = bodyWidth * envelope(t);
        // Streaks fade in and out so they never poke past the tapered ends.
        final fade = envelope(t) * envelope(t);
        final p = tangent.position + normal * (offset * width);
        if (prev != null && fade > 0.15) canvas.drawLine(prev, p, paint);
        prev = p;
      }
    }
  }

  @override
  bool shouldRepaint(BrushStrokePainter oldDelegate) => oldDelegate.color != color;
}

/// A short hand-drawn arrow curling down and to the left, used next to the
/// "Start drawing" hint.
class CurlyArrowPainter extends CustomPainter {
  const CurlyArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(w * 0.85, h * 0.05)
      ..cubicTo(w * 0.95, h * 0.45, w * 0.55, h * 0.75, w * 0.18, h * 0.92);
    canvas.drawPath(path, paint);
    final tip = Offset(w * 0.18, h * 0.92);
    canvas.drawLine(tip, tip + Offset(w * 0.22, -h * 0.02), paint);
    canvas.drawLine(tip, tip + Offset(w * 0.05, -h * 0.28), paint);
  }

  @override
  bool shouldRepaint(CurlyArrowPainter oldDelegate) => oldDelegate.color != color;
}
