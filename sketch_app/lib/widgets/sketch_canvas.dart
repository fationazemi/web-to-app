import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../canvas/sketch_painter.dart';
import '../models/layer.dart';
import '../models/stroke.dart';
import '../theme/app_theme.dart';
import 'brush_stroke.dart';

/// Zoom and pan state of the canvas viewport.
class CanvasViewport extends ChangeNotifier {
  static const double minScale = 1;
  static const double maxScale = 8;

  double _scale = 1;
  Offset _offset = Offset.zero;

  double get scale => _scale;
  Offset get offset => _offset;
  bool get isIdentity => _scale == 1 && _offset == Offset.zero;

  Matrix4 get matrix => Matrix4.identity()
    ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
    ..scaleByDouble(_scale, _scale, 1, 1);

  /// Converts a point in viewport coordinates to canvas coordinates.
  Offset toCanvas(Offset viewportPoint) => (viewportPoint - _offset) / _scale;

  void reset() {
    if (isIdentity) return;
    _scale = 1;
    _offset = Offset.zero;
    notifyListeners();
  }

  /// Zooms by [factor] keeping [focal] (viewport coordinates) fixed, then
  /// pans by [pan]. [viewportSize] bounds the result so the paper never
  /// leaves the view.
  void apply({double factor = 1, Offset focal = Offset.zero, Offset pan = Offset.zero, required Size viewportSize}) {
    final nextScale = (_scale * factor).clamp(minScale, maxScale);
    final effective = nextScale / _scale;
    var next = focal - (focal - _offset) * effective + pan;
    _scale = nextScale;
    // Keep the paper covering the viewport.
    final minX = viewportSize.width - viewportSize.width * _scale;
    final minY = viewportSize.height - viewportSize.height * _scale;
    next = Offset(next.dx.clamp(minX, 0.0), next.dy.clamp(minY, 0.0));
    _offset = next;
    notifyListeners();
  }
}

/// The interactive drawing surface. Keeps a 3:4 aspect ratio and forwards
/// pointer events to the [CanvasController] in normalized coordinates.
///
/// * One finger / stylus / mouse draws.
/// * Two fingers pan and pinch-zoom (a quick two-finger tap undoes).
/// * Mouse wheel and trackpad pinch zoom around the cursor.
/// * Stylus input gets pressure-sensitive strokes and takes priority over
///   touches, so a resting palm never draws.
class SketchCanvas extends StatefulWidget {
  const SketchCanvas({
    super.key,
    required this.controller,
    this.viewport,
    this.stylusOnly = false,
    this.pressureSensitivity = true,
  });

  final CanvasController controller;
  final CanvasViewport? viewport;

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
  late CanvasViewport _viewport = widget.viewport ?? CanvasViewport();
  final Map<int, Offset> _touches = {};
  int? _drawingPointer;
  PointerDeviceKind? _drawingKind;
  bool _filling = false;

  // Two-finger gesture bookkeeping.
  Offset? _gestureFocal;
  double? _gestureDistance;
  bool _gestureMoved = false;
  DateTime? _gestureStart;

  @override
  void didUpdateWidget(SketchCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewport != oldWidget.viewport && widget.viewport != null) _viewport = widget.viewport!;
  }

  @override
  void dispose() {
    if (widget.viewport == null) _viewport.dispose();
    super.dispose();
  }

  Offset _normalize(Offset viewportPoint, Size size) {
    final local = _viewport.toCanvas(viewportPoint);
    return Offset((local.dx / size.width).clamp(0.0, 1.0), (local.dy / size.height).clamp(0.0, 1.0));
  }

  /// Normalized pressure for stylus events, `null` for everything else.
  double? _pressure(PointerEvent event) {
    if (!widget.pressureSensitivity || event.kind != PointerDeviceKind.stylus) return null;
    final range = event.pressureMax - event.pressureMin;
    if (range <= 0) return null;
    return ((event.pressure - event.pressureMin) / range).clamp(0.0, 1.0);
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

  void _stopDrawing({bool cancel = false}) {
    if (_drawingPointer == null) return;
    _drawingPointer = null;
    _drawingKind = null;
    if (cancel) {
      widget.controller.cancelStroke();
    } else {
      widget.controller.endStroke();
    }
  }

  void _startDrawing(PointerDownEvent event, Size size) {
    final p = _normalize(event.localPosition, size);
    if (widget.controller.tool == ToolType.fill) {
      _fill(p);
      return;
    }
    _drawingPointer = event.pointer;
    _drawingKind = event.kind;
    widget.controller.beginStroke(p, size, pressure: _pressure(event));
  }

  void _down(PointerDownEvent event, Size size) {
    if (event.kind == PointerDeviceKind.touch) {
      _touches[event.pointer] = event.localPosition;
      if (widget.stylusOnly || _drawingKind == PointerDeviceKind.stylus) return;
      if (_touches.length >= 2) {
        // Second finger: stop drawing, start pan/zoom.
        _stopDrawing(cancel: true);
        final points = _touches.values.toList();
        _gestureFocal = (points[0] + points[1]) / 2;
        _gestureDistance = (points[0] - points[1]).distance;
        _gestureMoved = false;
        _gestureStart = DateTime.now();
        return;
      }
    }
    if (_drawingPointer != null) {
      // A stylus arriving mid-touch replaces the finger stroke.
      if (event.kind == PointerDeviceKind.stylus && _drawingKind == PointerDeviceKind.touch) {
        _stopDrawing(cancel: true);
      } else {
        return;
      }
    }
    _startDrawing(event, size);
  }

  void _move(PointerMoveEvent event, Size size) {
    if (_touches.containsKey(event.pointer)) {
      _touches[event.pointer] = event.localPosition;
      if (_touches.length >= 2 && _gestureFocal != null) {
        final points = _touches.values.take(2).toList();
        final focal = (points[0] + points[1]) / 2;
        final distance = (points[0] - points[1]).distance;
        final factor = _gestureDistance! <= 0 ? 1.0 : distance / _gestureDistance!;
        if ((focal - _gestureFocal!).distance > 4 || (factor - 1).abs() > 0.03) _gestureMoved = true;
        _viewport.apply(factor: factor, focal: _gestureFocal!, pan: focal - _gestureFocal!, viewportSize: size);
        _gestureFocal = focal;
        _gestureDistance = distance;
        return;
      }
    }
    if (event.pointer != _drawingPointer) return;
    widget.controller.extendStroke(_normalize(event.localPosition, size), pressure: _pressure(event));
  }

  void _up(PointerEvent event) {
    if (_touches.remove(event.pointer) != null && _gestureFocal != null) {
      if (_touches.length < 2) {
        final quick = _gestureStart != null && DateTime.now().difference(_gestureStart!).inMilliseconds < 250;
        if (!_gestureMoved && quick) widget.controller.undo();
        _gestureFocal = null;
        _gestureDistance = null;
      }
    }
    if (event.pointer != _drawingPointer) return;
    _stopDrawing();
  }

  void _signal(PointerSignalEvent event, Size size) {
    if (event is PointerScrollEvent) {
      final factor = math.exp(-event.scrollDelta.dy / 400);
      _viewport.apply(factor: factor, focal: event.localPosition, viewportSize: size);
    }
  }

  double? _panZoomScale;

  void _panZoomStart(PointerPanZoomStartEvent event) => _panZoomScale = 1;

  void _panZoomUpdate(PointerPanZoomUpdateEvent event, Size size) {
    final previous = _panZoomScale ?? 1;
    _viewport.apply(
      factor: event.scale / previous,
      focal: event.localPosition,
      pan: event.panDelta,
      viewportSize: size,
    );
    _panZoomScale = event.scale;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paper = widget.controller.paperColor;

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
              onPointerSignal: (event) => _signal(event, size),
              onPointerPanZoomStart: _panZoomStart,
              onPointerPanZoomUpdate: (event) => _panZoomUpdate(event, size),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ListenableBuilder(
                    listenable: _viewport,
                    builder: (context, child) => Transform(transform: _viewport.matrix, child: child),
                    child: CustomPaint(
                      painter: _CanvasPainter(
                        controller: widget.controller,
                        paperColor: paper,
                        templateInk: templateInkFor(paper),
                        guideColor: theme.colorScheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) => IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: widget.controller.isEmpty ? 1 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: _StartDrawingHint(onDark: paper.computeLuminance() < 0.4),
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
    required this.guideColor,
  }) : super(repaint: controller);

  final CanvasController controller;
  final Color paperColor;
  final Color templateInk;
  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    paintDrawing(
      canvas,
      size,
      layers: controller.layers,
      activeIndex: controller.activeIndex,
      activeStrokes: controller.activeStrokes,
      pictureFor: (layer) => controller.pictureFor(layer, size),
      template: controller.template,
      paperColor: paperColor,
      templateInk: templateInk,
    );
    _paintSymmetryGuides(canvas, size);
  }

  void _paintSymmetryGuides(Canvas canvas, Size size) {
    final mode = controller.symmetry;
    if (mode == SymmetryMode.none) return;
    final paint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    void dashed(Offset a, Offset b) {
      const dash = 6.0, gap = 5.0;
      final total = (b - a).distance;
      final dir = (b - a) / total;
      for (var d = 0.0; d < total; d += dash + gap) {
        canvas.drawLine(a + dir * d, a + dir * math.min(d + dash, total), paint);
      }
    }
    if (mode != SymmetryMode.horizontal) dashed(Offset(size.width / 2, 0), Offset(size.width / 2, size.height));
    if (mode != SymmetryMode.vertical) dashed(Offset(0, size.height / 2), Offset(size.width, size.height / 2));
  }

  @override
  bool shouldRepaint(_CanvasPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.paperColor != paperColor ||
      oldDelegate.templateInk != templateInk ||
      oldDelegate.guideColor != guideColor;
}

class _StartDrawingHint extends StatelessWidget {
  const _StartDrawingHint({required this.onDark});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = (onDark ? Colors.white : Colors.black).withValues(alpha: 0.5);
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
