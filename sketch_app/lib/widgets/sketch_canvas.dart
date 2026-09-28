import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../canvas/sketch_painter.dart';
import '../models/stroke.dart';
import '../theme/app_theme.dart';
import 'brush_stroke.dart';

/// The interactive drawing surface. Keeps a 3:4 aspect ratio and forwards
/// pointer events to the [CanvasController] in normalized coordinates.
///
/// Stylus input (Apple Pencil, S Pen, ...) gets pressure-sensitive strokes
/// and takes priority over touches, so a resting palm never draws.
class SketchCanvas extends StatefulWidget {
  const SketchCanvas({
    super.key,
    required this.controller,
    this.stylusOnly = false,
    this.pressureSensitivity = true,
  });

  final CanvasController controller;

  /// Ignore finger input entirely; only a stylus (or mouse) draws.
  final bool stylusOnly;

  /// Whether stylus pressure changes the stroke width.
  final bool pressureSensitivity;

  /// Aspect ratio (width / height) of every canvas in the app.
  static const double aspectRatio = 3 / 4;

  @override
  State<SketchCanvas> createState() => _SketchCanvasState();
}

class _SketchCanvasState extends State<SketchCanvas> {
  int? _activePointer;
  PointerDeviceKind? _activeKind;
  bool _filling = false;

  Offset _normalize(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );

  /// Normalized pressure for stylus events, `null` for everything else.
  double? _pressure(PointerEvent event) {
    if (!widget.pressureSensitivity || event.kind != PointerDeviceKind.stylus) return null;
    final range = event.pressureMax - event.pressureMin;
    if (range <= 0) return null;
    return ((event.pressure - event.pressureMin) / range).clamp(0.0, 1.0);
  }

  bool _accepts(PointerEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      if (widget.stylusOnly) return false;
      // A stylus already on the surface wins over touches (palm rejection).
      if (_activeKind == PointerDeviceKind.stylus) return false;
    }
    return true;
  }

  Future<void> _fill(Offset normalized) async {
    if (_filling) return;
    setState(() => _filling = true);
    try {
      await widget.controller.fillAt(normalized);
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  void _down(PointerDownEvent event, Size size) {
    if (!_accepts(event)) return;
    if (_activePointer != null) {
      // A stylus arriving mid-touch replaces the finger stroke.
      if (event.kind == PointerDeviceKind.stylus && _activeKind == PointerDeviceKind.touch) {
        widget.controller.cancelStroke();
      } else {
        return;
      }
    }
    final p = _normalize(event.localPosition, size);
    if (widget.controller.tool == ToolType.fill) {
      _fill(p);
      return;
    }
    _activePointer = event.pointer;
    _activeKind = event.kind;
    widget.controller.beginStroke(p, size, pressure: _pressure(event));
  }

  void _move(PointerMoveEvent event, Size size) {
    if (event.pointer != _activePointer) return;
    widget.controller.extendStroke(_normalize(event.localPosition, size), pressure: _pressure(event));
  }

  void _up(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _activeKind = null;
    widget.controller.endStroke();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF1B1B1B) : const Color(0xFFFCFBF8);
    final templateInk = theme.colorScheme.onSurface.withValues(alpha: dark ? 0.18 : 0.13);

    return AspectRatio(
      aspectRatio: SketchCanvas.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => _down(event, size),
              onPointerMove: (event) => _move(event, size),
              onPointerUp: _up,
              onPointerCancel: _up,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _CanvasPainter(
                      controller: widget.controller,
                      paperColor: paper,
                      templateInk: templateInk,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) => IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: widget.controller.isEmpty ? 1 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: const _StartDrawingHint(),
                      ),
                    ),
                  ),
                  if (_filling)
                    const ColoredBox(
                      color: Color(0x22000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.controller,
    required this.paperColor,
    required this.templateInk,
  }) : super(repaint: controller);

  final CanvasController controller;
  final Color paperColor;
  final Color templateInk;

  @override
  void paint(Canvas canvas, Size size) {
    paintDrawing(
      canvas,
      size,
      strokes: controller.strokes,
      committedPicture: controller.committedPicture(size),
      activeStroke: controller.activeStroke,
      background: controller.background,
      template: controller.template,
      paperColor: paperColor,
      templateInk: templateInk,
    );
  }

  @override
  bool shouldRepaint(_CanvasPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.paperColor != paperColor ||
      oldDelegate.templateInk != templateInk;
}

class _StartDrawingHint extends StatelessWidget {
  const _StartDrawingHint();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.rotate(
            angle: -0.12,
            child: Text('Start drawing', style: handStyle(size: 24, bold: false, color: color)),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: SizedBox(width: 34, height: 36, child: CustomPaint(painter: CurlyArrowPainter(color: color))),
          ),
        ],
      ),
    );
  }
}
