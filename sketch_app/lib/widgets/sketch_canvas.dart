import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../canvas/sketch_painter.dart';
import '../models/stroke.dart';

/// The interactive drawing surface. Keeps a 3:4 aspect ratio and forwards
/// pointer events to the [CanvasController] in normalized coordinates.
class SketchCanvas extends StatefulWidget {
  const SketchCanvas({super.key, required this.controller});

  final CanvasController controller;

  /// Aspect ratio (width / height) of every canvas in the app.
  static const double aspectRatio = 3 / 4;

  @override
  State<SketchCanvas> createState() => _SketchCanvasState();
}

class _SketchCanvasState extends State<SketchCanvas> {
  int? _activePointer;
  bool _filling = false;

  Offset _normalize(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );

  Future<void> _fill(Offset normalized) async {
    if (_filling) return;
    setState(() => _filling = true);
    try {
      await widget.controller.fillAt(normalized);
    } finally {
      if (mounted) setState(() => _filling = false);
    }
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
              onPointerDown: (event) {
                if (_activePointer != null) return;
                final p = _normalize(event.localPosition, size);
                if (widget.controller.tool == ToolType.fill) {
                  _fill(p);
                  return;
                }
                _activePointer = event.pointer;
                widget.controller.beginStroke(p, size);
              },
              onPointerMove: (event) {
                if (event.pointer != _activePointer) return;
                widget.controller.extendStroke(_normalize(event.localPosition, size));
              },
              onPointerUp: (event) {
                if (event.pointer != _activePointer) return;
                _activePointer = null;
                widget.controller.endStroke();
              },
              onPointerCancel: (event) {
                if (event.pointer != _activePointer) return;
                _activePointer = null;
                widget.controller.endStroke();
              },
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
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: -0.08,
            child: Text(
              'Start drawing',
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Icon(Icons.subdirectory_arrow_left_rounded, color: color),
        ],
      ),
    );
  }
}
