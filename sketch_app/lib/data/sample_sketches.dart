import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../models/layer.dart';
import '../models/stroke.dart';
import '../settings/app_settings.dart';
import 'drawing_repository.dart';

/// Procedurally generated starter sketches so the app does not open empty.
/// They are ordinary drawings: the user can edit, rename or delete them.
class SampleSketches {
  SampleSketches._();

  static const _ink = Color(0xFF1B1B19);

  /// Seeds the samples once, the first time the app runs with an empty
  /// library.
  static Future<void> seedIfNeeded(AppSettings settings, DrawingRepository repository) async {
    if (settings.samplesSeeded || repository.count > 0) return;
    final now = DateTime.now();
    var daysAgo = 0;
    for (final (name, template, strokes) in build()) {
      final layer = Layer(id: Layer.newId(), name: 'Layer 1', strokes: strokes);
      final controller = CanvasController(template: template, initial: CanvasSnapshot(layers: [layer]));
      try {
        final thumb = await controller.exportPng(CanvasController.referenceSize, pixelRatio: 1.5);
        await repository.save(
          name: name,
          template: template,
          layers: [layer],
          thumbnailPng: thumb,
          timestamp: now.subtract(Duration(days: daysAgo, hours: daysAgo)),
        );
      } catch (_) {
        // Storage unavailable; skip silently.
      } finally {
        controller.dispose();
      }
      daysAgo += 2;
    }
    settings.setSamplesSeeded(true);
  }

  static List<(String, CanvasTemplate, List<Stroke>)> build() => [
        ('Landscape', CanvasTemplate.blank, _landscape()),
        ('Flower', CanvasTemplate.blank, _flower()),
        ('Abstract', CanvasTemplate.blank, _abstract()),
        ('Portrait', CanvasTemplate.dots, _portrait()),
      ];

  // ---------------------------------------------------------------------------
  // Geometry helpers (all coordinates are normalized 0..1)
  // ---------------------------------------------------------------------------

  static Stroke _s(ToolType tool, Color color, double width, List<Offset> points) =>
      Stroke(tool: tool, color: color, width: width, points: points);

  static List<Offset> _wave(double x0, double x1, double y, {double amp = 0.01, double freq = 2, int n = 40}) =>
      [for (var i = 0; i <= n; i++) Offset(x0 + (x1 - x0) * i / n, y + amp * math.sin(freq * math.pi * i / n))];

  static List<Offset> _ellipse(Offset c, double rx, double ry, {double rotation = 0, int n = 48, double from = 0, double to = 2 * math.pi}) {
    final cosR = math.cos(rotation), sinR = math.sin(rotation);
    return [
      for (var i = 0; i <= n; i++)
        () {
          final u = from + (to - from) * i / n;
          final x = rx * math.cos(u), y = ry * math.sin(u);
          return Offset(c.dx + x * cosR - y * sinR, c.dy + x * sinR + y * cosR);
        }(),
    ];
  }

  static List<Offset> _hill(double cx, double cy, double rx, double ry) =>
      _ellipse(Offset(cx, cy), rx, ry, from: math.pi, to: 2 * math.pi, n: 40);

  // ---------------------------------------------------------------------------
  // Drawings
  // ---------------------------------------------------------------------------

  static List<Stroke> _landscape() {
    const sky = Color(0xFFA9C4E6), skyDeep = Color(0xFF8FB0DB);
    const sun = Color(0xFFF6C453);
    const hillFar = Color(0xFF9CC48E), hillNear = Color(0xFF5E9A5B), ground = Color(0xFF8FC276);
    const trunk = Color(0xFF6B4A33), crown = Color(0xFF3F7E3E);
    return [
      for (var i = 0; i < 5; i++)
        _s(ToolType.brush, i.isEven ? sky : skyDeep, 0.13, _wave(0.0, 1.0, 0.08 + i * 0.1, amp: 0.012, freq: 1.5)),
      _s(ToolType.pen, sun, 0.11, _ellipse(const Offset(0.72, 0.26), 0.045, 0.045)),
      _s(ToolType.brush, hillFar, 0.16, _hill(0.25, 0.68, 0.45, 0.22)),
      _s(ToolType.brush, hillFar, 0.14, _hill(0.8, 0.7, 0.4, 0.18)),
      _s(ToolType.brush, hillNear, 0.18, _hill(0.55, 0.85, 0.6, 0.26)),
      for (var i = 0; i < 3; i++) _s(ToolType.brush, ground, 0.14, _wave(0.0, 1.0, 0.84 + i * 0.07, amp: 0.008)),
      _s(ToolType.pen, trunk, 0.022, const [Offset(0.3, 0.74), Offset(0.3, 0.56)]),
      _s(ToolType.pen, crown, 0.09, _ellipse(const Offset(0.3, 0.5), 0.06, 0.07)),
      _s(ToolType.pen, crown, 0.07, _ellipse(const Offset(0.27, 0.44), 0.04, 0.04)),
    ];
  }

  static List<Stroke> _flower() {
    const center = Offset(0.5, 0.44);
    const stem = Color(0xFF4B7F49);
    return [
      for (var i = 0; i < 6; i++)
        () {
          final a = i * math.pi / 3 - math.pi / 2;
          final dir = Offset(math.cos(a), math.sin(a));
          return _s(ToolType.pen, _ink, 0.011, _ellipse(center + dir * 0.17, 0.11, 0.05, rotation: a));
        }(),
      _s(ToolType.pen, _ink, 0.011, _ellipse(center, 0.05, 0.05)),
      _s(ToolType.pen, _ink, 0.008, _ellipse(center, 0.025, 0.025)),
      _s(ToolType.pen, stem, 0.014, [for (var i = 0; i <= 30; i++) Offset(0.5 + 0.03 * math.sin(i / 30 * math.pi), 0.62 + 0.3 * i / 30)]),
      _s(ToolType.pen, stem, 0.011, _ellipse(const Offset(0.58, 0.78), 0.08, 0.03, rotation: -0.6)),
      _s(ToolType.pen, stem, 0.011, _ellipse(const Offset(0.43, 0.7), 0.07, 0.028, rotation: 0.7)),
    ];
  }

  static List<Stroke> _abstract() {
    const pink = Color(0xFFF7B3C2), orange = Color(0xFFF5A868), yellow = Color(0xFFF7D774), blue = Color(0xFFB5C6EA);
    List<Stroke> block(Color c, double x0, double x1, double y0, double y1) => [
          for (var y = y0; y <= y1; y += 0.06) _s(ToolType.brush, c, 0.09, _wave(x0, x1, y, amp: 0.004, freq: 3)),
        ];
    return [
      ...block(pink, 0.1, 0.58, 0.12, 0.5),
      ...block(orange, 0.5, 0.92, 0.38, 0.72),
      ...block(yellow, 0.14, 0.52, 0.58, 0.9),
      ...block(blue, 0.66, 0.9, 0.1, 0.28),
      _s(ToolType.pen, _ink, 0.008, const [Offset(0.12, 0.88), Offset(0.88, 0.14)]),
      _s(ToolType.pen, _ink, 0.02, _ellipse(const Offset(0.7, 0.82), 0.05, 0.05)),
    ];
  }

  static List<Stroke> _portrait() {
    // A profile facing left, built from a few smoothed polylines.
    const profile = [
      Offset(0.52, 0.16), Offset(0.45, 0.20), Offset(0.40, 0.28), Offset(0.39, 0.36),
      Offset(0.40, 0.40), Offset(0.36, 0.45), Offset(0.34, 0.49), Offset(0.38, 0.51),
      Offset(0.37, 0.55), Offset(0.40, 0.57), Offset(0.38, 0.61), Offset(0.42, 0.64),
      Offset(0.48, 0.65), Offset(0.53, 0.63), Offset(0.55, 0.70), Offset(0.53, 0.80),
    ];
    const hair = [
      Offset(0.52, 0.16), Offset(0.62, 0.14), Offset(0.72, 0.20), Offset(0.76, 0.32),
      Offset(0.74, 0.46), Offset(0.68, 0.58), Offset(0.62, 0.62),
    ];
    const hairInner = [Offset(0.54, 0.20), Offset(0.62, 0.26), Offset(0.66, 0.36), Offset(0.64, 0.48)];
    const neck = [Offset(0.62, 0.62), Offset(0.64, 0.72), Offset(0.70, 0.82)];
    const shoulder = [Offset(0.30, 0.90), Offset(0.45, 0.84), Offset(0.60, 0.83), Offset(0.78, 0.86), Offset(0.90, 0.92)];
    return [
      _s(ToolType.pen, _ink, 0.011, profile),
      _s(ToolType.pen, _ink, 0.011, hair),
      _s(ToolType.pen, _ink, 0.008, hairInner),
      _s(ToolType.pen, _ink, 0.011, neck),
      _s(ToolType.pen, _ink, 0.011, shoulder),
      _s(ToolType.pen, _ink, 0.008, _ellipse(const Offset(0.46, 0.38), 0.03, 0.012, from: math.pi, to: 2 * math.pi, n: 12)),
      _s(ToolType.pen, _ink, 0.008, const [Offset(0.42, 0.33), Offset(0.50, 0.32)]),
    ];
  }
}
